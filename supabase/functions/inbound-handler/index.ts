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
import * as ed from 'https://esm.sh/@noble/ed25519@2.0.0';
import { sha512 } from 'https://esm.sh/@noble/hashes@1.3.1/sha512';
import { decode as base64Decode } from 'https://deno.land/std@0.168.0/encoding/base64.ts';

// 🛡️ CRITICAL: Configure SHA-512 for @noble/ed25519 v2
// v2 requires manual hash configuration, otherwise verify() fails silently!
ed.etc.sha512Sync = (...m: Uint8Array[]) => sha512(ed.etc.concatBytes(...m));

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
  const _supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
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
    const {
      amount_satang,
      wallet_amount_satang,
      token,
      card_id,
      is_apple_pay: _is_apple_pay,
      reference_id,
      description,
    } = body;

    if (!amount_satang || !reference_id) {
      return jsonError('Missing required fields (amount_satang, reference_id)', 400);
    }

    // 💎 Fee Handling: MONEY CORRECTNESS RE-ENGINEERING
    // The amount the user enters (e.g., 500 THB) should be EXACTLY what they get
    // in their wallet and what shows in their history.

    // 1. Determine the Intended Wallet Credit (Net)
    // We prioritize what the user intended to add.
    const targetNetSatang = wallet_amount_satang || amount_satang;

    const OMISE_FEERATE = 0.0365; // 3.65%
    const VAT_RATE = 0.07; // 7%
    const effectiveRate = OMISE_FEERATE * (1 + VAT_RATE);

    // 2. Calculate Required Charge Amount (Gross) to yield the target Net
    // Formula: Gross = Net / (1 - effectiveRate)
    // We use Math.ceil to ensure we cover all fees and don't lose satangs.
    const requiredChargeSatang = Math.ceil(targetNetSatang / (1 - effectiveRate));

    console.log(
      `[Money Logic] Target Net: ${targetNetSatang}, Required Charge: ${requiredChargeSatang} (Total Fee: ${
        requiredChargeSatang - targetNetSatang
      })`,
    );

    const effectiveWalletAmount = targetNetSatang;
    const finalChargeAmount = requiredChargeSatang;

    // 💎 DAILY TOP-UP LIMITS CHECK (Using the INTENDED amount)
    const MIN_PER_TRANSACTION = 50000; // 500 THB
    const MAX_DAILY = 300000; // 3,000 THB

    if (effectiveWalletAmount < MIN_PER_TRANSACTION) {
      return jsonError(
        `Top-up amount must be at least ${MIN_PER_TRANSACTION / 100} THB`,
        400,
      );
    }

    // Check daily limit using intended Net amount
    const { data: limitCheck, error: limitError } = await adminClient.rpc(
      'check_and_update_daily_topup',
      {
        p_user_id: userId,
        p_amount_satang: effectiveWalletAmount,
      },
    );

    if (limitError) {
      console.error('[Limits] Failed to check daily limit:', limitError);
      return jsonError('Unable to verify daily limits. Please try again.', 500);
    }

    const limitResult = limitCheck as {
      success: boolean;
      error?: string;
      remaining_limit?: number;
    };

    if (!limitResult.success) {
      return jsonError(
        `Daily top-up limit reached. You can top up up to ${MAX_DAILY / 100} THB per day. ` +
          `Remaining: ${(limitResult.remaining_limit || 0) / 100} THB`,
        400,
      );
    }

    console.log(`[Limits] Approved. Remaining: ${(limitResult.remaining_limit || 0) / 100} THB`);

    // ========================================================================
    // 3. SECURE DEVICE CHALLENGE (Signature Verification)
    // ========================================================================
    const deviceId = req.headers.get('x-device-id');
    const signature = req.headers.get('x-device-signature');

    if (!deviceId || !signature) {
      console.error('[Security] Missing device headers for critical action');
      return jsonError('Device authorization missing', 401);
    }

    // Fetch the device public key for this user
    const { data: binding, error: bindError } = await adminClient
      .from('user_device_bindings')
      .select('public_key')
      .eq('user_id', userId)
      .eq('device_id', deviceId)
      .eq('is_active', true)
      .maybeSingle();

    if (bindError || !binding) {
      console.warn(`[Security] Unrecognized or inactive device attempt: ${deviceId}`);
      return jsonError('Device not recognized or link revoked', 401);
    }

    // 🔬 DEBUG: Log the public key prefix from DB for troubleshooting key mismatch
    console.log(
      `[Security] Device ${deviceId} - DB PubKey Prefix: ${binding.public_key.substring(0, 10)}...`,
    );

    // Verify Signature: Payload signed is the reference_id
    const isValidSig = await verifySignature(signature, reference_id, binding.public_key);
    if (!isValidSig) {
      console.error(`[Security] Signature Mismatch for ref: ${reference_id}. Device: ${deviceId}`);
      return jsonError('Request integrity check failed', 401);
    }

    console.log(`[Security] Signature Verified for Device: ${deviceId}`);

    // ========================================================================
    // 3.5 IDEMPOTENCY CHECK
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
    // 6. EXECUTE PAYMENT (OMISE)
    // ========================================================================
    // Use finalChargeAmount for Omise and effectiveWalletAmount for Database
    const chargePayload: any = {
      amount: finalChargeAmount,
      currency: 'thb',
      capture: true,
      description: description || `Top up ${effectiveWalletAmount / 100} THB`,
      metadata: {
        user_id: userId,
        reference_id,
        wallet_amount_satang: effectiveWalletAmount, // True intended amount
        charge_amount_satang: finalChargeAmount, // Total taken from card
      },
    };

    // 🎯 FIX: Always use customer + card if we have them (prevents using a consumed token)
    if (omiseCustomerId && chargeCard) {
      chargePayload.customer = omiseCustomerId;
      chargePayload.card = chargeCard;
    } else if (token) {
      // Fallback: Charge token directly (only if vaulting was skipped)
      chargePayload.card = token;
    } else if (_is_apple_pay) {
      // Apple Pay handling...
    }

    const charge = await opn.createCharge(chargePayload);
    // @ts-ignore: Handle both successful charge and error response objects
    const chargeError = charge.object === 'error' ? (charge as any).message : null;
    console.log(`[Opn] Charge result: ${charge.status || 'error'} (${charge.id || 'N/A'})`);

    if (chargeError || (charge.status !== 'successful' && charge.status !== 'pending')) {
      const errorMsg = chargeError || charge.failure_message || 'Payment failed';
      // 🔍 DEBUG: Log full charge response for troubleshooting
      console.error(`[Opn] Charge failed: ${errorMsg}`);
      console.error(`[Opn] Full charge response:`, JSON.stringify(charge, null, 2));
      console.error(`[Opn] Charge payload was:`, JSON.stringify(chargePayload, null, 2));
      return jsonError(errorMsg, 400, 'CHARGE_FAILED');
    }

    // ========================================================================
    // 7. ATOMIC LEDGER UPDATE
    // ========================================================================
    // 💎 ATOMIC LEDGER UPDATE
    // We record the WALLET amount (Net) as the primary transaction value.
    // fees are kept in metadata for audit.
    console.log(
      `[DB] Recording Transaction: Net Wallet +${effectiveWalletAmount} (Gross Charge: ${finalChargeAmount})`,
    );

    const feeAmount = finalChargeAmount - effectiveWalletAmount;

    const { data: rpcData, error: rpcError } = await adminClient.rpc(
      'process_inbound_transaction',
      {
        p_user_id: userId,
        p_amount_satang: effectiveWalletAmount, // 💎 SOURCE OF TRUTH: Net amount
        p_provider: 'omise',
        p_provider_txn_id: charge.id,
        p_reference_id: reference_id,
        p_description: 'Wallet Top Up',
        p_metadata: {
          ...charge,
          charge_amount_satang: finalChargeAmount,
          wallet_amount_satang: effectiveWalletAmount,
          fee_amount_satang: feeAmount,
          is_auto_round: true,
          recorded_at: new Date().toISOString(),
        },
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

async function verifySignature(sigB64: string, msg: string, pubKeyB64: string): Promise<boolean> {
  try {
    const sig = base64Decode(sigB64);
    const pub = base64Decode(pubKeyB64);
    const msgBytes = new TextEncoder().encode(msg);
    return await ed.verify(sig, msgBytes, pub);
  } catch (err) {
    console.error('Ed25519 verify error:', err);
    return false;
  }
}
