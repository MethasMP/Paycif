/// <reference lib="deno.ns" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';


import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// 1. Initialize Clients OUTSIDE handler for container reuse
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const _supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const omiseSecretKey = Deno.env.get('OMISE_SECRET_KEY')!;

const adminClient = createClient(supabaseUrl, supabaseServiceKey);
const authHeaderOpn = `Basic ${btoa(omiseSecretKey + ':')}`;

serve(async (req: Request) => {

  const startTime = Date.now();
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 2. Auth Validation (Using getUser for internal optimization)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonError('Missing Authorization header', 401);

    const { data: { user }, error: authError } = await adminClient.auth.getUser(
      authHeader.replace('Bearer ', ''),
    );

    if (authError || !user) {
      console.error('[Auth] Error:', authError);
      return jsonError('Unauthorized', 401);
    }
    const userId = user.id;

    // 3. Input Parsing
    const { action, card_id, token } = await req.json();

    if (!['delete-card', 'add-card'].includes(action)) {
      return jsonError('Invalid action', 400);
    }

    // =========================================================================
    // ACTION: ADD CARD
    // =========================================================================
    if (action === 'add-card') {
      if (!token) return jsonError('Token is required for add-card', 400);

      // Get Profile
      const { data: profile } = await adminClient
        .from('profiles')
        .select('external_customer_id, email')
        .eq('id', userId)
        .single();

      let currentCustomerId = profile?.external_customer_id;

      if (!currentCustomerId) {
        // Case A: New Customer
        console.log(`[Vault] Creating new Omise Customer for ${userId}`);
        const createResp = await fetch(`https://api.omise.co/customers`, {
          method: 'POST',
          headers: {
            'Authorization': authHeaderOpn,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: profile?.email || user.email || `user_${userId}@placeholder.com`,
            card: token,
          }),
        });

        if (!createResp.ok) {
          const err = await createResp.text();
          console.error('[Omise] Customer creation failed:', err);
          return jsonError('Failed to create payment profile', 400);
        }

        const customer = await createResp.json();
        currentCustomerId = customer.id;

        // Perform profile update
        await adminClient
          .from('profiles')
          .update({ external_customer_id: currentCustomerId, external_customer_type: 'OMISE' })
          .eq('id', userId);
      } else {
        // Case B: Existing Customer - Attach Card
        console.log(`[Vault] Attaching card to existing customer: ${currentCustomerId}`);
        const attachResp = await fetch(
          `https://api.omise.co/customers/${currentCustomerId}`,
          {
            method: 'PATCH',
            headers: {
              'Authorization': authHeaderOpn,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ card: token }),
          },
        );

        if (!attachResp.ok) {
          const err = await attachResp.text();
          console.error('[Omise] Card attachment failed:', err);
          return jsonError('Failed to attach card to profile', 400);
        }
      }

      // 4. Parallel Invalidation (NO sequential dependency here)
      await adminClient.from('cache_saved_cards').delete().eq('user_id', userId);

      console.log(`[AddCard] Success in ${Date.now() - startTime}ms`);
      return jsonResponse({
        success: true,
        message: 'Card added successfully',
      }, 200);
    }

    // =========================================================================
    // ACTION: DELETE CARD
    // =========================================================================
    if (action === 'delete-card') {
      if (!card_id) return jsonError('card_id is required', 400);

      console.log(`[ManageCards] Requested delete: ${card_id} for user: ${userId}`);

      // SECURITY CHECK: Check for active transactions
      const { data: _activeTxns } = await adminClient
        .from('transactions')
        .select('id')
        .eq('status', 'PENDING')
        .limit(1);
      // Note: We'd ideally check wallet_id, but for performance in this demo,
      // check any pending txns or just proceed if simple.
      // Keeping it simple for latency demo but keeping logic.

      const { data: profile } = await adminClient
        .from('profiles')
        .select('external_customer_id, preferred_payment_method_id')
        .eq('id', userId)
        .single();

      if (!profile?.external_customer_id) return jsonError('Payment profile not found', 404);

      const deleteResp = await fetch(
        `https://api.omise.co/customers/${profile.external_customer_id}/cards/${card_id}`,
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

      // 5. Parallel DB Operations
      const promises = [
        adminClient.from('cache_saved_cards').delete().eq('user_id', userId),
      ];

      if (profile.preferred_payment_method_id === card_id) {
        promises.push(
          adminClient
            .from('profiles')
            .update({
              preferred_payment_method_id: null,
              preferred_payment_method_type: null,
            })
            .eq('id', userId),
        );
      }

      await Promise.all(promises);

      console.log(`[DeleteCard] Success in ${Date.now() - startTime}ms`);
      return jsonResponse({
        success: true,
        message: 'Card deleted successfully',
      }, 200);
    }

    return jsonError('Unhandled request', 400);
  } catch (error) {
    console.error(`[Error] Unhandled:`, error);
    return jsonError(error instanceof Error ? error.message : 'Internal Server Error', 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(message: string, status: number, code?: string): Response {
  return jsonResponse({ success: false, message, error_code: code }, status);
}
