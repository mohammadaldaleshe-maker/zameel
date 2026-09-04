import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { message, mode = "assistant", language = "ar", university = "" } = await req.json();
    if (!message || typeof message !== "string") throw new Error("message_required");

    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) throw new Error("OPENAI_API_KEY_not_configured");

    const system = `You are Zameel AI, an academic assistant for university students. Answer accurately and practically. Language: ${language === "ar" ? "Arabic" : "English"}. University context: ${university || "unknown"}. Mode: ${mode}. If current facts, university announcements, schedules, or official information are needed, use web search and prefer official university/government domains. Clearly distinguish verified facts from suggestions.`;
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-5",
        tools: [{ type: "web_search" }],
        input: [
          { role: "system", content: [{ type: "input_text", text: system }] },
          { role: "user", content: [{ type: "input_text", text: message }] },
        ],
      }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data?.error?.message || "openai_request_failed");
    return new Response(JSON.stringify({ answer: data.output_text || "" }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
