import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(url, key);

    const auth = req.headers.get('Authorization');
    if (!auth) return err('Missing auth', 401);
    const { data: { user }, error } = await admin.auth.getUser(auth.replace(/^Bearer /i, ''));
    if (error || !user) return err('Unauthorized', 401);

    const { pin } = await req.json().catch(() => ({}));
    if (!pin || typeof pin !== 'string' || pin.length !== 6 || !/^\d+$/.test(pin))
      return err('PIN must be an 8-digit number', 400);

    // DB does Argon2id hashing via pgsodium
    const { error: rpcErr } = await admin.rpc('setup_user_pin_v2', { p_user_id: user.id, p_pin: pin });
    if (rpcErr) { console.error('[setup-pin]', rpcErr); return err('Setup failed', 500); }

    return ok({ success: true });
  } catch (e) {
    console.error('[setup-pin] fatal:', e);
    return err('Internal error', 500);
  }
});

function ok(b: unknown) { return new Response(JSON.stringify(b), { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } }); }
function err(m: string, s: number) { return new Response(JSON.stringify({ success: false, error: m }), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } }); }
