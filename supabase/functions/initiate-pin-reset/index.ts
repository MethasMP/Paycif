/// <reference lib="deno.ns" />
// ============================================================================
// INITIATE-PIN-RESET - Supabase Edge Function
// ============================================================================
// This function handles the "Secure Recovery" flow.
// It challenges the user with Static Knowledge (Last 4 of ID Card).
// If successful, it performs an Atomic Reset of the PIN state.
//
// Key Features:
// 1. KYC Validation (vs identity_verification table)
// 2. Anti-Brute Force (Shared Lockout Logic with PIN)
// 3. Atomic Reset (Clear Hash + Reset Profile Flag)
// ============================================================================

import { serve } from 'std/server';
import { createClient } from '@supabase/supabase-js';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Auth & Setup
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Public client (Service Role)
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Private client (kept for Success path only, until RPC is available)
    const privateClient = createClient(supabaseUrl, supabaseServiceKey, {
      db: { schema: 'private' },
    });

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing auth', 401);

    const jwt = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);

    if (authError || !user) {
      return jsonError('Unauthorized', 401);
    }

    // ------------------------------------------------------------------------
    // READ BODY ONCE
    // ------------------------------------------------------------------------
    const body = await req.json();
    const { answer } = body;

    if (!answer || answer.length !== 4) {
      return jsonError('Invalid challenge format', 400);
    }

    // ------------------------------------------------------------------------
    // SIGNATURE VERIFICATION
    // ------------------------------------------------------------------------
    const deviceId = req.headers.get('x-device-id');
    const signature = req.headers.get('x-device-signature');

    if (!deviceId || !signature) {
      console.warn(`[ResetPin] User ${user.id} missing device headers.`);
      return jsonError('Device authorization missing', 401);
    }

    const { data: binding, error: bindError } = await supabase
      .from('user_device_bindings')
      .select('public_key')
      .eq('user_id', user.id)
      .eq('device_id', deviceId)
      .single();

    if (bindError || !binding) {
      console.warn(`[ResetPin] Unbound device attempt: ${deviceId}`);
      return jsonError('Device not recognized', 401);
    }

    // Verify signature of the 'answer' payload
    const isValidSig = await verifySignature(signature, answer, binding.public_key);
    if (!isValidSig) {
      console.warn(`[ResetPin] Invalid Signature for ${user.id}`);
      return jsonError('Device signature verification failed', 401);
    }

    // ------------------------------------------------------------------------
    // C. CHECK LOCKOUT via RPC
    // ------------------------------------------------------------------------
    const { data: secret, error: secretError } = await supabase
      .rpc('get_user_auth_secret', { p_user_id: user.id });

    if (secretError) {
      console.error('Secret fetch error:', secretError);
      return jsonError('System Error', 500);
    }

    if (secret && secret.locked_until) {
      const lockedUntil = new Date(secret.locked_until);
      const now = new Date();
      if (lockedUntil > now) {
        const diffMs = lockedUntil.getTime() - now.getTime();
        const diffSec = Math.ceil(diffMs / 1000);
        return new Response(
          JSON.stringify({
            success: false,
            error: `Account locked. Try again in ${diffSec} seconds.`,
            locked_until: secret.locked_until,
          }),
          {
            status: 423,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
              'Retry-After': diffSec.toString(),
            },
          },
        );
      }
    }

    // ------------------------------------------------------------------------
    // D. VALIDATE CHALLENGE & RESET
    // ------------------------------------------------------------------------
    const { data: kyc, error: kycError } = await supabase
      .from('identity_verification')
      .select('passport_number')
      .eq('user_id', user.id)
      .single();

    if (kycError || !kyc) {
      return jsonError('No identity record found. Contact support.', 403, 'KYC_MISSING');
    }

    const idNumber = kyc.passport_number.trim();
    if (idNumber.length < 4) {
      return jsonError('Identity record invalid. Contact support.', 403, 'KYC_INVALID');
    }

    const expectedLast4 = idNumber.slice(-4);

    if (answer === expectedLast4) {
      // SUCCESS: Perform Atomic Reset
      console.log(`[ResetPin] Challenge passed for ${user.id}`);

      // Update Device Last Used
      await supabase
        .from('user_device_bindings')
        .update({ last_used_at: new Date().toISOString() })
        .eq('device_id', deviceId);

      // A. Clear Secret Hash
      // WARNING: Still relies on private schema due to missing RPC for clearing
      const { error: resetSecretError } = await privateClient
        .from('user_auth_secrets') // in private schema
        .update({
          pin_hash: null,
          failed_attempts: 0,
          locked_until: null,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', user.id);

      if (resetSecretError) throw resetSecretError;

      // B. Update Profile
      const { error: profileError } = await supabase
        .from('profiles')
        .update({ has_pin: false })
        .eq('id', user.id);

      if (profileError) throw profileError;

      return new Response(
        JSON.stringify({ success: true, message: 'PIN reset successful. Please setup a new PIN.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    } else {
      // FAILURE: Increment Lockout via RPC
      console.warn(`[ResetPin] Challenge FAILED for ${user.id}`);

      if (secret) {
        const newFailed = (secret.failed_attempts || 0) + 1;
        let newLockedUntil = null;
        let errorMsg = 'Incorrect answer.';

        if (newFailed >= 3) {
          const lockDuration = 60 * 60 * 1000; // 1 HOUR
          newLockedUntil = new Date(Date.now() + lockDuration).toISOString();
          errorMsg = 'Too many failed attempts. Recovery locked for 1 hour.';
        } else {
          errorMsg = `Incorrect answer. ${3 - newFailed} attempts remaining.`;
        }

        await supabase.rpc('update_user_auth_status', {
          p_user_id: user.id,
          p_failed_attempts: newFailed,
          p_locked_until: newLockedUntil,
          p_reset_counters: false,
        });

        return jsonError(errorMsg, 401);
      } else {
        return jsonError('Incorrect answer', 401);
      }
    }
  } catch (e) {
    console.error('[ResetPin] Error:', e);
    return jsonError('Internal Server Error', 500);
  }
});

function jsonError(message: string, status: number, code?: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: message, code }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}

// ----------------------------------------------------------------------------
// HELPER: Dual-Algorithm Signature Verification (Ed25519 & P256)
// ----------------------------------------------------------------------------
import * as ed from '@noble/ed25519';
import { p256 } from '@noble/curves/p256';
import { sha512 } from '@noble/hashes/sha512';
import { decode as base64Decode } from 'std/encoding/base64';

// 🛡️ CRITICAL: Configure SHA-512 for @noble/ed25519 v2
ed.etc.sha512Sync = (...m: Uint8Array[]) => sha512(ed.etc.concatBytes(...m));

async function verifySignature(sigB64: string, msg: string, pubKeyB64: string): Promise<boolean> {
  try {
    const sig = base64Decode(sigB64);
    const pub = base64Decode(pubKeyB64);
    const msgBytes = new TextEncoder().encode(msg);

    // 🛡️ Algorithm Intelligence: Detection by Key Length
    if (pub.length === 32) {
      return await ed.verify(sig, msgBytes, pub);
    } else if (pub.length === 33 || pub.length === 65) {
      return p256.verify(sig, msgBytes, pub);
    } else {
      console.error(`[ResetPin] Unsupported public key length: ${pub.length}`);
      return false;
    }
  } catch (err) {
    console.error('Signature verification error:', err);
    return false;
  }
}
