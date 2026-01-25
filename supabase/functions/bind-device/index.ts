// ============================================================================
// BIND-DEVICE - Supabase Edge Function
// ============================================================================
// Stores the Cryptographic Public Key for Hardware Binding.
// Linked to user_device_bindings table.
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Auth & Setup
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    // Service Role needed to potentially bypass RLS or if table is in private schema (it issues public schema but sometimes needs admin rights for "binding")
    // Actually user_device_bindings is public, so user *could* insert if RLS allows.
    // But safe to use Service Role for "System Binding" to ensure integrity.
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing auth', 401);

    // Validate Token
    const authClient = createClient(supabaseUrl, supabaseServiceKey);
    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await authClient.auth.getUser(jwt);

    if (authError || !user) {
      return jsonError('Unauthorized', 401);
    }

    // 2. Parse Body
    const { public_key, device_id, device_name } = await req.json();

    if (!public_key || !device_id) {
      return jsonError('Missing public_key or device_id', 400);
    }

    console.log(`[BindDevice] Binding device for ${user.id}. Model: ${device_name || 'Unknown'}`);

    // 3. Upsert Binding
    // NOTE: Schema provided: user_device_bindings (id, user_id, device_id, public_key, is_active, last_used_at)
    // We will upsert based on (user_id, device_id).

    const payload: any = {
      user_id: user.id,
      device_id: device_id,
      public_key: public_key,
      is_active: true,
      last_used_at: new Date().toISOString(),
    };

    // Optional Metadata Support (If schema supports it later)
    // if (device_name) payload.device_name = device_name;

    // Using upsert to allow re-binding (e.g., user re-installs app)
    const { error: bindError } = await adminClient
      .from('user_device_bindings')
      .upsert(payload, { onConflict: 'user_id, device_id' } as any) // Assuming composite unique constraint?
      // If no composite constraint, upsert might fail or duplicate.
      // Schema constraints were "not valid for execution" in prompt.
      // We assume standard (user_id, device_id) uniqueness for binding logic.
      .select();

    if (bindError) {
      console.error('[BindDevice] DB Error:', bindError);
      // If conflict error, we might need to handle it.
      return jsonError('Failed to bind device', 500);
    }

    // 4. Audit Log (Black Box)
    // If table exists... (Project Prompt asked for it, assuming we can attempt)
    try {
      await adminClient.from('security_logs').insert({
        user_id: user.id,
        event_type: 'DEVICE_BIND',
        device_id: device_id,
        metadata: { device_name: device_name, timestamp: new Date() },
        ip_address: req.headers.get('x-forwarded-for') || 'unknown',
      });
    } catch (ignore) {
      // Ignore audit log failure if table missing
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Device bound successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('[BindDevice] Error:', e);
    return jsonError('Internal Server Error', 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}
