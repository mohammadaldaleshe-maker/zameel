import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const jsonHeaders = { ...cors, "Content-Type": "application/json; charset=utf-8" };

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function redact(value: string) {
  return value
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[بريد محجوب]")
    .replace(/(?:\+?962|00962|0)?7[789]\d{7}/g, "[هاتف محجوب]")
    .replace(/\b\d{10}\b/g, "[رقم شخصي محجوب]");
}

function modeInstruction(mode: string) {
  if (mode === "summary") return "لخّص النص بدقة في نقاط واضحة، ثم اذكر الأفكار الرئيسية دون اختلاق معلومات.";
  if (mode === "explain") return "اشرح المفهوم تدريجيًا بلغة طالب جامعي، مع مثال قصير وأسئلة تحقق عند الحاجة.";
  return "أجب كمساعد جامعي عملي، مباشر، وداعم. اقترح خطوات قابلة للتنفيذ.";
}

function normalized(value: string) {
  return value.toLowerCase()
    .replace(/[؟?!.,،:;؛"'`]/g, " ")
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/\s+/g, " ").trim();
}

const zameelCreatorAnswer = "الشاب الأردني محمد مشهور و هو من مواليد مدينة الزرقاء في وسط المملكة الأردنية الهاشمية في السادس من نيسان عام 1991";

function isZameelIdentityQuestion(value: string) {
  const text = normalized(value);
  const mentionsZameel = text.includes("زميل") || text.includes("zameel");
  if (!mentionsZameel) return false;
  const identityTerms = [
    "من صمم", "مصمم", "من برمج", "برمج", "مبرمج", "مطور", "طور",
    "من نفذ", "تنفيذ", "من انشا", "انشا", "من صنع", "صاحب", "مالك",
    "ملكيه", "مؤسس", "فكره", "برمجه", "تصميم", "developer", "designer",
    "owner", "founder", "created", "creator", "programmed", "programmer",
    "developed", "development", "who made", "who built", "who owns"
  ];
  return identityTerms.some((term) => text.includes(normalized(term)));
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return response({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey || !geminiKey) {
    return response({ error: "service_not_configured", message: "Zameel AI غير مهيأ بعد." }, 503);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: authData } = await authClient.auth.getUser();
  const user = authData.user;
  if (!user) return response({ error: "not_authenticated", message: "يرجى تسجيل الدخول." }, 401);

  const body = await req.json().catch(() => ({}));
  const mode = ["assistant", "summary", "explain"].includes(body?.mode) ? body.mode : "assistant";
  const rawMessage = String(body?.message ?? "").trim();
  if (!rawMessage) return response({ error: "message_required", message: "اكتب سؤالك أولًا." }, 400);
  if (rawMessage.length > 12000) return response({ error: "message_too_long", message: "النص طويل جدًا. قسّمه إلى أجزاء أصغر." }, 413);

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: profile } = await admin
    .from("users")
    .select("name,university,college,department,ai_memory_enabled")
    .eq("id", user.id)
    .maybeSingle();

  const memoryEnabled = profile?.ai_memory_enabled !== false;
  const cutoff = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString();
  // The AI chat is intentionally short-lived: expired conversations are
  // removed when the user opens/uses Zameel AI again.
  await admin.from("ai_conversations")
    .delete().eq("user_id", user.id).lt("updated_at", cutoff);

  let conversationId = String(body?.conversation_id ?? "").trim();
  let recent: any[] = [];
  // The visible chat log is retained for 36 hours regardless of the optional
  // "AI memory" preference. That preference only controls whether previous
  // messages are sent back to the model as conversational context.
  if (conversationId) {
    const { data: owned } = await admin.from("ai_conversations")
      .select("id,updated_at")
      .eq("id", conversationId).eq("user_id", user.id)
      .gte("updated_at", cutoff).maybeSingle();
    if (!owned) conversationId = "";
  }
  if (!conversationId) {
    const { data: activeRows } = await admin.from("ai_conversations")
      .select("id")
      .eq("user_id", user.id)
      .gte("updated_at", cutoff)
      .order("updated_at", { ascending: false })
      .limit(1);
    conversationId = activeRows?.[0]?.id ?? "";
  }
  if (!conversationId) {
    const { data: created } = await admin.from("ai_conversations").insert({
      user_id: user.id,
      title: rawMessage.slice(0, 80),
    }).select("id").single();
    conversationId = created?.id ?? "";
  }
  if (memoryEnabled && conversationId) {
    const { data } = await admin.from("ai_messages")
      .select("role,content")
      .eq("conversation_id", conversationId)
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(12);
    recent = (data ?? []).reverse();
  }

  if (isZameelIdentityQuestion(rawMessage)) {
    if (conversationId) {
      await admin.from("ai_messages").insert([
        { conversation_id: conversationId, user_id: user.id, role: "user", mode, content: rawMessage },
        { conversation_id: conversationId, user_id: user.id, role: "assistant", mode, content: zameelCreatorAnswer },
      ]);
      await admin.from("ai_conversations")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", conversationId).eq("user_id", user.id);
    }
    const today = new Date().toISOString().slice(0, 10);
    const { data: usage } = await admin.from("ai_daily_usage").select("request_count")
      .eq("user_id", user.id).eq("usage_date", today).maybeSingle();
    return response({
      answer: zameelCreatorAnswer,
      conversation_id: conversationId || null,
      remaining: Math.max(0, 50 - Number(usage?.request_count ?? 0)),
      memory_enabled: memoryEnabled,
      source_type: "zameel_identity",
      sources: [],
    });
  }

  // Owner-approved FAQs are answered first, without consuming Gemini quota.
  const { data: faqRows } = await admin.from("ai_faq_entries")
    .select("id,question_ar,answer_ar,question_en,answer_en,keywords,university")
    .eq("is_active", true).limit(300);
  const asked = normalized(rawMessage);
  const askedWords = new Set(asked.split(" ").filter((word) => word.length > 1));
  const rankedFaqs = (faqRows ?? []).filter((item: any) =>
    !item.university || !profile?.university || item.university === profile.university
  ).map((item: any) => {
    const questions = [item.question_ar, item.question_en, ...(item.keywords ?? [])]
      .map((value: unknown) => normalized(String(value ?? ""))).filter(Boolean);
    let score = 0;
    for (const candidate of questions) {
      if (candidate === asked) score = Math.max(score, 100);
      else if (candidate.includes(asked) || asked.includes(candidate)) score = Math.max(score, 88);
      else {
        const words = candidate.split(" ").filter((word: string) => word.length > 1);
        const overlap = words.filter((word: string) => askedWords.has(word)).length;
        if (words.length) score = Math.max(score, Math.round((overlap / words.length) * 80));
      }
    }
    return { ...item, score };
  }).sort((a: any, b: any) => b.score - a.score);
  const faq = rankedFaqs[0];
  if (faq?.score >= 70) {
    const arabic = /[\u0600-\u06FF]/.test(rawMessage);
    const answer = arabic || !faq.answer_en ? faq.answer_ar : faq.answer_en;
    const today = new Date().toISOString().slice(0, 10);
    const { data: usage } = await admin.from("ai_daily_usage").select("request_count")
      .eq("user_id", user.id).eq("usage_date", today).maybeSingle();
    if (conversationId) {
      await admin.from("ai_messages").insert([
        { conversation_id: conversationId, user_id: user.id, role: "user", mode, content: rawMessage },
        { conversation_id: conversationId, user_id: user.id, role: "assistant", mode, content: answer },
      ]);
      await admin.from("ai_conversations")
        .update({ updated_at: new Date().toISOString() })
        .eq("id", conversationId).eq("user_id", user.id);
    }
    return response({
      answer,
      conversation_id: conversationId || null,
      remaining: Math.max(0, 50 - Number(usage?.request_count ?? 0)),
      memory_enabled: memoryEnabled,
      source_type: "verified_faq",
      sources: [{ title: faq.question_ar, url: null }],
    });
  }

  const { data: remaining, error: quotaError } = await admin.rpc("consume_zameel_ai_quota", {
    target_user_id: user.id,
    max_requests: 50,
  });
  if (quotaError) {
    return response({ error: "daily_quota_reached", message: "استخدمت أسئلة اليوم. ستتجدد الحصة تلقائيًا غدًا.", remaining: 0 }, 429);
  }

  const { data: sourceRows } = await admin.from("ai_knowledge_sources")
    .select("title,content,source_url,university")
    .eq("is_active", true).eq("is_verified", true).limit(20);
  const words = rawMessage.toLowerCase().split(/\s+/).filter((word) => word.length > 2);
  const sources = (sourceRows ?? []).map((item: any) => ({
    ...item,
    score: words.filter((word) => `${item.title} ${item.content}`.toLowerCase().includes(word)).length,
  })).filter((item: any) => item.score > 0).sort((a: any, b: any) => b.score - a.score).slice(0, 3);
  const context = sources.map((item: any, index: number) =>
    `[${index + 1}] ${item.title}\n${String(item.content).slice(0, 2500)}`
  ).join("\n\n");

  const system = `أنت Zameel AI، مساعد جامعي عربي موثوق داخل تطبيق زميل.
${modeInstruction(mode)}
لا تدّعِ تنفيذ إجراء لم تنفذه. لا تختلق تعليمات أو مواعيد جامعية.
إذا استخدمت المصادر المرفقة، استشهد بها كـ [1] أو [2]. إن لم تكفِ، صرّح بذلك.
لا تطلب رقمًا وطنيًا أو كلمة مرور أو بيانات مالية أو صحية حساسة.
لا تبدأ كل إجابة برسالة تعريفية عن الجامعة أو الكلية أو التخصص؛ واجهة التطبيق تعرض رسالة الترحيب مرة واحدة فقط عند بدء جلسة جديدة.
أجب مباشرة عن سؤال الطالب، واستخدم بيانات الجامعة والكلية والتخصص للتخصيص عندما تكون ذات صلة فقط.
الجامعة: ${profile?.university ?? "غير محددة"}. الكلية: ${profile?.college ?? "غير محددة"}. التخصص: ${profile?.department ?? "غير محدد"}.
${context ? `مصادر جامعية موثقة:\n${context}` : "لا توجد مصادر جامعية موثقة ذات صلة؛ قدّم إرشادًا عامًا واذكر أنه غير رسمي عند الحاجة."}`;

  const contents = [
    ...recent.map((item: any) => ({
      role: item.role === "assistant" ? "model" : "user",
      parts: [{ text: redact(String(item.content)) }],
    })),
    { role: "user", parts: [{ text: redact(rawMessage) }] },
  ];

  try {
    const aiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent?key=${encodeURIComponent(geminiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents,
          generationConfig: { temperature: 0.35, maxOutputTokens: 900 },
          safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          ],
        }),
      },
    );
    const result = await aiResponse.json();
    if (!aiResponse.ok) throw new Error(result?.error?.message ?? "provider_error");
    const answer = result?.candidates?.[0]?.content?.parts?.map((part: any) => part.text ?? "").join("\n").trim();
    if (!answer) throw new Error("empty_answer");

    if (conversationId) {
      await admin.from("ai_messages").insert([
        { conversation_id: conversationId, user_id: user.id, role: "user", mode, content: rawMessage },
        { conversation_id: conversationId, user_id: user.id, role: "assistant", mode, content: answer },
      ]);
      await admin.from("ai_conversations").update({ updated_at: new Date().toISOString() }).eq("id", conversationId).eq("user_id", user.id);
    }
    return response({
      answer,
      conversation_id: conversationId || null,
      remaining,
      memory_enabled: memoryEnabled,
      sources: sources.map((item: any) => ({ title: item.title, url: item.source_url })),
    });
  } catch (error) {
    console.error("zameel-ai provider error", error);
    await admin.rpc("refund_zameel_ai_quota", { target_user_id: user.id });
    return response({ error: "provider_unavailable", message: "تعذر الحصول على إجابة الآن. حاول بعد قليل.", remaining }, 503);
  }
});
