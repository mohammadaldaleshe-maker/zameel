import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function base64Url(input: Uint8Array | string) {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function getAccessToken(serviceAccount: Record<string, string>) {
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const claim = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const pem = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\\n/g, "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const unsigned = `${header}.${claim}`;
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  ));
  const jwt = `${unsigned}.${base64Url(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!response.ok) throw new Error(`OAuth token error: ${await response.text()}`);
  return (await response.json()).access_token as string;
}

function isInvalidTokenResponse(status: number, body: string) {
  if (status === 404) return true;
  return body.includes("UNREGISTERED") || body.includes("registration-token-not-registered");
}

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("ZAMEEL_PUSH_WEBHOOK_SECRET");
  const providedSecret = req.headers.get("x-zameel-push-secret");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }

  try {
    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountRaw) throw new Error("FCM_SERVICE_ACCOUNT_JSON is not configured");

    const serviceAccount = JSON.parse(serviceAccountRaw) as Record<string, string>;
    const projectId = serviceAccount.project_id;
    const accessToken = await getAccessToken(serviceAccount);

    // Recover rows whose previous worker died after claiming them. Migration
    // 069 records processing_started_at at the database layer, so even an
    // older worker active during rollout receives a timestamp automatically.
    // Thirty minutes is intentionally conservative to avoid replaying a push
    // that a slow-but-live worker is still sending.
    const staleProcessingBefore = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { error: staleProcessingError } = await supabase
      .from("push_notification_queue")
      .update({
        status: "failed",
        processed_at: null,
        last_error: "stale_processing_recovered",
      })
      .eq("status", "processing")
      .lt("processing_started_at", staleProcessingBefore);
    if (staleProcessingError) {
      // Keep the function backward-compatible during rollout: if the Edge
      // Function reaches production a moment before migration 069, continue
      // using the existing queue behavior instead of breaking all pushes. Any
      // other database error remains fatal and visible.
      const recoveryErrorText = JSON.stringify(staleProcessingError);
      if (!recoveryErrorText.includes("processing_started_at")) {
        throw staleProcessingError;
      }
    }

    const { data: queue, error: queueError } = await supabase
      .from("push_notification_queue")
      .select("id,notification_id,attempts")
      .in("status", ["pending", "failed"])
      .lt("attempts", 5)
      .order("created_at", { ascending: true })
      .limit(50);
    if (queueError) throw queueError;

    let sent = 0;
    let failed = 0;
    let processed = 0;

    for (const item of queue ?? []) {
      // Atomically claim this queue row. Multiple webhook invocations can overlap;
      // only the worker whose conditional UPDATE actually matched may send it.
      const { data: claimed, error: claimError } = await supabase
        .from("push_notification_queue")
        .update({ status: "processing", attempts: item.attempts + 1 })
        .eq("id", item.id)
        .in("status", ["pending", "failed"])
        .select("id")
        .maybeSingle();
      if (claimError) throw claimError;
      if (!claimed) continue;
      processed++;

      const { data: notification } = await supabase
        .from("notifications")
        .select("id,user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data")
        .eq("id", item.notification_id)
        .maybeSingle();

      if (!notification) {
        await supabase.from("push_notification_queue").update({
          status: "sent",
          processed_at: new Date().toISOString(),
          last_error: null,
        }).eq("id", item.id);
        continue;
      }

      // A queued call invitation can arrive long after the caller hung up.
      if (notification.type === "incoming_video_call" ||
          notification.type === "incoming_voice_call") {
        const roomId = String(notification.data?.room_id ?? "");
        const { data: session, error: sessionError } = await supabase
          .from("direct_call_sessions")
          .select("status,callee_id,created_at")
          .eq("room_id", roomId)
          .maybeSingle();
        if (sessionError) throw sessionError;
        const created = Date.parse(String(session?.created_at ?? ""));
        if (!session || session.status !== "ringing" ||
            session.callee_id !== notification.user_id ||
            !Number.isFinite(created) || created > Date.now() ||
            Date.now() - created > 90_000) {
          await supabase.from("push_notification_queue").update({
            status: "sent", processed_at: new Date().toISOString(),
            last_error: "call_invitation_expired",
          }).eq("id", item.id);
          continue;
        }
      }

      const { data: recipient } = await supabase
        .from("users")
        .select("notifications_enabled,call_sounds_enabled,notification_sounds_enabled")
        .eq("id", notification.user_id)
        .maybeSingle();

      if (recipient?.notifications_enabled === false) {
        await supabase.from("push_notification_queue").update({
          status: "sent",
          processed_at: new Date().toISOString(),
          last_error: "push_disabled_by_user",
        }).eq("id", item.id);
        continue;
      }

      const { data: tokens, error: tokenError } = await supabase
        .from("push_device_tokens")
        .select("id,token,locale,platform")
        .eq("user_id", notification.user_id);
      if (tokenError) throw tokenError;

      // Enrich direct-message pushes once per notification. Android uses this
      // data to render the official Conversation/Bubble UI without needing a
      // second database lookup on the phone.
      let messageSenderName = "";
      let messageSenderAvatar = "";
      let messagePreview = "";
      if (notification.type === "message") {
        if (notification.actor_id) {
          const { data: actor } = await supabase
            .from("users")
            .select("name,profile_image")
            .eq("id", notification.actor_id)
            .maybeSingle();
          messageSenderName = String(actor?.name ?? "").trim().slice(0, 80);
          messageSenderAvatar = String(actor?.profile_image ?? "").trim().slice(0, 1200);
        }
        const messageId = String(notification.data?.message_id ?? "").trim();
        if (messageId) {
          const { data: chatMessage } = await supabase
            .from("messages")
            .select("content,media_type")
            .eq("id", messageId)
            .maybeSingle();
          messagePreview = String(chatMessage?.content ?? "").trim().slice(0, 240);
          if (!messagePreview) {
            const mediaType = String(chatMessage?.media_type ?? "").toLowerCase();
            if (mediaType === "image") messagePreview = "📷 Photo";
            else if (mediaType) messagePreview = "Attachment";
          }
        }
      }

      let itemHadFailure = false;
      for (const device of tokens ?? []) {
        // Idempotency is tracked per queue row + device token. If a previous
        // attempt already delivered to this device, retry only the devices that
        // actually failed instead of alerting successful devices twice.
        let deliveryLedgerAvailable = true;
        const { data: previousDelivery, error: deliveryLookupError } = await supabase
          .from("push_notification_deliveries")
          .select("status,attempts")
          .eq("queue_id", item.id)
          .eq("token_id", device.id)
          .maybeSingle();
        if (deliveryLookupError) {
          const lookupText = JSON.stringify(deliveryLookupError);
          if (lookupText.includes("push_notification_deliveries") || lookupText.includes("PGRST205")) {
            deliveryLedgerAvailable = false;
          } else {
            throw deliveryLookupError;
          }
        }
        if (deliveryLedgerAvailable && previousDelivery?.status === "sent") {
          continue;
        }

        const useArabic = String(device.locale ?? "ar").toLowerCase().startsWith("ar");
        const directMessage = notification.type === "message";
        const title = directMessage && messageSenderName
          ? messageSenderName
          : (useArabic
            ? (notification.title_ar || notification.title_en || "زميل")
            : (notification.title_en || notification.title_ar || "Zameel"));
        const body = directMessage && messagePreview
          ? messagePreview
          : (useArabic
            ? (notification.body_ar || notification.body_en || "")
            : (notification.body_en || notification.body_ar || ""));

        const data: Record<string, string> = Object.fromEntries(
          Object.entries(notification.data ?? {}).map(([k, v]) => [k, String(v)]),
        );
        data.notification_id = String(notification.id);
        data.notification_type = String(notification.type);
        data.type = String(notification.type);
        data.title = String(title);
        data.body = String(body);
        if (directMessage) {
          data.sender_id = String(notification.actor_id ?? "");
          data.sender_name = messageSenderName || String(title);
          data.sender_avatar = messageSenderAvatar;
          data.message_preview = String(body);
          const { data: bubbleFlag } = await supabase.from("feature_flags")
            .select("is_enabled,display_mode")
            .eq("feature_key", "floating_chat_bubble")
            .eq("scope_type", "global").eq("scope_value", "*")
            .maybeSingle();
          data.bubble_enabled = String(!bubbleFlag ||
            (bubbleFlag.is_enabled === true && bubbleFlag.display_mode === "enabled"));
        }

        const incomingCall = notification.type === "incoming_video_call" ||
          notification.type === "incoming_voice_call";
        const playSound = incomingCall
          ? recipient?.call_sounds_enabled !== false
          : recipient?.notification_sounds_enabled !== false;
        data.play_sound = String(playSound);

        const platform = String(device.platform ?? "").toLowerCase();
        const androidBubbleMessage = directMessage && platform === "android";

        const fcmMessage: Record<string, unknown> = {
          token: device.token,
          data,
          android: androidBubbleMessage
            ? { priority: "HIGH" }
            : {
              priority: "HIGH",
              notification: {
                channel_id: incomingCall ? "zameel_calls_v2" : "zameel_notifications_v2",
                sound: playSound
                  ? (incomingCall ? "zameel_ringtone" : "zameel_notification")
                  : undefined,
              },
            },
        };

        // Android direct-chat messages are intentionally data-only so the
        // app's native bubble receiver can post one conversation notification
        // instead of FCM also creating a duplicate standard notification.
        if (!androidBubbleMessage) {
          fcmMessage.notification = { title, body };
          const conversationId = directMessage
            ? String(notification.data?.conversation_id ?? "").trim() : "";
          fcmMessage.apns = {
            headers: {
              "apns-priority": "10",
              ...(conversationId
                ? { "apns-collapse-id": `zameel-chat-${conversationId}` }
                : {}),
            },
            payload: {
              aps: {
                ...(conversationId ? { "thread-id": `zameel-chat-${conversationId}` } : {}),
                sound: playSound
                  ? (incomingCall ? "zameel_ringtone.wav" : "zameel_notification.wav")
                  : undefined,
                badge: 1,
              },
            },
          };
        }

        const payload = { message: fcmMessage };

        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "content-type": "application/json",
              authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(payload),
          },
        );

        if (response.ok) {
          sent++;
          if (deliveryLedgerAvailable) {
            await supabase.from("push_notification_deliveries").upsert({
              queue_id: item.id,
              token_id: device.id,
              status: "sent",
              attempts: Number(previousDelivery?.attempts ?? 0) + 1,
              last_error: null,
              sent_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            }, { onConflict: "queue_id,token_id" });
          }
          continue;
        }

        const text = await response.text();
        itemHadFailure = true;
        failed++;
        if (deliveryLedgerAvailable) {
          await supabase.from("push_notification_deliveries").upsert({
            queue_id: item.id,
            token_id: device.id,
            status: "failed",
            attempts: Number(previousDelivery?.attempts ?? 0) + 1,
            last_error: text.slice(0, 2000),
            sent_at: null,
            updated_at: new Date().toISOString(),
          }, { onConflict: "queue_id,token_id" });
        }
        if (isInvalidTokenResponse(response.status, text)) {
          await supabase.from("push_device_tokens").delete().eq("id", device.id);
        }
        await supabase.from("push_notification_queue").update({
          last_error: text.slice(0, 2000),
        }).eq("id", item.id);
      }

      await supabase.from("push_notification_queue").update({
        status: itemHadFailure ? "failed" : "sent",
        processed_at: itemHadFailure ? null : new Date().toISOString(),
      }).eq("id", item.id);
    }

    return new Response(JSON.stringify({ ok: true, sent, failed, processed }), {
      headers: { "content-type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ ok: false, error: String(error) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
