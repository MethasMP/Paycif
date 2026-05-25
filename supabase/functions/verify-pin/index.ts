// ============================================================================
// VERIFY-PIN - Supabase Edge Function
// ============================================================================
// The "Server Authority" for PIN verification.
// Implements strict Server-Side Lockout to prevent client-side bypass.
//
// Features:
// 1. Pre-Check Lockout (db.locked_until)
// 2. Argon2id PHC Verification (Manual implementation via hash-wasm)
// 3. Rate Limiting / Lockout Punishment (3 attempts -> Lock)
// ============================================================================

import { serve } from 'std/server';
import { createClient } from '@supabase/supabase-js';
// 🛡️ Use WASM-based Argon2id for Edge Compatibility
import { argon2id } from 'hash-wasm';
import { decode as base64Decode } from 'std/encoding/base64';

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

    // Use Service Role client (standard public schema)
    // We will use RPC calls to access private data securely
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify User from Header
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
    const { pin } = body;

    if (!pin) return jsonError('PIN required', 400);

    // ------------------------------------------------------------------------
    // 2. DEVICE SIGNATURE VERIFICATION (Dual Layer Enforcer)
    // ------------------------------------------------------------------------
    const deviceId = req.headers.get('x-device-id');
    const signature = req.headers.get('x-device-signature');

    // Strict Mode: Require Device Signature
    if (!deviceId || !signature) {
      console.warn(`[VerifyPin] User ${user.id} missing device headers.`);
      return jsonError('Device authorization missing', 401);
    }

    // Fetch binding
    const { data: binding, error: bindError } = await supabase
      .from('user_device_bindings')
      .select('public_key')
      .eq('user_id', user.id)
      .eq('device_id', deviceId)
      .single();

    if (bindError || !binding) {
      console.warn(`[VerifyPin] Unbound device attempt: ${deviceId}`);
      return jsonError('Device not recognized', 401);
    }

    // 🔬 DEBUG: Trace what we're verifying
    const pubKeyPrefix = binding.public_key.substring(0, 10);
    const sigPrefix = signature.substring(0, 10);
    console.log(`[VerifyPin] DEBUG - DeviceID: ${deviceId}`);
    console.log(`[VerifyPin] DEBUG - PubKey Prefix (from DB): ${pubKeyPrefix}...`);
    console.log(`[VerifyPin] DEBUG - Signature Prefix (from Header): ${sigPrefix}...`);
    console.log(`[VerifyPin] DEBUG - PIN (message): ${pin}`);

    // Verify Signature: The device signs the PIN attempt itself.
    const isValidSig = await verifySignature(signature, pin, binding.public_key);
    if (!isValidSig) {
      console.warn(
        `[VerifyPin] Invalid Signature for ${user.id}. PubKey: ${pubKeyPrefix}... Sig: ${sigPrefix}...`,
      );
      return jsonError('Device signature verification failed', 401);
    }

    // ------------------------------------------------------------------------
    // 3. SERVER-SIDE LOCKOUT CHECK (The "Authority")
    // ------------------------------------------------------------------------
    // Use RPC to get secret securely without exposing private schema
    const { data: secret, error: secretError } = await supabase
      .rpc('get_user_auth_secret', { p_user_id: user.id });

    if (secretError) {
      console.error('Secret fetch error:', secretError);
      return jsonError(`System Error: ${secretError.message}`, 500);
    }

    if (!secret) {
      return jsonError('PIN not setup', 400);
    }

    // Check Lockout
    if (secret.locked_until) {
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
    // 4. Verify PIN Hash
    // ------------------------------------------------------------------------
    const isValid = await verifyWithHashWasm(secret.pin_hash, pin);

    if (isValid) {
      // SUCCESS: Reset counters via RPC
      console.log(`[VerifyPin] User ${user.id} Success`);

      await supabase.rpc('update_user_auth_status', {
        p_user_id: user.id,
        p_failed_attempts: 0,
        p_locked_until: null,
        p_reset_counters: true
      });

      // Also update device last_used (Public table)
      await supabase
        .from('user_device_bindings')
        .update({ last_used_at: new Date().toISOString() })
        .eq('device_id', deviceId);

      return new Response(
        JSON.stringify({ success: true, message: 'Verified' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    } else {
      // FAILURE: Increment & Check Lockout via RPC
      const newFailed = (secret.failed_attempts || 0) + 1;
      let newLockedUntil = null;
      let errorMsg = 'Invalid PIN';

      // Lockout Rule: > 3 attempts = 5 minutes lock
      if (newFailed >= 3) {
        const lockDuration = 5 * 60 * 1000; // 5 mins
        newLockedUntil = new Date(Date.now() + lockDuration).toISOString();
        errorMsg = 'Too many attempts. Account locked for 5 minutes.';
        console.warn(`[VerifyPin] User ${user.id} LOCKED until ${newLockedUntil}`);
      } else {
        const remaining = 3 - newFailed;
        errorMsg = `Invalid PIN. ${remaining} attempts remaining.`;
      }

      await supabase.rpc('update_user_auth_status', {
        p_user_id: user.id,
        p_failed_attempts: newFailed,
        p_locked_until: newLockedUntil,
        p_reset_counters: false
      });

      return jsonError(errorMsg, 401);
    }
  } catch (e: unknown) {
    console.error('[VerifyPin] Critical Error:', e);
    // 🛡️ DEBUG MODE: Returning error details to client for troubleshooting
    const errorMessage = e instanceof Error ? e.message : String(e);
    return jsonError(`Internal Server Error: ${errorMessage}`, 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(
    JSON.stringify({ success: false, error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}

// ----------------------------------------------------------------------------
// HELPER: Dual-Algorithm Signature Verification (Ed25519 & P256)
// ----------------------------------------------------------------------------
import * as ed from '@noble/ed25519';
import { p256 } from '@noble/curves/p256';
import { sha512 } from '@noble/hashes/sha512';

// 🛡️ CRITICAL: Configure SHA-512 for @noble/ed25519 v2
ed.etc.sha512Sync = (...m: Uint8Array[]) => sha512(ed.etc.concatBytes(...m));

async function verifySignature(sigB64: string, msg: string, pubKeyB64: string): Promise<boolean> {
  try {
    const sig = base64Decode(sigB64);
    const pub = base64Decode(pubKeyB64);
    const msgBytes = new TextEncoder().encode(msg);

    // 🛡️ Algorithm Intelligence: Detection by Key Length
    // Ed25519 = 32 bytes
    // P256 (Compressed) = 33 bytes
    // P256 (Uncompressed) = 65 bytes
    
    if (pub.length === 32) {
      // 🚀 Path A: Legacy Ed25519 (Software)
      return await ed.verify(sig, msgBytes, pub);
    } else if (pub.length === 33 || pub.length === 65) {
      // 🚀 Path B: Banking-Grade P256 (Hardware Secure Enclave)
      // Note: noble-curves p256.verify expects (sig, msg, pub)
      return p256.verify(sig, msgBytes, pub);
    } else {
      console.error(`[VerifyPin] Unsupported public key length: ${pub.length}`);
      return false;
    }
  } catch (err) {
    console.error('Signature verification error:', err);
    return false;
  }
}

// ----------------------------------------------------------------------------
// HELPER: Verify PHC String using hash-wasm
// ----------------------------------------------------------------------------
async function verifyWithHashWasm(phcString: string, pin: string): Promise<boolean> {
  try {
    // Parse PHC String
    // Format: $argon2id$v=19$m=65536,t=3,p=4$saltB64$hashB64
    const parts = phcString.split('$');
    if (parts.length !== 6) return false;

    // Check Algorithm
    if (parts[1] !== 'argon2id') {
      console.error(`[VerifyPin] Invalid algorithm: ${parts[1]}`);
      return false;
    }

    // Parse Parameters
    const params = parts[3]; // "m=65536,t=3,p=4"
    if (!params) {
      console.error(`[VerifyPin] Missing params in hash: ${phcString}`);
      return false;
    }

    const paramMap: Record<string, number> = {};
    params.split(',').forEach((p) => {
      const kv = p.split('=');
      if (kv.length === 2) {
        paramMap[kv[0]] = parseInt(kv[1]);
      }
    });

    const m = paramMap['m']; // memorySize (KB)
    const t = paramMap['t']; // iterations
    const p = paramMap['p']; // parallelism

    if (!m || !t || !p) {
      console.error(`[VerifyPin] Invalid params: m=${m}, t=${t}, p=${p}`);
      return false;
    }

    // Decode Salt (Index 4)
    const saltB64 = parts[4];
    const salt = base64Decode(saltB64);

    // Re-hash
    const newHash = await argon2id({
      password: pin,
      salt: salt,
      parallelism: p,
      iterations: t, // 🛡️ Fix: Use parsed iterations
      memorySize: m, // 🛡️ Fix: Use parsed memory
      hashLength: 32,
      outputType: 'encoded',
    });

    return newHash === phcString;
  } catch (err) {
    console.error('Verification error:', err);
    return false;
  }
}
