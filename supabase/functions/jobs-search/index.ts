import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function normalizeJobs(items: any[], provider: string, location: string) {
  return items.map((job: any) => ({
    id: job.id?.toString() ?? job.slug?.toString() ?? crypto.randomUUID(),
    title_en: job.title ?? "",
    title_ar: job.title ?? "",
    company: job.company ?? job.company_name ?? "",
    type_en: Array.isArray(job.job_types) ? job.job_types.join(", ") : "Job",
    type_ar: "وظيفة",
    location_en: job.location ?? location,
    location_ar: job.location ?? location,
    description_en: job.snippet ?? job.description ?? "",
    description_ar: job.snippet ?? job.description ?? "",
    url: job.link ?? job.url ?? "",
    created_at: job.updated ?? job.created_at ?? "",
    isRemote: job.remote === true || /remote|عن بعد/i.test(`${job.location ?? ""} ${job.title ?? ""}`),
    color: 0xFF18D4C6,
    provider,
  }));
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const keywords = String(body?.q ?? "").trim() || "student jobs";
    const location = String(body?.location ?? "Jordan").trim() || "Jordan";
    const limit = Math.min(Math.max(Number(body?.results ?? 20), 1), 50);
    const apiKey = Deno.env.get("JOOBLE_API_KEY");
    if (apiKey) {
      const apiUrl = Deno.env.get("JOOBLE_API_URL") || "https://jooble.org/api/";
      const response = await fetch(`${apiUrl.replace(/\/$/, "")}/${apiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ keywords, location, page: 1, ResultOnPage: limit }),
      });
      if (response.ok) {
        const data = await response.json();
        return new Response(JSON.stringify({ jobs: normalizeJobs(Array.isArray(data?.jobs) ? data.jobs : [], "Jooble", location), provider_configured: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
    }

    // Free fallback provider; no API key required.
    const response = await fetch("https://www.arbeitnow.com/api/job-board-api", { headers: { "Accept": "application/json", "User-Agent": "Zameel/1.3.7" } });
    if (!response.ok) throw new Error(`Jobs provider returned ${response.status}`);
    const data = await response.json();
    const q = keywords.toLowerCase();
    const allItems = Array.isArray(data?.data) ? data.data : [];
    const matches = q ? allItems.filter((j: any) => `${j.title ?? ""} ${j.company_name ?? ""} ${j.description ?? ""} ${j.location ?? ""}`.toLowerCase().includes(q)) : allItems;
    const items = (matches.length ? matches : allItems).slice(0, limit);
    return new Response(JSON.stringify({ jobs: normalizeJobs(items, "Arbeitnow", location), provider_configured: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ jobs: [], provider_configured: true, error: String(e?.message ?? e) }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
