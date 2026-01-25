// ============================================================================
// Inbound Handler - Card Vaulting + Security Hardening Edition
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import {
  InboundRequest,
  OpnChargeRequest,
  OpnChargeResponse,
  OpnCustomerCreateRequest,
  OpnCustomerResponse,
  ServiceResponse,
} from './types.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ============================================================================
// Helper: Opn API Client
// ============================================================================

class OpnClient {
  private secretKey: string;
  private baseUrl = 'https://api.omise.co';

  constructor(secretKey: string) {
    this.secretKey = secretKey;
  }

  private authHeader(): string {
    return `Basic ${btoa(this.secretKey + ':')}`;
  }

  async createCustomer(email: string, cardToken?: string): Promise<OpnCustomerResponse> {
    const body: OpnCustomerCreateRequest = { email };
    if (cardToken) body.card = cardToken;

    const resp = await fetch(`${this.baseUrl}/customers`, {
      method: 'POST',
      headers: {
        'Authorization': this.authHeader(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`Opn Customer Create Failed: ${err}`);
    }

    return resp.json();
  }

  async getCustomer(customerId: string): Promise<OpnCustomerResponse> {
    const resp = await fetch(`${this.baseUrl}/customers/${customerId}`, {
      headers: { 'Authorization': this.authHeader() },
    });

    if (!resp.ok) {
      throw new Error(`Opn Customer Not Found: ${customerId}`);
    }

    return resp.json();
  }

  async attachCard(customerId: string, cardToken: string): Promise<OpnCustomerResponse> {
    const resp = await fetch(`${this.baseUrl}/customers/${customerId}`, {
      method: 'PATCH',
      headers: {
        'Authorization': this.authHeader(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ card: cardToken }),
    });

    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`Opn Attach Card Failed: ${err}`);
    }

    return resp.json();
  }

