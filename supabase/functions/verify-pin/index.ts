// ============================================================================
// VERIFY-PIN - Supabase Edge Function
// ============================================================================
// Server Authority for PIN verification.
// Implements strict Server-Side Lockout to prevent client-side bypass.
// ============================================================================

import { serve } from 'std/server';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { argon2id } from 'hash-wasm';
import { decode as decodeBase64 } from 'std/encoding/base64';
import * as ed from '@noble/ed25519';
import { p256 } from '@noble/curves/p256';
import { sha512 } from '@noble/hashes/sha512';

// Configure SHA-512 for @noble/ed25519 v2
ed.etc.sha512Sync = (...messages: Uint8Array[]) => sha512(ed.etc.concatBytes(...messages));

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ----------------------------------------------------------------------------
// Domain Types & Interfaces
// ----------------------------------------------------------------------------

interface UserAuthContext {
  pin_hash: string;
  failed_attempts: number;
  locked_until: string | null;
  public_key: string | null;
  is_device_active: boolean;
}

interface RequestCredentials {
  pin: string;
  deviceId: string;
  signature: string;
  accessToken: string;
}

// ----------------------------------------------------------------------------
// Custom Domain Exceptions
// ----------------------------------------------------------------------------

abstract class HttpException extends Error {
  abstract readonly statusCode: number;
  constructor(message: string) {
    super(message);
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

class ValidationException extends HttpException {
  readonly statusCode = 400;
}

class AuthenticationException extends HttpException {
  readonly statusCode = 401;
}

class LockoutException extends HttpException {
  readonly statusCode = 423;
  readonly lockedUntil: string;

  constructor(message: string, lockedUntil: string) {
    super(message);
    this.lockedUntil = lockedUntil;
  }
}

class DatabaseException extends HttpException {
  readonly statusCode = 500;
}

// ----------------------------------------------------------------------------
// Main Server Handler
// ----------------------------------------------------------------------------

serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    return await handleVerifyPinRequest(request);
  } catch (error: unknown) {
    return buildErrorResponse(error);
  }
});

// ----------------------------------------------------------------------------
// Request Coordinator
// ----------------------------------------------------------------------------

async function handleVerifyPinRequest(request: Request): Promise<Response> {
  const credentials = await extractCredentials(request);
  const supabase = createSupabaseServiceClient();
  const userId = await authenticateUser(supabase, credentials.accessToken);
  
  const authContext = await fetchUserAuthContext(supabase, userId, credentials.deviceId);
  validateLockStatus(authContext);

  const verificationResult = await verifyCredentials(credentials, authContext);
  if (verificationResult.isValid) {
    await handleSuccess(supabase, userId, credentials.deviceId);
    return buildSuccessResponse();
  }

  await handleFailure(supabase, userId, credentials.deviceId, authContext);
}

// ----------------------------------------------------------------------------
// Extraction & Parsing
// ----------------------------------------------------------------------------

async function extractCredentials(request: Request): Promise<RequestCredentials> {
  const accessToken = extractAuthorizationToken(request);
  const deviceId = request.headers.get('x-device-id');
  const signature = request.headers.get('x-device-signature');

  if (!deviceId || !signature) {
    throw new AuthenticationException('Device authorization missing');
  }

  const { pin } = await parseRequestBody(request);
  if (!pin) {
    throw new ValidationException('PIN required');
  }

  return { pin, deviceId, signature, accessToken };
}

function extractAuthorizationToken(request: Request): string {
  const authorizationHeader = request.headers.get('Authorization');
  if (!authorizationHeader) {
    throw new AuthenticationException('Missing auth');
  }
  return authorizationHeader.replace('Bearer ', '');
}

async function parseRequestBody(request: Request): Promise<{ pin?: string }> {
  try {
    return await request.json();
  } catch {
    throw new ValidationException('Invalid JSON payload');
  }
}

// ----------------------------------------------------------------------------
// Authentication & Database Integration
// ----------------------------------------------------------------------------

function createSupabaseServiceClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new DatabaseException('Server configuration missing');
  }
  return createClient(supabaseUrl, supabaseServiceKey);
}

async function authenticateUser(supabase: SupabaseClient, accessToken: string): Promise<string> {
  const { data: { user }, error } = await supabase.auth.getUser(accessToken);
  if (error || !user) {
    throw new AuthenticationException('Unauthorized');
  }
  return user.id;
}

async function fetchUserAuthContext(
  supabase: SupabaseClient,
  userId: string,
  deviceId: string
): Promise<UserAuthContext> {
  const { data: authContext, error } = await supabase.rpc('get_user_auth_context', {
    p_user_id: userId,
    p_device_id: deviceId,
  });

  if (error) {
    throw new DatabaseException(`System Error: ${error.message}`);
  }
  if (!authContext) {
    throw new ValidationException('PIN not setup');
  }
  if (!authContext.public_key || !authContext.is_device_active) {
    throw new AuthenticationException('Device not recognized');
  }

  return authContext as UserAuthContext;
}

// ----------------------------------------------------------------------------
// Lockout Checks & Enforcement
// ----------------------------------------------------------------------------

function validateLockStatus(authContext: UserAuthContext): void {
  if (!authContext.locked_until) {
    return;
  }

  const lockedUntil = new Date(authContext.locked_until);
  const now = new Date();
  if (lockedUntil > now) {
    const diffMs = lockedUntil.getTime() - now.getTime();
    const diffSec = Math.ceil(diffMs / 1000);
    throw new LockoutException(
      `Account locked. Try again in ${diffSec} seconds.`,
      authContext.locked_until
    );
  }
}

