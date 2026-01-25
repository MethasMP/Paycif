// ============================================================================
// Inbound Handler Types - Card Vaulting + Security Hardening Edition
// ============================================================================

// Request from Flutter app
export interface InboundRequest {
  amount_satang: number;
  currency: string;
  token?: string; // Optional: Opn card token (tokn_...). If omitted, uses saved card.
  card_id?: string; // NEW: Specific card ID to charge (card_test_...)
  is_apple_pay?: boolean; // NEW: Flag if payment is via Apple Pay
  description?: string;
  reference_id: string; // UUID from client for idempotency
}

// ============================================================================
// Opn Customer API (Card Vaulting)
// ============================================================================

export interface OpnCustomerCreateRequest {
  email: string;
  description?: string;
  card?: string; // Token to attach as first card
}

export interface OpnCustomerResponse {
  object: 'customer';
  id: string; // cust_test_...
  livemode: boolean;
  default_card: string | null; // card_test_...
  email: string;
  description: string | null;
  cards: {
    object: 'list';
    data: OpnCard[];
  };
  created_at: string;
}

export interface OpnCard {
  object: 'card';
  id: string; // card_test_...
  livemode: boolean;
  brand: string;
  last_digits: string;
  name: string;
  expiration_month: number;
  expiration_year: number;
}

export interface OpnAttachCardRequest {
  card: string; // Token to attach
}

// ============================================================================
// Opn Charge API
// ============================================================================

export interface OpnChargeRequest {
  amount: number;
  currency: string;
  customer?: string; // cust_... (use saved card)
  card?: string; // tokn_... (use new token) - for customer, use card ID
  description?: string;
  capture: boolean;
  metadata?: Record<string, string>;
}

export interface OpnChargeResponse {
  object: 'charge';
  id: string; // chrg_...
  livemode: boolean;
  location: string;
  status: 'successful' | 'pending' | 'failed' | 'reversed';
  amount: number;
  currency: string;
  description: string | null;
  failure_code: string | null;
  failure_message: string | null;
  transaction: string | null; // trxn_...
  customer: string | null; // cust_...
  card: {
    object: string;
    id: string;
    livemode: boolean;
    brand: string;
    last_digits: string;
    name: string;
  };
  created_at: string;
}

// ============================================================================
// Service Response
// ============================================================================

export interface ServiceResponse<T = unknown> {
  success: boolean;
  message: string;
  data?: T;
  error?: string;
  error_code?: string;
}

// ============================================================================
// Database Types
// ============================================================================

export interface Profile {
  id: string;
  email: string;
  omise_customer_id: string | null;
}

export interface IdentityVerification {
  user_id: string;
  kyc_status: 'PENDING' | 'APPROVED' | 'REJECTED';
}
