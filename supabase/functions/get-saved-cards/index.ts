// ============================================================================
// Get Saved Cards - PCI DSS Compliant Card Retrieval
// ============================================================================
// Retrieves saved card details (masked) from Omise Customer API.
// SECURITY: Only returns id, brand, last_digits, expiration_month/year
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ============================================================================
// Types
// ============================================================================

interface SavedCard {
  id: string;
  brand: string;
  last_digits: string;
  expiration_month: number;
  expiration_year: number;
}

interface OpnCard {
  object: 'card';
  id: string;
  brand: string;
  last_digits: string;
  expiration_month: number;
  expiration_year: number;
  // Other fields exist but we don't need them (PCI DSS)
}

interface OpnCardsListResponse {
  object: 'list';
  data: OpnCard[];
}

// ============================================================================
// Omise Client (Minimal)
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

  async listCards(customerId: string): Promise<SavedCard[]> {
    const resp = await fetch(`${this.baseUrl}/customers/${customerId}/cards`, {
      method: 'GET',
      headers: {
        'Authorization': this.authHeader(),
      },
    });

    if (!resp.ok) {
      const error = await resp.text();
      console.error('[OpnClient] Failed to list cards:', error);
      throw new Error(`Omise API error: ${resp.status}`);
    }

    const data: OpnCardsListResponse = await resp.json();

    // Transform to PCI DSS compliant format (only safe fields)
    return data.data.map((card) => ({
      id: card.id,
      brand: card.brand,
      last_digits: card.last_digits,
      expiration_month: card.expiration_month,
      expiration_year: card.expiration_year,
    }));
  }
}

// ============================================================================
// Supabase Client
// ============================================================================

// We use service role key to bypass RLS for reading profiles,
// AFTER creating a manual auth verification to ensure security.
function createAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  try {
    // =========================================================================
    // 1. Authenticate User (Manual Fetch Pattern)
    // =========================================================================
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const jwtToken = authHeader.replace('Bearer ', '');

    // Verify token manually via Auth API
    const userResp = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${jwtToken}`,
        'apikey': supabaseAnonKey,
      },
    });

    if (!userResp.ok) {
      console.error('[Auth] Token verification failed');
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { id: userId } = await userResp.json();
    console.log(`[Auth] User verified: ${userId}`);

    // =========================================================================
    // 2. Get Omise Customer ID from Profile (Using Admin Client for reliability)
    // =========================================================================
    const adminClient = createAdminClient();

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('omise_customer_id')
      .eq('id', userId)
      .single();

    if (profileError) {
      console.error('[get-saved-cards] Profile fetch error:', profileError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // No saved cards if no Omise customer ID
    if (!profile?.omise_customer_id) {
      return new Response(
        JSON.stringify({ cards: [] }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // =========================================================================
    // 3. Fetch Cards from Omise
    // =========================================================================
    const omiseSecretKey = Deno.env.get('OMISE_SECRET_KEY');
    if (!omiseSecretKey) {
      console.error('[get-saved-cards] OMISE_SECRET_KEY not configured');
      return new Response(
        JSON.stringify({ error: 'Payment provider not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const opnClient = new OpnClient(omiseSecretKey);
    const cards = await opnClient.listCards(profile.omise_customer_id);

    // =========================================================================
    // 4. Return PCI DSS Compliant Response
    // =========================================================================
    return new Response(
      JSON.stringify({ cards }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('[get-saved-cards] Unhandled error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
