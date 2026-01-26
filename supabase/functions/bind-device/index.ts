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
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Admin Client for Privileged Operations (DB Writes)
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing auth', 401);

    // Validate Token using Standard Pattern (Client Context)
    const jwt = authHeader.replace(/^Bearer\s+/i, '');
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Explicitly pass JWT to ensure it is picked up
    const { data: { user }, error: authError } = await userClient.auth.getUser(jwt);

    if (authError || !user) {
      console.error('[BindDevice] Auth Failed:', authError);
      return jsonError('Unauthorized: ' + (authError?.message || 'Invalid Token'), 401);
    }

    // 2. Parse Body
    const { public_key, device_id, device_name, os_type, metadata, trust_score } = await req.json();

    if (!public_key || !device_id) {
      return jsonError('Missing public_key or device_id', 400);
    }

    console.log(
      `[BindDevice] Binding device for ${user.id}. Model: ${device_name || 'Unknown'} OS: ${
        os_type || 'Unknown'
      }`,
    );

    // 3. 🛡️ Atomic Rebind Strategy: DELETE old binding, then INSERT new.
    // This bypasses the missing unique constraint issue and ensures key rotation works.
    // Step 1: Delete any existing binding for this (user_id, device_id)
    await adminClient
      .from('user_device_bindings')
      .delete()
      .eq('user_id', user.id)
      .eq('device_id', device_id);

    console.log(`[BindDevice] Deleted old binding for device ${device_id}`);

    // Step 2: Insert the new binding with fresh public key
    const payload: any = {
      user_id: user.id,
      device_id: device_id,
      public_key: public_key,
      is_active: true,
      last_used_at: new Date().toISOString(),
      device_name: device_name || 'Unknown Device',
      os_type: os_type || 'web', // Default to 'web' to satisfy CHECK constraint
      metadata: metadata || {},
      trust_score: trust_score ?? 100,
    };

    const { error: bindError } = await adminClient
      .from('user_device_bindings')
      .insert(payload)
      .select();

    if (bindError) {
      console.error('[BindDevice] DB Insert Error:', bindError);
      return jsonError('Failed to bind device', 500);
    }

    // 4. Audit Log (Black Box)
    try {
      await adminClient.from('security_logs').insert({
        user_id: user.id,
        event_type: 'DEVICE_BIND',
        device_id: device_id,
        metadata: { device_name: device_name, os_type: os_type, timestamp: new Date() },
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
