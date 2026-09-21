import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json; charset=utf-8' },
});

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);
  const expected = Deno.env.get('ZAMEEL_MAINTENANCE_SECRET') ?? '';
  if (!expected || request.headers.get('x-zameel-maintenance-secret') !== expected) {
    return json({ ok: false, error: 'unauthorized' }, 401);
  }

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return json({ ok: false, error: 'missing_server_configuration' }, 500);
  const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });

  const now = new Date();
  const { data: expired, error: readError } = await supabase
    .from('zameel_radio_posts')
    .select('id,storage_path')
    .lte('expires_at', now.toISOString())
    .limit(500);
  if (readError) return json({ ok: false, error: readError.message }, 500);

  const paths = (expired ?? []).map((row) => row.storage_path).filter(Boolean);
  if (paths.length > 0) {
    const { error: storageError } = await supabase.storage.from('zameel-radio').remove(paths);
    if (storageError) return json({ ok: false, error: storageError.message }, 500);
    const ids = (expired ?? []).map((row) => row.id);
    const { error: deleteError } = await supabase.from('zameel_radio_posts').delete().in('id', ids);
    if (deleteError) return json({ ok: false, error: deleteError.message }, 500);
  }

  const jordanParts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Amman', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23',
  }).formatToParts(now);
  const part = (type: string) => jordanParts.find((item) => item.type === type)?.value ?? '';
  const jordanDate = `${part('year')}-${part('month')}-${part('day')}`;
  let winner: string | null = null;
  if (Number(part('hour')) >= 20) {
    const { data, error } = await supabase.rpc('zameel_select_college_winner', { p_cycle: jordanDate });
    if (error) return json({ ok: false, error: error.message }, 500);
    winner = data;
  }

  return json({ ok: true, deletedRadioPosts: paths.length, winner });
});
