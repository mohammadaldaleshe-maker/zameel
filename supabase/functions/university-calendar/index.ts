import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SOURCES: Record<string, { name: string; domains: string[]; urls: string[] }> = {
  ju: {
    name: "الجامعة الأردنية",
    domains: ["ju.edu.jo", "registration.ju.edu.jo"],
    urls: ["https://registration.ju.edu.jo/", "https://ju.edu.jo/"],
  },
  yu: {
    name: "جامعة اليرموك",
    domains: ["yu.edu.jo", "admreg.yu.edu.jo"],
    urls: ["https://admreg.yu.edu.jo/index.php/unical", "https://www.yu.edu.jo/index.php/en/student"],
  },
  just: {
    name: "جامعة العلوم والتكنولوجيا الأردنية",
    domains: ["just.edu.jo"],
    urls: ["https://www.just.edu.jo/", "https://www.just.edu.jo/Academics/Pages/default.aspx"],
  },
  hu: {
    name: "الجامعة الهاشمية",
    domains: ["hu.edu.jo"],
    urls: ["https://hu.edu.jo/en/default.aspx?t=0", "https://hu.edu.jo/facnew/index.aspx?typ=79&unitid=73000000"],
  },
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { university_key = "ju" } = await req.json().catch(() => ({}));
    const source = SOURCES[university_key] || SOURCES.ju;
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) throw new Error("OPENAI_API_KEY_not_configured");
    const prompt = `Find the current academic calendar for ${source.name} for the current/next academic year. Search ONLY these official domains: ${source.domains.join(", ")}. Return JSON array only. Each item: {"title_ar":string,"title_en":string,"event_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD|null","time_text":"string|null","source_url":"official URL","source_title":"page title"}. Do not invent dates. If the official site does not publish a date, omit that item. Use the most recent official calendar. Candidate official pages: ${source.urls.join(" | ")}`;
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-5",
        tools: [{ type: "web_search" }],
        input: prompt,
      }),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data?.error?.message || "openai_request_failed");
    const raw = (data.output_text || "[]").trim().replace(/^```json\s*/i, "").replace(/```$/i, "");
    let events: unknown[] = [];
    try { events = JSON.parse(raw); } catch { events = []; }
    const cleaned = (events as any[]).filter((e) => e && /^\d{4}-\d{2}-\d{2}$/.test(e.event_date) && typeof e.source_url === "string");
    return new Response(JSON.stringify({ university_key, university_name: source.name, fetched_at: new Date().toISOString(), events: cleaned }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
