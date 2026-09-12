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
      processed++;
      await supabase
        .from("push_notification_queue")
        .update({ status: "processing", attempts: item.attempts + 1 })
        .eq("id", item.id)
        .in("status", ["pending", "failed"]);

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

      const { data: recipient } = await supabase
        .from("users")
        .select("notifications_enabled")
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
        .select("id,token,locale")
        .eq("user_id", notification.user_id);
      if (tokenError) throw tokenError;

      let itemHadFailure = false;
      for (const device of tokens ?? []) {
        const useArabic = String(device.locale ?? "ar").toLowerCase().startsWith("ar");
        const title = useArabic
          ? (notification.title_ar || notification.title_en || "زميل")
          : (notification.title_en || notification.title_ar || "Zameel");
        const body = useArabic
          ? (notification.body_ar || notification.body_en || "")
          : (notification.body_en || notification.body_ar || "");

        const data = Object.fromEntries(
          Object.entries(notification.data ?? {}).map(([k, v]) => [k, String(v)]),
        );
        data.notification_id = String(notification.id);
        data.notification_type = String(notification.type);

        const payload = {
          message: {
            token: device.token,
            notification: { title, body },
            data,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "zameel_high_importance",
                sound: "default",
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: { aps: { sound: "default", badge: 1 } },
            },
          },
        };

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
          continue;
        }

        const text = await response.text();
        itemHadFailure = true;
        failed++;
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
