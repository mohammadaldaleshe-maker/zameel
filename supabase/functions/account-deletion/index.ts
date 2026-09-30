import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { processDeletion } from './worker.mjs';
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
});
Deno.serve(async (req) => {
  if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return reply({ error: 'service_not_configured' }, 503);
  const body = await req.json().catch(() => null);
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!body || !uuid.test(String(body.job_id)) || !uuid.test(String(body.token))) {
    return reply({ error: 'invalid_request' }, 400);
  }
  const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: job, error: claimError } = await db.rpc('zameel_claim_account_deletion', {
    p_job: body.job_id, p_token: body.token,
  });
  // No user-chosen target ID. A valid one-time job token is mandatory.
  if (claimError) return reply({ error: 'claim_unavailable' }, 503);
  if (!job) return reply({ error: 'invalid_job_token' }, 403);
  let stage = 'start';
  const must = (error: unknown) => { if (error) throw new Error(stage); };
  const rpc = async (name: string) => {
    stage = name;
    const { error } = await db.rpc(name, { p_job: job.id, p_lease: job.lease });
    must(error);
  };
  try {
    const state = await processDeletion(job, {
      ban: async (id: string) => {
        stage = 'disable_login';
        const { error } = await db.auth.admin.updateUserById(id, { ban_duration: '876000h' });
        // A previous retry may already have removed Auth but not marked completion.
        if (error && error.status !== 404) must(error);
      },
      discover: () => rpc('zameel_discover_account_files'),
      removeData: () => rpc('zameel_remove_account_data'),
      files: async (id: string, limit: number) => {
        stage = 'read_manifest';
        const { data, error } = await db.from('zameel_account_deletion_files')
          .select('bucket_id,name').eq('job_id', id).order('bucket_id').order('name').limit(limit);
        must(error); return data ?? [];
      },
      removeStorage: async (bucket: string, names: string[]) => {
        stage = 'remove_storage';
        const { error } = await db.storage.from(bucket).remove(names); must(error);
      },
      ackFiles: async (id: string, bucket: string, names: string[]) => {
        stage = 'acknowledge_storage';
        const { error } = await db.from('zameel_account_deletion_files').delete()
          .eq('job_id', id).eq('bucket_id', bucket).in('name', names); must(error);
      },
      deleteAuth: async (id: string) => {
        stage = 'remove_auth';
        const { error } = await db.auth.admin.deleteUser(id);
        if (error && error.status !== 404) must(error);
      },
      finish: () => rpc('zameel_finish_account_deletion'),
    });
    if (state === 'pending') {
      const { error } = await db.from('zameel_account_deletion_jobs').update({
        state: 'pending', lease_until: null, token: null,
        next_attempt_at: new Date(Date.now() + 60_000).toISOString(),
      }).eq('id', job.id).eq('token', job.lease);
      must(error);
    }
    return reply({ state });
  } catch (_) {
    // Record stage only, not credentials, email, tokens or arbitrary DB messages.
    const needsReview = job.attempts >= 10;
    const { error } = await db.from('zameel_account_deletion_jobs').update({
      state: needsReview ? 'review' : 'pending', last_error: stage,
      lease_until: null, token: null,
      next_attempt_at: new Date(Date.now() + 300_000).toISOString(),
    }).eq('id', job.id).eq('token', job.lease);
    if (error) return reply({ error: 'retry_state_unavailable' }, 503);
    return reply({ state: needsReview ? 'review' : 'pending', stage }, 202);
  }
});
