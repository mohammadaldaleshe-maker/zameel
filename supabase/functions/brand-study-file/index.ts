import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const authorization = request.headers.get('Authorization') ?? '';
    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: userData, error: userError } = await client.auth.getUser();
    if (userError || !userData.user) return new Response('Unauthorized', { status: 401, headers: corsHeaders });

    const body = await request.json();
    const storagePath = String(body.storage_path ?? '');
    const logoBase64 = String(body.logo_base64 ?? '');
    if (!storagePath || !logoBase64) return new Response('Invalid request', { status: 400, headers: corsHeaders });

    const { data: file, error: downloadError } = await client.storage.from('study_files').download(storagePath);
    if (downloadError || !file) return new Response('File unavailable', { status: 404, headers: corsHeaders });

    const pdf = await PDFDocument.load(await file.arrayBuffer());
    const logoBytes = Uint8Array.from(atob(logoBase64), (c) => c.charCodeAt(0));
    const logo = await pdf.embedPng(logoBytes);
    for (const page of pdf.getPages()) {
      const size = 42;
      page.drawImage(logo, {
        x: page.getWidth() - size - 18,
        y: 18,
        width: size,
        height: size,
        opacity: 0.22,
      });
    }
    const output = await pdf.save();
    return new Response(output, {
      headers: { ...corsHeaders, 'Content-Type': 'application/pdf', 'Content-Disposition': 'attachment; filename="Zameel_study_file.pdf"' },
    });
  } catch (error) {
    return new Response(`Branding failed: ${error}`, { status: 500, headers: corsHeaders });
  }
});
