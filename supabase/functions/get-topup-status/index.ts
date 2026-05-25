// ============================================================================
// Get Daily Top-up Status
// Returns user's daily top-up limits and current usage
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(message: string, status: number): Response {
  return jsonResponse({ success: false, error: message }, status);
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return jsonError('Method not allowed', 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // =========================================================================
    // 1. AUTH VALIDATION
    // =========================================================================
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonError('Missing Authorization header', 401);
    }

    const authMatch = authHeader.match(/^Bearer\s+(.*)$/i);
    if (!authMatch) {
      return jsonError('Invalid Authorization format', 401);
    }
    const jwtToken = authMatch[1].trim();

    const { data: { user }, error: authError } = await adminClient.auth.getUser(jwtToken);

    if (authError || !user) {
      console.error('[GetTopUpStatus] Auth failed:', authError);
      return jsonError('Unauthorized', 401);
    }

    // =========================================================================
    // 2. GET DAILY TOP-UP STATUS
    // =========================================================================
    const { data: statusData, error: statusError } = await adminClient.rpc(
      'get_daily_topup_status',
      { p_user_id: user.id },
    );

    if (statusError) {
      console.error('[GetTopUpStatus] RPC error:', statusError);
      return jsonError('Failed to retrieve top-up status', 500);
    }

    // Convert satang to baht for easier frontend consumption
    const status = statusData as {
      current_total: number;
      max_daily: number;
      remaining_limit: number;
      min_per_transaction: number;
      is_limit_reached: boolean;
    };

    return jsonResponse({
      success: true,
      limits: {
        current_total_satang: status.current_total,
        current_total_baht: status.current_total / 100,
        max_daily_satang: status.max_daily,
        max_daily_baht: status.max_daily / 100,
        remaining_limit_satang: status.remaining_limit,
        remaining_limit_baht: status.remaining_limit / 100,
        min_per_transaction_satang: status.min_per_transaction,
        min_per_transaction_baht: status.min_per_transaction / 100,
        is_limit_reached: status.is_limit_reached,
      },
    }, 200);
  } catch (error) {
    console.error('[GetTopUpStatus] Critical error:', error);
    const message = error instanceof Error ? error.message : 'Internal server error';
    return jsonError(message, 500);
  }
});
