import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const omiseSecretKey = Deno.env.get('OMISE_SECRET_KEY')!;

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // 1. Auth Validation
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing Authorization header', 401);

    const jwtToken = authHeader.replace('Bearer ', '');
    const userResp = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${jwtToken}`,
        'apikey': supabaseAnonKey,
      },
    });

    if (!userResp.ok) return jsonError('Unauthorized', 401);
    const { id: userId } = await userResp.json();

    // 2. Input Parsing
    const { action, card_id } = await req.json();

    if (action !== 'delete-card' || !card_id) {
      return jsonError('Invalid action or card_id', 400);
    }

    console.log(`[ManageCards] Requested delete: ${card_id} for user: ${userId}`);

    // 3. SECURITY CHECK: Check for active transactions
    // We prevent deletion if there are any PENDING transactions for this user
    // to ensure reconciliations can still happen if needed.
    const { data: activeTxns, error: txnError } = await adminClient
      .from('transactions')
      .select('id')
      .eq(
        'wallet_id',
        (await adminClient.from('wallets').select('id').eq('profile_id', userId).eq(
          'currency',
          'THB',
        ).single()).data?.id,
      )
      .eq('status', 'PENDING')
      .limit(1);

    if (activeTxns && activeTxns.length > 0) {
      return jsonError(
        'Cannot delete card while transactions are pending',
        403,
        'ACTIVE_TRANSACTIONS',
      );
    }

    // 4. Get Profile for Omise Customer ID
    const { data: profile } = await adminClient
      .from('profiles')
      .select('omise_customer_id, preferred_payment_method_id')
      .eq('id', userId)
      .single();

    if (!profile?.omise_customer_id) return jsonError('Omise customer not found', 404);

    // 5. Delete from Omise
    const authHeaderOpn = `Basic ${btoa(omiseSecretKey + ':')}`;
    const deleteResp = await fetch(
      `https://api.omise.co/customers/${profile.omise_customer_id}/cards/${card_id}`,
      {
        method: 'DELETE',
        headers: { 'Authorization': authHeaderOpn },
      },
    );

    if (!deleteResp.ok) {
      const err = await deleteResp.text();
      console.error('[Omise] Card deletion failed:', err);
      return jsonError('Failed to delete card from provider', 400);
    }

    // 6. INVALIDATE CACHE (Redis-like experience)
    console.log(`[Cache] Invalidating card cache for ${userId}`);
    await adminClient.from('cache_saved_cards').delete().eq('user_id', userId);

    // 7. If it was the preferred card, reset it
    if (profile.preferred_payment_method_id === card_id) {
      console.log(`[ManageCards] Resetting preferred_payment_method for ${userId}`);
      await adminClient
        .from('profiles')
        .update({
          preferred_payment_method_id: null,
          preferred_payment_method_type: null,
        })
        .eq('id', userId);
    }

    return jsonResponse({
      success: true,
      message: 'Card deleted successfully',
    }, 200);
  } catch (error) {
    console.error(`[Error] Unhandled:`, error);
    return jsonError(error instanceof Error ? error.message : 'Internal Server Error', 500);
  }
});

function jsonResponse(body: any, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(message: string, status: number, code?: string): Response {
  return jsonResponse({ success: false, message, error_code: code }, status);
}
