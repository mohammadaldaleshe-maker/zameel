import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AccessToken, RoomServiceClient } from "npm:livekit-server-sdk@2.19.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const jsonHeaders = { ...cors, "Content-Type": "application/json; charset=utf-8" };

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function websocketUrl(raw: string) {
  if (raw.startsWith("https://")) return `wss://${raw.slice(8)}`;
  if (raw.startsWith("http://")) return `ws://${raw.slice(7)}`;
  return raw;
}

function apiUrl(raw: string) {
  if (raw.startsWith("wss://")) return `https://${raw.slice(6)}`;
  if (raw.startsWith("ws://")) return `http://${raw.slice(5)}`;
  return raw;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const livekitUrl = Deno.env.get("LIVEKIT_URL") ?? "";
  const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY") ?? "";
  const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return reply({ error: "supabase_not_configured" }, 503);
  }
  if (!livekitUrl || !livekitApiKey || !livekitApiSecret) {
    return reply({
      error: "livekit_not_configured",
      message: "LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET are not configured",
    }, 503);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  const user = authData.user;
  if (authError || !user) return reply({ error: "not_authenticated" }, 401);

  const body = await req.json().catch(() => ({}));
  const action = String(body?.action ?? "token").trim().toLowerCase();
  const roomCode = String(body?.room_code ?? "").trim().toUpperCase();
  if (!roomCode) return reply({ error: "room_code_required" }, 400);

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  if (action === "token") {
    const { data: feature, error: featureError } = await admin
      .from("feature_flags")
      .select("is_enabled,display_mode")
      .eq("feature_key", "zameel_meet")
      .eq("scope_type", "global")
      .eq("scope_value", "*")
      .maybeSingle();

    if (featureError || !feature) {
      return reply({ error: "meeting_feature_status_unavailable" }, 503);
    }
    if (feature.is_enabled !== true || feature.display_mode !== "enabled") {
      return reply({
        error: "zameel_meet_temporarily_unavailable",
        message: "هذه الميزة معلقة حالياً",
      }, 409);
    }
  }

  const { data: meeting } = await admin
    .from("meeting_rooms")
    .select("room_code,title,host_id,is_active")
    .eq("room_code", roomCode)
    .maybeSingle();
  if (!meeting) return reply({ error: "meeting_not_found" }, 404);
  if (meeting.is_active !== true && action !== "end") return reply({ error: "meeting_ended" }, 409);

  const { data: membership } = await admin
    .from("meeting_room_members")
    .select("user_id")
    .eq("room_code", roomCode)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!membership) return reply({ error: "meeting_membership_required" }, 403);

  const isHost = String(meeting.host_id) === user.id;

  if (action === "token") {
    const { data: profile } = await admin
      .from("users")
      .select("name,profile_image")
      .eq("id", user.id)
      .maybeSingle();

    const access = new AccessToken(livekitApiKey, livekitApiSecret, {
      identity: user.id,
      name: String(profile?.name ?? "Zameel"),
      ttl: "3h",
      metadata: JSON.stringify({
        avatar: String(profile?.profile_image ?? ""),
        zameel_room_code: roomCode,
        is_host: isHost,
      }),
    });
    access.addGrant({
      roomJoin: true,
      room: roomCode,
      roomAdmin: isHost,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      canUpdateOwnMetadata: false,
    });
    const token = await access.toJwt();
    return reply({
      token,
      server_url: websocketUrl(livekitUrl),
      room_code: roomCode,
      title: String(meeting.title ?? "Zameel Meet"),
      is_host: isHost,
      participant_identity: user.id,
      participant_name: String(profile?.name ?? "Zameel"),
    });
  }

  if (!isHost) return reply({ error: "host_required" }, 403);
  const roomService = new RoomServiceClient(apiUrl(livekitUrl), livekitApiKey, livekitApiSecret);

  if (action === "remove") {
    const identity = String(body?.participant_identity ?? "").trim();
    if (!identity || identity === user.id) return reply({ error: "invalid_participant" }, 400);
    await roomService.removeParticipant(roomCode, identity);
    await admin.from("meeting_room_bans").upsert({
      room_code: roomCode,
      user_id: identity,
      banned_by: user.id,
      banned_at: new Date().toISOString(),
    }, { onConflict: "room_code,user_id" });
    await admin.from("meeting_room_members")
      .delete()
      .eq("room_code", roomCode)
      .eq("user_id", identity);
    return reply({ ok: true });
  }

  if (action === "mute") {
    const identity = String(body?.participant_identity ?? "").trim();
    const trackSid = String(body?.track_sid ?? "").trim();
    if (!identity || !trackSid || identity === user.id) return reply({ error: "invalid_mute_request" }, 400);
    await roomService.mutePublishedTrack(roomCode, identity, trackSid, true);
    return reply({ ok: true });
  }

  if (action === "end") {
    try {
      await roomService.deleteRoom(roomCode);
    } catch (_) {
      // The LiveKit room may already be empty. Supabase remains the source of truth.
    }
    await admin.from("meeting_rooms")
      .update({ is_active: false, ended_at: new Date().toISOString() })
      .eq("room_code", roomCode)
      .eq("host_id", user.id);
    return reply({ ok: true });
  }

  return reply({ error: "unsupported_action" }, 400);
});
