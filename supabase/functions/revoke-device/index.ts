// ============================================================================
// REVOKE-DEVICE - Supabase Edge Function
// ============================================================================
// Securely invalidates a bound device.
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

    // We need normal client to check user first
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing auth', 401);

    const authClient = createClient(supabaseUrl, supabaseServiceKey);
    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await authClient.auth.getUser(jwt);

    if (authError || !user) {
      return jsonError('Unauthorized', 401);
    }

    // 2. Parse Body
    const { device_id, reason } = await req.json();

    if (!device_id) {
      return jsonError('Missing device_id', 400);
    }

    console.log(`[RevokeDevice] Revoking device ${device_id} for user ${user.id}`);

    // 3. Perform Revocation (Logical Delete)
    // We use Service Role to perform the update to ensure it bypasses any restrictive policies
    // but we use the user.id filter to ensure we only touch their data.
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify ownership first/implicitly by filter
    const { data, error: revokeError } = await adminClient
      .from('user_device_bindings')
      .update({
        is_active: false,
        revoked_at: new Date().toISOString(),
        revoked_reason: reason || 'User Action',
      })
      .eq('user_id', user.id) // IMPORTANT: Ownership guarantee
      .eq('device_id', device_id)
      .select();

    if (revokeError) {
      console.error('[RevokeDevice] DB Error:', revokeError);
      return jsonError('Failed to revoke device', 500);
    }

    if (!data || data.length === 0) {
      // Could mean device doesn't exist OR belongs to another user
      return jsonError('Device not found or access denied', 404);
    }

    // 4. Audit Log
    try {
      await adminClient.from('security_logs').insert({
        user_id: user.id,
        event_type: 'DEVICE_REVOKE',
        device_id: device_id,
        metadata: { timestamp: new Date() },
        ip_address: req.headers.get('x-forwarded-for') || 'unknown',
      });
    } catch (ignore) {
      // Ignore
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Device revoked successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('[RevokeDevice] Error:', e);
    return jsonError('Internal Server Error', 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}
