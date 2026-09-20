import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function cleanHtml(value: unknown) {
  return String(value ?? "")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function normalize(job: any, provider: string, fallbackLocation: string) {
  const title = cleanHtml(job.title);
  const company = cleanHtml(job.company ?? job.company_name);
  const location = cleanHtml(job.location ?? job.candidate_required_location) || fallbackLocation;
  const type = cleanHtml(job.job_type ?? (Array.isArray(job.job_types) ? job.job_types.join(", ") : "Job"));
  const url = String(job.url ?? job.link ?? "");
  const remote = job.remote === true || /remote|عن بعد/i.test(`${location} ${title} ${type}`);
  const internship = /intern|trainee|training/i.test(`${title} ${type}`);
  return {
    id: String(job.id ?? job.slug ?? `${provider}:${company}:${title}`),
    title_en: title,
    title_ar: title,
    company,
    type_en: type || "Job",
    type_ar: internship ? "تدريب" : "وظيفة",
    location_en: location,
    location_ar: location,
    description_en: cleanHtml(job.description ?? job.snippet).slice(0, 5000),
    description_ar: cleanHtml(job.description ?? job.snippet).slice(0, 5000),
    requirements_en: "",
    requirements_ar: "",
    salary: cleanHtml(job.salary) || "غير محدد",
    deadline: "مفتوح",
    url,
    created_at: String(job.publication_date ?? job.created_at ?? job.updated ?? ""),
    isRemote: remote,
    isUrgent: false,
    provider,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json().catch(() => ({}));
    const query = String(body?.q ?? "").trim();
    const location = String(body?.location ?? "Jordan").trim() || "Jordan";
    const limit = Math.min(Math.max(Number(body?.results ?? 30), 1), 50);
    const needles = query.toLowerCase().split(/\s+/).filter((part: string) => part.length > 1);

    const [arbeitnow, remotive] = await Promise.allSettled([
      fetch("https://www.arbeitnow.com/api/job-board-api", {
        headers: { Accept: "application/json", "User-Agent": "Zameel/2.0" },
      }).then((response) => response.ok ? response.json() : { data: [] }),
      fetch(`https://remotive.com/api/remote-jobs?limit=${Math.max(limit, 30)}`, {
        headers: { Accept: "application/json", "User-Agent": "Zameel/2.0" },
      }).then((response) => response.ok ? response.json() : { jobs: [] }),
    ]);

    const external = [
      ...(arbeitnow.status === "fulfilled" && Array.isArray(arbeitnow.value?.data)
        ? arbeitnow.value.data.map((job: any) => normalize(job, "Arbeitnow", location)) : []),
      ...(remotive.status === "fulfilled" && Array.isArray(remotive.value?.jobs)
        ? remotive.value.jobs.map((job: any) => normalize(job, "Remotive", location)) : []),
    ];

    let partnerJobs: any[] = [];
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (supabaseUrl && serviceKey) {
      const admin = createClient(supabaseUrl, serviceKey);
      const { data } = await admin
        .from("job_opportunities")
        .select("*")
        .eq("is_active", true)
        .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
        .order("published_at", { ascending: false })
        .limit(100);
      partnerJobs = (data ?? []).map((job: any) => normalize({
        id: job.id,
        title: job.title_ar || job.title,
        company: job.company,
        location: job.location,
        description: job.description,
        job_type: job.opportunity_type,
        remote: job.work_mode === "remote",
        salary: job.salary_text,
        url: job.apply_url || job.source_url,
        created_at: job.published_at,
      }, "Zameel Partners", location));
    }

    const all = [...partnerJobs, ...external];
    const unique = new Map<string, any>();
    for (const job of all) {
      if (!job.title_en || !job.company || !job.url) continue;
      const key = `${job.company}|${job.title_en}|${job.url}`.toLowerCase();
      if (!unique.has(key)) unique.set(key, job);
    }
    const jobs = [...unique.values()];
    const matched = needles.length === 0 ? jobs : jobs.filter((job) => {
      const haystack = `${job.title_en} ${job.company} ${job.description_en} ${job.location_en} ${job.type_en}`.toLowerCase();
      return needles.some((needle: string) => haystack.includes(needle));
    });
    const selected = (matched.length >= Math.min(5, limit) ? matched : jobs).slice(0, limit);
    return new Response(JSON.stringify({ jobs: selected, refreshed_at: new Date().toISOString() }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ jobs: [], error: String(error?.message ?? error) }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
