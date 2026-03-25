/**
 * Paycif Backend Integration (Supabase)
 * 
 * Instructions:
 * 1. Create a Supabase project at supabase.com
 * 2. Create a table 'waitlist' with columns: 'email' (text), 'ref_code' (text), 'created_at' (timestamp)
 * 3. Replace the URL and KEY below.
 */

const SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

async function joinWaitlist(email, refCode = '') {
    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/waitlist`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal'
            },
            body: JSON.stringify({
                email: email,
                ref_code: refCode,
                source: window.location.hostname
            })
        });

        if (!response.ok) throw new Error('Could not join waitlist');
        return { success: true };
    } catch (err) {
        console.error('Waitlist Error:', err);
        return { success: false, error: err.message };
    }
}