  async createCharge(payload: OpnChargeRequest): Promise<OpnChargeResponse> {
    const resp = await fetch(`${this.baseUrl}/charges`, {
      method: 'POST',
      headers: {
        'Authorization': this.authHeader(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    return resp.json();
  }
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const omiseSecretKey = Deno.env.get('OMISE_SECRET_KEY')!;

  const opn = new OpnClient(omiseSecretKey);
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // ========================================================================
    // 1. AUTH VALIDATION
    // ========================================================================
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error('[Auth] Missing Authorization header');
      return jsonError('Missing Authorization header', 401);
    }

    // 🛡️ Permissive Header Parsing: Handle "Bearer <token>" case-insensitively with regex
    const authMatch = authHeader.match(/^Bearer\s+(.*)$/i);
    if (!authMatch) {
      console.error('[Auth] Malformed Authorization header:', authHeader);
      return jsonError('Invalid Authorization format', 401);
    }
    const jwtToken = authMatch[1].trim();

    // 🛡️ World-Class Logging: Log first 10 chars of JWT for trace visibility
    console.log(`[Auth] Validating JWT with AdminClient (Prefix: ${jwtToken.substring(0, 10)}...)`);

    // 🎯 Use Admin Client for robust verification (Bypasses brittle raw fetch)
    const { data: { user }, error: authError } = await adminClient.auth.getUser(jwtToken);

    if (authError || !user) {
      console.error('[Auth] Validation failed:', authError);
      return jsonError('Unauthorized: Session is invalid or poisoned. Please log in again.', 401);
    }

    const { id: userId, email: userEmail } = user;
    console.log(`[Auth] User verified: ${userId} (${userEmail})`);

    // ========================================================================
    // 2. INPUT PARSING
    // ========================================================================
    const body: InboundRequest = await req.json();
    const { amount_satang, token, card_id, is_apple_pay, reference_id, description } = body;

    if (!amount_satang || !reference_id) {
      return jsonError('Missing required fields (amount_satang, reference_id)', 400);
    }

    console.log(`[Request] TopUp ${amount_satang} satang, ref: ${reference_id}`);

    // ========================================================================
    // 3. IDEMPOTENCY CHECK
    // ========================================================================
    const { data: existingTxn } = await adminClient
      .from('transactions')
      .select('id, status')
      .eq('reference_id', reference_id)
      .maybeSingle();

    if (existingTxn) {
      console.log(`[Idempotency] Duplicate reference_id: ${reference_id}`);
      return jsonResponse({
        success: true,
        message: 'Transaction already processed',
        data: { transaction_id: existingTxn.id, status: existingTxn.status },
      }, 200);
    }

    // ========================================================================
    // 4. KYC GATE (Optional - Skip if no record)
    // ========================================================================
    const { data: kycRecord } = await adminClient
      .from('identity_verification')
      .select('kyc_status')
      .eq('user_id', userId)
      .maybeSingle();

    if (kycRecord?.kyc_status === 'REJECTED') {
      console.log(`[KYC] User ${userId} is REJECTED`);
      return jsonError('KYC verification rejected. Contact support.', 403, 'KYC_REJECTED');
    }

    // ========================================================================
    // 5. CARD VAULTING - Get or Create Customer
    // ========================================================================
    const { data: profile } = await adminClient
      .from('profiles')
      .select('id, email, omise_customer_id')
      .eq('id', userId)
      .single();

    if (!profile) {
      return jsonError('Profile not found', 404);
    }

    let omiseCustomerId = profile.omise_customer_id;
    let chargeCard: string | undefined;

    if (!omiseCustomerId) {
      // Case A: New Customer - Create in Opn
      console.log(`[Vault] Creating new Opn Customer for ${userId}`);

      if (!token) {
        return jsonError('Card token required for first top-up', 400, 'TOKEN_REQUIRED');
      }

      const customer = await opn.createCustomer(userEmail || profile.email, token);
      omiseCustomerId = customer.id;

      // Save to profile
      await adminClient
        .from('profiles')
        .update({ omise_customer_id: omiseCustomerId })
        .eq('id', userId);

      console.log(`[Vault] Saved omise_customer_id: ${omiseCustomerId}`);
      // Card is already attached during customer creation
      chargeCard = customer.default_card || undefined;
    } else {
      // Case B: Existing Customer
      console.log(`[Vault] Existing customer: ${omiseCustomerId}`);

      if (token) {
        // Attach new card
        console.log(`[Vault] Attaching new card to customer`);
        const updated = await opn.attachCard(omiseCustomerId, token);
        chargeCard = updated.default_card || undefined;
      } else if (card_id) {
        // 🎯 EXACT FIX: Use the specific card ID passed from the app
        console.log(`[Vault] Using specific card selection: ${card_id}`);
        chargeCard = card_id;
      } else {
        // Use default card as a final fallback
        console.log(`[Vault] No specific card_id, fetching default card`);
        const customer = await opn.getCustomer(omiseCustomerId);
        chargeCard = customer.default_card || undefined;

        if (!chargeCard) {
          return jsonError('No saved card found. Please add a card.', 400, 'NO_CARD');
        }
      }
    }

    // ========================================================================
    // 6. CREATE CHARGE
    // ========================================================================
    console.log(`[Opn] Creating charge for ${amount_satang} satang...`);

    const chargePayload: OpnChargeRequest = {
      amount: amount_satang,
      currency: 'thb',
      customer: omiseCustomerId,
      card: chargeCard,
      description: `TopUp: ${description ?? 'Wallet'} (Ref: ${reference_id})`,
      capture: true,
      metadata: { reference_id, user_id: userId },
    };

    const charge = await opn.createCharge(chargePayload);
    console.log(`[Opn] Charge result: ${charge.status} (${charge.id})`);

    if (charge.status !== 'successful' && charge.status !== 'pending') {
      console.error(`[Opn] Charge failed: ${charge.failure_message}`);
      return jsonError(charge.failure_message || 'Payment failed', 400, 'CHARGE_FAILED');
    }

    // ========================================================================
    // 7. ATOMIC LEDGER UPDATE
    // ========================================================================
    console.log(`[DB] Executing RPC process_inbound_transaction...`);

    const { data: rpcData, error: rpcError } = await adminClient.rpc(
      'process_inbound_transaction',
      {
        p_user_id: userId,
        p_amount_satang: amount_satang,
        p_provider: 'omise',
        p_provider_txn_id: charge.id,
        p_reference_id: reference_id,
        p_description: description ?? 'Top Up',
        p_metadata: charge,
      },
    );

    if (rpcError) {
      console.error(`[DB] RPC Failed after successful charge!`, rpcError);

      // ======================================================================
      // 8. FAILURE RECOVERY - Log to Outbox
      // ======================================================================
      await adminClient.from('transaction_outbox').insert({
        transaction_id: null, // We don't have one yet
        event_type: 'INBOUND_CHARGE_SUCCESS_DB_FAIL',
        payload: {
          user_id: userId,
          amount_satang,
          charge_id: charge.id,
          reference_id,
          error: rpcError.message,
        },
        status: 'PENDING_RECONCILE',
      });

      console.log(`[Outbox] Logged for reconciliation: ${charge.id}`);

      // Still return success - money was taken, we'll reconcile later
      return jsonResponse({
        success: true,
        message: 'Payment successful. Balance update pending.',
        data: { charge_id: charge.id, status: 'PENDING_RECONCILE' },
      }, 202);
    }

    console.log(`[DB] RPC Success:`, rpcData);

    // ========================================================================
    // 8.5 UPDATE USER PREFERENCE & INVALIDATE CACHE (Returning User Pattern)
    // ========================================================================
    if (charge.card?.id) {
      console.log(`[Preference] Updating preferred_payment_method for ${userId}...`);
      await adminClient
        .from('profiles')
        .update({
          preferred_payment_method_id: charge.card.id,
          preferred_payment_method_type: 'card',
        })
        .eq('id', userId);
    }

    // Invalidate Card Cache (Redis-like experience)
    console.log(`[Cache] Invalidating card cache for ${userId} (Top-up success)`);
    await adminClient.from('cache_saved_cards').delete().eq('user_id', userId);

    // ========================================================================
    // 9. SUCCESS RESPONSE
    // ========================================================================
    return jsonResponse({
      success: true,
      message: 'Top-up successful',
      data: {
        charge_id: charge.id,
        ...rpcData,
      },
    }, 200);
  } catch (error) {
    console.error(`[Error] Unhandled:`, error);
    return jsonError(
      error instanceof Error ? error.message : 'Internal Server Error',
      500,
    );
  }
});

// ============================================================================
// Helper Functions
// ============================================================================

function jsonResponse<T>(body: ServiceResponse<T>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(message: string, status: number, code?: string): Response {
  return jsonResponse({ success: false, message, error: message, error_code: code }, status);
}
