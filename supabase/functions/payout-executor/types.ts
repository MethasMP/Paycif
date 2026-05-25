// ============================================================================
// TYPES.TS - TypeScript Interfaces for Payout Executor
// ============================================================================

/**
 * Payout request from Flutter client
 */
export interface PayoutRequest {
  user_id: string;
  wallet_id: string;
  amount_satang: number;
  target_type: 'MOBILE' | 'NATID' | 'EWALLET';
  target_value: string;
  idempotency_key: string; // NEW: Signed for security
  description?: string;
}

/**
 * Gateway target type mapping
 * MOBILE -> MOB (PromptPay Personal/Mobile)
 * NATID  -> NID (National ID / Tax ID)
 * EWALLET -> EWL (E-Wallet ID)
 */
export type GatewayTargetType = 'MOB' | 'NID' | 'EWL';

/**
 * Gateway request payload
 */
export interface GatewayPayoutRequest {
  reference_id: string;
  amount_satang: number;
  target_type: GatewayTargetType;
  target_value: string;
  description: string;
  timestamp: string;
}

/**
 * Gateway response
 */
export interface GatewayPayoutResponse {
  success: boolean;
  gateway_ref?: string;
  error_code?: string;
  error_message?: string;
  raw_response?: unknown;
}

/**
 * Edge Function response to Flutter
 */
export interface PayoutResponse {
  success: boolean;
  transaction_id?: string;
  gateway_ref?: string;
  status?: 'SUCCESS' | 'FAILED' | 'PENDING';
  error?: string;
}

/**
 * RPC result from process_payout_request
 */
export interface RpcResult {
  transaction_id: string | null;
  status_code: number;
  status_message: string;
}

/**
 * Target type mapping utility
 */
export function mapTargetType(appType: string): GatewayTargetType {
  switch (appType) {
    case 'MOBILE':
      return 'MOB';
    case 'NATID':
      return 'NID';
    case 'EWALLET':
      return 'EWL';
    default:
      throw new Error(`Unknown target type: ${appType}`);
  }
}
