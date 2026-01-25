// ============================================================================
// PAYOUT-EXECUTOR - Supabase Edge Function
// ============================================================================
// This is the "Hand" that executes payout requests.
//
// Flow:
// 1. Receive request from Flutter
// 2. Call RPC process_payout_request (atomic balance deduction)
// 3. Execute gateway payout (mock/real)
// 4. Update transaction status based on result
// ============================================================================

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

import {
  GatewayPayoutRequest,
  mapTargetType,
  PayoutRequest,
  PayoutResponse,
  RpcResult,
} from './types.ts';

import { createGateway } from './gateway.ts';

// ============================================================================
// CORS Headers
// ============================================================================
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ============================================================================
// Supabase Client (Service Role - bypasses RLS)
// ============================================================================
function getSupabaseClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing Supabase environment variables');
  }

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

// ============================================================================
// Request Validation
// ============================================================================
function validateRequest(body: unknown): PayoutRequest {
  if (!body || typeof body !== 'object') {
    throw new Error('Request body must be a JSON object');
  }

  const req = body as Record<string, unknown>;

  // Required fields
  if (!req.user_id || typeof req.user_id !== 'string') {
    throw new Error('user_id is required and must be a string (UUID)');
  }

  if (!req.wallet_id || typeof req.wallet_id !== 'string') {
    throw new Error('wallet_id is required and must be a string (UUID)');
  }

  if (!req.amount_satang || typeof req.amount_satang !== 'number' || req.amount_satang <= 0) {
    throw new Error('amount_satang is required and must be a positive number');
  }

  if (!req.target_type || !['MOBILE', 'NATID', 'EWALLET'].includes(req.target_type as string)) {
    throw new Error('target_type is required and must be MOBILE, NATID, or EWALLET');
  }

  if (!req.target_value || typeof req.target_value !== 'string' || req.target_value.length < 5) {
    throw new Error('target_value is required and must be at least 5 characters');
  }

  return {
    user_id: req.user_id as string,
    wallet_id: req.wallet_id as string,
    amount_satang: req.amount_satang as number,
    target_type: req.target_type as 'MOBILE' | 'NATID' | 'EWALLET',
    target_value: req.target_value as string,
    description: (req.description as string) || 'Paysif Payout',
  };
}

