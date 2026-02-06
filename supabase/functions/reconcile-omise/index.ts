import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';

// ============================================================================
// 1. GATEWAY INTERFACE (The Abstraction)
// ============================================================================
interface PaymentTransaction {
  id: string; // Gateway Transaction ID
  amount: number; // Gross Amount (Satang/Cents)
  currency: string;
  status: 'successful' | 'pending' | 'failed' | 'canceled';
  userId?: string;
  referenceId?: string;
  description?: string;
  metadata: Record<string, any>;
  createdAt: string;
}

interface PaymentGatewayAdapter {
  fetchRecentTransactions(limit: number): Promise<PaymentTransaction[]>;
  getName(): string;
}

// ============================================================================
// 2. OMISE ADAPTER (The Implementation)
// ============================================================================
class OmiseAdapter implements PaymentGatewayAdapter {
  private secretKey: string;

  constructor(secretKey: string) {
    this.secretKey = secretKey;
  }

  getName(): string {
    return 'omise';
  }

  async fetchRecentTransactions(limit: number): Promise<PaymentTransaction[]> {
    if (!this.secretKey) throw new Error('Omise Secret Key is missing');

    const response = await fetch(
      `https://api.omise.co/charges?limit=${limit}&order=reverse_chronological`,
      {
        headers: {
          'Authorization': 'Basic ' + btoa(this.secretKey + ':'),
        },
      },
    );

    if (!response.ok) {
      throw new Error(`Omise API Error: ${response.statusText}`);
    }

    const { data } = await response.json();

    // Map Omise format to Unified format
    return data.map((charge: any) => ({
      id: charge.id,
      amount: charge.amount, // Gross
      currency: charge.currency,
      status: charge.status,
      userId: charge.metadata?.user_id,
      referenceId: charge.metadata?.reference_id || charge.id,
      description: charge.description,
      metadata: charge.metadata || {},
      createdAt: charge.created_at,
    }));
  }
}

// ============================================================================
// 3. STRIPE ADAPTER (Example for future extensibility)
// ============================================================================
/*
class StripeAdapter implements PaymentGatewayAdapter {
  async fetchRecentTransactions(limit: number): Promise<PaymentTransaction[]> {
     // ... Stripe API logic ...
     return [];
  }
}
*/

// ============================================================================
// 4. FACTORY (Select Adapter based on Config)
// ============================================================================
function getGatewayAdapter(): PaymentGatewayAdapter {
  // Check Env Var to decide which gateway is active
  const activeGateway = Deno.env.get('ACTIVE_PAYMENT_GATEWAY') || 'omise';

  switch (activeGateway.toLowerCase()) {
    case 'omise':
      return new OmiseAdapter(Deno.env.get('OMISE_SECRET_KEY') || '');
    case 'stripe':
      // return new StripeAdapter(...);
      throw new Error('Stripe adapter not implemented yet');
    default:
      throw new Error(`Unknown Payment Gateway: ${activeGateway}`);
  }
}

// ============================================================================
// 5. MAIN LOGIC (Gateway Agnostic)
// ============================================================================

// Initialize Supabase
const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const adapter = getGatewayAdapter();
    console.log(`🔄 Starting Reconciliation via Adapter: ${adapter.getName()}`);

    // 1. Fetch from Gateway (Generic)
    const transactions = await adapter.fetchRecentTransactions(50);
    console.log(`📡 Fetched ${transactions.length} recent charges`);

    const results = {
      total: transactions.length,
      synced: 0,
      skipped: 0,
      errors: 0,
      details: [] as any[],
    };

    // 2. Loop and Sync (Generic Logic)
    for (const txn of transactions) {
      // Only care about SUCCESSFUL charges
      if (txn.status !== 'successful') {
        continue;
      }

      const { userId, referenceId, id, amount, metadata } = txn;

      if (!userId) {
        console.warn(`⚠️ Skipped txn ${id}: No userId in metadata`);
        continue;
      }

      // 3. Check if exists in our DB
      const { data: existing } = await supabase
        .from('transactions')
        .select('id')
        .eq('reference_id', referenceId)
        .maybeSingle();

      if (existing) {
        results.skipped++;
        continue;
      }

      console.log(`⚡ Found MISSING Transaction! ID: ${id}, Amount: ${amount}, User: ${userId}`);

      // 4. INSERT into DB
      // Determine Wallet Amount (Net/Gross logic might depend on Gateway fees)
      // Ideally, Adapter should provide 'netAmount' if available, otherwise fallback.

      // Check for specific metadata keys standardized across our app
      const walletAmount = metadata.wallet_amount_satang || amount;

      const { data: rpcData, error: rpcError } = await supabase.rpc(
        'process_inbound_transaction',
        {
          p_user_id: userId,
          p_amount_satang: amount, // 💎 TRUTH: Charge Amount (Gross)
          p_provider: adapter.getName(), // 'omise', 'stripe', etc.
          p_provider_txn_id: id,
          p_reference_id: referenceId!,
          p_description: txn.description || 'Top Up (Auto-Synced)',
          p_metadata: {
            ...metadata, // Preserve original metadata
            auto_reconciled: true,
            reconciled_at: new Date().toISOString(),
            gateway_raw: txn, // Optional: Store raw data for audit
          },
        },
      );

      if (rpcError) {
        console.error(`❌ Sync Failed for ${id}:`, rpcError);
        results.errors++;
        results.details.push({ id: id, error: rpcError.message });
      } else {
        console.log(`✅ Synced Successfully: ${id}`);
        results.synced++;
        results.details.push({ id: id, status: 'RESTORED' });
      }
    }

    console.log('🏁 Reconciliation Complete:', results);

    return new Response(JSON.stringify(results), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error('🚨 Fatal Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