// ----------------------------------------------------------------------------
// Cryptographic Verifications
// ----------------------------------------------------------------------------

interface VerificationOutcome {
  isValid: boolean;
}

async function verifyCredentials(
  credentials: RequestCredentials,
  authContext: UserAuthContext
): Promise<VerificationOutcome> {
  const [isValidSignature, isValidPin] = await Promise.all([
    verifySignature(credentials.signature, credentials.pin, authContext.public_key!),
    verifyPinHash(authContext.pin_hash, credentials.pin),
  ]);

  return { isValid: isValidSignature && isValidPin };
}

async function verifySignature(
  signatureBase64: string,
  message: string,
  publicKeyBase64: string
): Promise<boolean> {
  try {
    const signature = decodeBase64(signatureBase64);
    const publicKey = decodeBase64(publicKeyBase64);
    const messageBytes = new TextEncoder().encode(message);

    if (publicKey.length === 32) {
      return await ed.verify(signature, messageBytes, publicKey);
    }
    if (publicKey.length === 33 || publicKey.length === 65) {
      return p256.verify(signature, messageBytes, publicKey);
    }

    console.error(`[VerifyPin] Unsupported public key length: ${publicKey.length}`);
    return false;
  } catch (error) {
    console.error('[VerifyPin] Signature verification error:', error);
    return false;
  }
}

async function verifyPinHash(phcString: string, pin: string): Promise<boolean> {
  try {
    const parts = phcString.split('$');
    if (parts.length !== 6 || parts[1] !== 'argon2id') {
      return false;
    }

    const params = parts[3];
    const paramMap = parsePhcParams(params);
    const memorySize = paramMap['m'];
    const iterations = paramMap['t'];
    const parallelism = paramMap['p'];

    if (!memorySize || !iterations || !parallelism) {
      return false;
    }

    const salt = decodeBase64Salt(parts[4]);
    const computedHash = await argon2id({
      password: pin,
      salt: salt,
      parallelism,
      iterations,
      memorySize,
      hashLength: 32,
      outputType: 'encoded',
    });

    return safeCompare(computedHash, phcString);
  } catch (error) {
    console.error('[VerifyPin] PIN verification error:', error);
    return false;
  }
}

function parsePhcParams(params: string): Record<string, number> {
  const paramMap: Record<string, number> = {};
  params.split(',').forEach((param) => {
    const parts = param.split('=');
    if (parts.length === 2) {
      paramMap[parts[0]] = parseInt(parts[1], 10);
    }
  });
  return paramMap;
}

function decodeBase64Salt(saltBase64: string): Uint8Array {
  let paddedSalt = saltBase64;
  while (paddedSalt.length % 4 !== 0) {
    paddedSalt += '=';
  }
  return decodeBase64(paddedSalt);
}

function safeCompare(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

// ----------------------------------------------------------------------------
// Outcome Handlers
// ----------------------------------------------------------------------------

async function handleSuccess(
  supabase: SupabaseClient,
  userId: string,
  deviceId: string
): Promise<void> {
  const { error } = await supabase.rpc('update_user_auth_result', {
    p_user_id: userId,
    p_device_id: deviceId,
    p_failed_attempts: 0,
    p_locked_until: null,
    p_reset_counters: true,
  });

  if (error) {
    console.error('[VerifyPin] Failed to update success result in database:', error);
  }
}

async function handleFailure(
  supabase: SupabaseClient,
  userId: string,
  deviceId: string,
  authContext: UserAuthContext
): Promise<never> {
  const failedAttempts = (authContext.failed_attempts || 0) + 1;
  const lockedUntil = calculateLockoutTime(failedAttempts);

  const { error } = await supabase.rpc('update_user_auth_result', {
    p_user_id: userId,
    p_device_id: deviceId,
    p_failed_attempts: failedAttempts,
    p_locked_until: lockedUntil,
    p_reset_counters: false,
  });

  if (error) {
    console.error('[VerifyPin] Failed to update failure result in database:', error);
  }

  if (lockedUntil) {
    throw new LockoutException(
      'Too many attempts. Account locked for 5 minutes.',
      lockedUntil
    );
  }

  const remainingAttempts = Math.max(0, 3 - failedAttempts);
  throw new AuthenticationException(
    `Invalid PIN. ${remainingAttempts} attempts remaining.`
  );
}

function calculateLockoutTime(failedAttempts: number): string | null {
  const MAX_ATTEMPTS = 3;
  const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes

  if (failedAttempts >= MAX_ATTEMPTS) {
    return new Date(Date.now() + LOCK_DURATION_MS).toISOString();
  }
  return null;
}

// ----------------------------------------------------------------------------
// Response Builders
// ----------------------------------------------------------------------------

function buildSuccessResponse(): Response {
  return new Response(
    JSON.stringify({ success: true, message: 'Verified' }),
    { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
  );
}

function buildErrorResponse(error: unknown): Response {
  if (error instanceof LockoutException) {
    const diffMs = new Date(error.lockedUntil).getTime() - Date.now();
    const diffSec = Math.max(0, Math.ceil(diffMs / 1000));
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        locked_until: error.lockedUntil,
      }),
      {
        status: 423,
        headers: {
          ...CORS_HEADERS,
          'Content-Type': 'application/json',
          'Retry-After': diffSec.toString(),
        },
      }
    );
  }

  if (error instanceof HttpException) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: error.statusCode,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      }
    );
  }

  const internalMessage = error instanceof Error ? error.message : String(error);
  return new Response(
    JSON.stringify({ success: false, error: `Internal Server Error: ${internalMessage}` }),
    { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
  );
}