// ============================================================================
// Main Handler
// ============================================================================
async function handlePayoutRequest(request: Request): Promise<Response> {
  console.log('[PayoutExecutor] New request received');

  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Only accept POST
  if (request.method !== 'POST') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // =========================================================================
  // JWT Verification - Verify the user is authenticated
  // =========================================================================
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.error('[PayoutExecutor] Missing or invalid Authorization header');
    return new Response(
      JSON.stringify({ success: false, error: 'Missing authorization token' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Verify JWT using Supabase client
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;

  // Extract JWT
  const authMatch = authHeader.match(/^Bearer\s+(.*)$/i);
  if (!authMatch) {
    console.error('[PayoutExecutor] Malformed Authorization header');
    return new Response(
      JSON.stringify({ success: false, error: 'Invalid Authorization format' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
  const jwt = authMatch[1].trim();

  // Create an admin client for robust verification
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  // 🎯 Use Admin Client for robust verification (Bypasses brittle raw fetch)
  const { data: { user }, error: authError } = await adminClient.auth.getUser(jwt);

  if (authError || !user) {
    console.error(
      '[PayoutExecutor] JWT verification failed:',
      authError?.message || 'No user found',
    );
    // Log truncated token for debugging
    console.log(`[PayoutExecutor] Token Prefix: ${jwt.substring(0, 10)}...`);

    return new Response(
      JSON.stringify({
        success: false,
        error: 'Unauthorized: Session is invalid or poisoned.',
        debug: { auth_header_len: authHeader.length },
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  console.log('[PayoutExecutor] User authenticated:', user.id);

  try {
    // STEP 1: Parse and validate request
    const body = await request.json();
    const payoutRequest = validateRequest(body);

    // Security: Verify user_id in request matches authenticated user
    if (payoutRequest.user_id !== user.id) {
      console.error('[PayoutExecutor] User ID mismatch:', payoutRequest.user_id, '!=', user.id);
      return new Response(
        JSON.stringify({ success: false, error: 'User ID mismatch' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    console.log('[PayoutExecutor] Request validated:', payoutRequest.user_id);

    // STEP 2: Get Supabase client (Service Role for DB operations)
    const supabase = getSupabaseClient();

    // STEP 3: Call RPC for atomic balance deduction
    console.log('[PayoutExecutor] Calling process_payout_request RPC...');
    const { data: rpcResult, error: rpcError } = await supabase
      .rpc('process_payout_request', {
        p_user_id: payoutRequest.user_id,
        p_wallet_id: payoutRequest.wallet_id,
        p_amount_satang: payoutRequest.amount_satang,
        p_target_type: payoutRequest.target_type,
        p_target_value: payoutRequest.target_value,
        p_description: payoutRequest.description,
      })
      .single();

    if (rpcError) {
      console.error('[PayoutExecutor] RPC Error:', rpcError);
      throw new Error(`Database error: ${rpcError.message}`);
    }

    const result = rpcResult as RpcResult;
    console.log('[PayoutExecutor] RPC Result:', result);

    // Check if RPC returned error status
    if (result.status_code !== 200 || !result.transaction_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: result.status_message,
        } as PayoutResponse),
        {
          status: result.status_code >= 400 && result.status_code < 500 ? result.status_code : 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const transactionId = result.transaction_id;
    console.log('[PayoutExecutor] Transaction created:', transactionId);

    // STEP 4: Map target type to gateway format
    const gatewayTargetType = mapTargetType(payoutRequest.target_type);

    // STEP 5: Prepare gateway request
    const gatewayRequest: GatewayPayoutRequest = {
      reference_id: transactionId,
      amount_satang: payoutRequest.amount_satang,
      target_type: gatewayTargetType,
      target_value: payoutRequest.target_value,
      description: payoutRequest.description || 'Paysif Payout',
      timestamp: new Date().toISOString(),
    };

    // STEP 6: Execute gateway payout
    console.log('[PayoutExecutor] Executing gateway payout...');
    const gateway = createGateway();
    const gatewayResponse = await gateway.execute(gatewayRequest);
    console.log('[PayoutExecutor] Gateway response:', gatewayResponse);

    // STEP 7: Update transaction status based on gateway result
    if (gatewayResponse.success) {
      // SUCCESS: Update transaction and outbox
      console.log('[PayoutExecutor] Payout successful, updating records...');

      await supabase
        .from('transactions')
        .update({
          status: 'SUCCESS',
          provider_metadata: {
            gateway_ref: gatewayResponse.gateway_ref,
            target_type: payoutRequest.target_type,
            target_value: payoutRequest.target_value,
            completed_at: new Date().toISOString(),
            raw_response: gatewayResponse.raw_response,
          },
        })
        .eq('id', transactionId);

      await supabase
        .from('transaction_outbox')
        .update({
          status: 'PROCESSED',
        })
        .eq('transaction_id', transactionId);

      return new Response(
        JSON.stringify({
          success: true,
          transaction_id: transactionId,
          gateway_ref: gatewayResponse.gateway_ref,
          status: 'SUCCESS',
        } as PayoutResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    } else {
      // FAILURE: Update transaction with error
      console.error('[PayoutExecutor] Payout failed:', gatewayResponse.error_message);

      await supabase
        .from('transactions')
        .update({
          status: 'FAILED',
          provider_metadata: {
            error_code: gatewayResponse.error_code,
            error_message: gatewayResponse.error_message,
            target_type: payoutRequest.target_type,
            target_value: payoutRequest.target_value,
            failed_at: new Date().toISOString(),
          },
        })
        .eq('id', transactionId);

      await supabase
        .from('transaction_outbox')
        .update({
          status: 'FAILED',
        })
        .eq('transaction_id', transactionId);

      // NOTE: In production, this would trigger refund/reversal logic
      // For now, we just mark as failed

      return new Response(
        JSON.stringify({
          success: false,
          transaction_id: transactionId,
          status: 'FAILED',
          error: gatewayResponse.error_message || 'Gateway payout failed',
        } as PayoutResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
  } catch (error) {
    console.error('[PayoutExecutor] Unhandled error:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error occurred',
      } as PayoutResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
}

// ============================================================================
// Serve
// ============================================================================
serve(handlePayoutRequest);
