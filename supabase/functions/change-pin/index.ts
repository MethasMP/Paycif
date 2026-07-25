import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import * as ed from 'https://esm.sh/@noble/ed25519@2.0.0';
import { p256 } from 'https://esm.sh/@noble/curves@1.2.0/p256';
import { sha512 } from 'https://esm.sh/@noble/hashes@1.3.1/sha512';

ed.etc.sha512Sync = (...msgs: Uint8Array[]) => sha512(ed.etc.concatBytes(...msgs));

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-device-id, x-device-signature, x-nonce',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const MAX_MINUTE_DRIFT = 2;

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const db = createSupabase();

    // 1. JWT auth
    const auth = req.headers.get('Authorization');
    if (!auth) return err('Missing auth', 401);
    const { data: { user }, error: authErr } = await db.auth.getUser(auth.replace(/^Bearer /i, ''));
    if (authErr || !user) return err('Unauthorized', 401);

    // 2. Required headers
    const deviceId = req.headers.get('x-device-id');
    const signature = req.headers.get('x-device-signature');
    const nonce = req.headers.get('x-nonce');
    if (!deviceId || !signature || !nonce) return err('Device authorization missing', 401);

    // 3. Body
    const { old_pin, new_pin, is_hashed } = await req.json().catch(() => ({}));
    if (is_hashed) {
      if (!old_pin || typeof old_pin !== 'string' || old_pin.length !== 64 || !/^[a-fA-F0-9]+$/.test(old_pin))
        return err('Invalid old_pin format', 400);
      if (!new_pin || typeof new_pin !== 'string' || new_pin.length !== 64 || !/^[a-fA-F0-9]+$/.test(new_pin))
        return err('Invalid new_pin format', 400);
    } else {
      if (!old_pin || typeof old_pin !== 'string' || old_pin.length !== 6 || !/^\d+$/.test(old_pin))
        return err('old_pin must be a 6-digit number', 400);
      if (!new_pin || typeof new_pin !== 'string' || new_pin.length !== 6 || !/^\d+$/.test(new_pin))
        return err('new_pin must be a 6-digit number', 400);
    }
    if (old_pin === new_pin) return err('New PIN must differ from current PIN.', 400);

    // 4. Load auth context
    const ctx = await fetchContext(db, user.id, deviceId);
    if (!ctx) return err('PIN not set up. Please set up your PIN first.', 404);
    if (!ctx.public_key || !ctx.is_device_active) return err('Device not recognized', 401);

    // 5. Lockout check
    if (ctx.locked_until && new Date(ctx.locked_until) > new Date()) {
      const secs = Math.ceil((new Date(ctx.locked_until).getTime() - Date.now()) / 1000);
      const levelMsg = ctx.lockout_level >= 3
        ? 'Account permanently locked. Please use Forgot PIN to recover.'
        : `Account locked. Try again in ${secs} seconds.`;
      return new Response(
        JSON.stringify({ success: false, error: levelMsg, locked_until: ctx.locked_until, lockout_level: ctx.lockout_level }),
        { status: 423, headers: { ...CORS, 'Content-Type': 'application/json', 'Retry-After': secs.toString() } },
      );
    }

    // 6. Timestamp window validation
    const clientMinute = parseInt(req.headers.get('x-timestamp-bucket') ?? '0', 10);
    const serverMinute = Math.floor(Date.now() / 60000);
    if (Math.abs(serverMinute - clientMinute) > MAX_MINUTE_DRIFT) {
      return err('Request timestamp expired. Please try again.', 401);
    }

    // 7. Nonce consumption (atomic, replay-proof)
    const { data: nonceOk, error: nonceErr } = await db.rpc('consume_nonce', {
      p_nonce: nonce,
      p_user_id: user.id,
      p_window_seconds: 120,
    });
    if (nonceErr || !nonceOk) return err('Request already used or expired. Please try again.', 401);

    // 8. Signature verification — payload: "PIN:NONCE:MINUTE_BUCKET" (using old_pin)
    const sigPayload = `${old_pin}:${nonce}:${clientMinute}`;
    const sigOk = await verifySignature(signature, sigPayload, ctx.public_key);
    if (!sigOk) {
      await recordFailure(db, user.id, deviceId, ctx.failed_attempts);
      return err('Invalid PIN.', 401);
    }

    // 9. Verify old PIN hash in DB (hash never leaves Postgres)
    const { data: pinOk, error: pinErr } = await db.rpc('verify_pin_hash', {
      p_user_id: user.id,
      p_pin: old_pin,
    });
    if (pinErr) { console.error('[change-pin] verify DB error:', pinErr); return err('Internal error', 500); }

    if (!pinOk) {
      await recordFailure(db, user.id, deviceId, ctx.failed_attempts);
      const newFailed = (ctx.failed_attempts || 0) + 1;
      const remaining = Math.max(0, 3 - (newFailed % 3));
      return err(`Incorrect current PIN. ${remaining > 0 ? remaining + ' attempts before lockout.' : 'Account locked.'}`, 401);
    }

    // 10. Hash and store new PIN in DB via Argon2id (pgsodium)
    const { error: setupErr } = await db.rpc('setup_user_pin_v2', {
      p_user_id: user.id,
      p_pin: new_pin,
    });
    if (setupErr) { console.error('[change-pin] setup DB error:', setupErr); return err('Failed to update PIN.', 500); }

    // 11. Reset failure counters on success
    await db.rpc('update_user_auth_result', {
      p_user_id: user.id, p_device_id: deviceId,
      p_failed_attempts: 0, p_locked_until: null, p_reset_counters: true,
    });

    return ok({ success: true });

  } catch (e: unknown) {
    console.error('[change-pin] fatal:', e);
    return err(`Internal error: ${e instanceof Error ? e.message : String(e)}`, 500);
  }
});

function createSupabase(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Server config missing');
  return createClient(url, key);
}

interface AuthContext {
  failed_attempts: number; locked_until: string | null;
  lockout_level: number; public_key: string | null; is_device_active: boolean;
}

async function fetchContext(db: SupabaseClient, userId: string, deviceId: string): Promise<AuthContext | null> {
  const { data, error } = await db.rpc('get_user_auth_context', { p_user_id: userId, p_device_id: deviceId });
  if (error) throw new Error(`DB: ${error.message}`);
  return data ?? null;
}

async function recordFailure(db: SupabaseClient, userId: string, deviceId: string, currentFailed: number) {
  const newFailed = (currentFailed || 0) + 1;
  await db.rpc('update_user_auth_result', {
    p_user_id: userId, p_device_id: deviceId,
    p_failed_attempts: newFailed, p_locked_until: null, p_reset_counters: false,
  });
}

async function verifySignature(sigB64: string, payload: string, pubKeyB64: string): Promise<boolean> {
  try {
    const sig = fromB64(sigB64);
    const pub = fromB64(pubKeyB64);
    const msg = new TextEncoder().encode(payload);
    if (pub.length === 32) return await ed.verify(sig, msg, pub);
    if (pub.length === 33 || pub.length === 65) return p256.verify(sig, msg, pub);
    return false;
  } catch { return false; }
}

function fromB64(s: string): Uint8Array {
  const p = s + '='.repeat((4 - s.length % 4) % 4);
  const r = atob(p.replace(/-/g, '+').replace(/_/g, '/'));
  return new Uint8Array([...r].map(c => c.charCodeAt(0)));
}

function ok(b: unknown): Response {
  return new Response(JSON.stringify(b), { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } });
}
function err(m: string, s: number): Response {
  return new Response(JSON.stringify({ success: false, error: m }), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
}
