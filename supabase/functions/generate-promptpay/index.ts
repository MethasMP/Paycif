import { serve } from 'std/server';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// CRC16 CCITT Calculation function
function crc16(data: string): string {
  let crc = 0xFFFF;
  for (let i = 0; i < data.length; i++) {
    const code = data.charCodeAt(i);
    crc ^= code << 8;
    for (let j = 0; j < 8; j++) {
      if ((crc & 0x8000) !== 0) {
        crc = (crc << 1) ^ 0x1021;
      } else {
        crc = crc << 1;
      }
    }
    crc &= 0xFFFF;
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { promptpayId, amount } = body;

    if (!promptpayId) {
      return new Response(
        JSON.stringify({ success: false, error: 'promptpayId is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 1. Format PromptPay ID
    // It can be a phone number (e.g., "0812345678") or a National ID (e.g., "1101234567890")
    const sanitizedId = promptpayId.replace(/[^0-9]/g, '');
    let formattedPP = '';
    let targetTag = '';

    if (sanitizedId.length === 10 || sanitizedId.length === 9) {
      // Mobile Number: Remove leading 0 (if present) and prepend country code (66)
      let mobile = sanitizedId;
      if (mobile.startsWith('0')) {
        mobile = mobile.substring(1);
      }
      formattedPP = '0066' + mobile;
      targetTag = '01'; // Tag 01 for mobile phone
    } else if (sanitizedId.length === 13) {
      // National ID / Card ID
      formattedPP = sanitizedId;
      targetTag = '02'; // Tag 02 for National ID
    } else if (sanitizedId.length === 15) {
      // E-Wallet ID / Bill Payment ID
      formattedPP = sanitizedId;
      targetTag = '03'; // Tag 03 for E-Wallet / Bill Payment ID
    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid promptpayId format. Must be a 9-10 digit mobile number, 13-digit National ID, or 15-digit E-Wallet ID.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Construct EMVCo Payload
    let payload = '';

    // Tag 00: Payload Format Indicator (Value "01")
    payload += '000201';

    // Tag 01: Point of Initiation Method
    // "11" for Static QR (non-reusable, or reusable but no amount)
    // "12" for Dynamic QR (includes amount)
    const hasAmount = amount !== undefined && amount !== null && amount !== '';
    payload += hasAmount ? '010212' : '010211';

    // Tag 29: Merchant Account Information - PromptPay
    // Value is AID + PromptPay ID (Formatted)
    // PromptPay AID is "A000000677010111"
    const aidSubtag = '0016A000000677010111';
    const ppSubtag = targetTag + String(formattedPP.length).padStart(2, '0') + formattedPP;
    const tag29Value = aidSubtag + ppSubtag;
    payload += '29' + String(tag29Value.length).padStart(2, '0') + tag29Value;

    // Tag 53: Transaction Currency (Value "764" for Thai Baht THB)
    payload += '5303764';

    // Tag 54: Transaction Amount (only if amount is present)
    if (hasAmount) {
      const parsedAmount = parseFloat(String(amount));
      if (isNaN(parsedAmount) || parsedAmount <= 0) {
        return new Response(
          JSON.stringify({ success: false, error: 'Invalid amount. Must be a positive number.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      const amountStr = parsedAmount.toFixed(2);
      payload += '54' + String(amountStr.length).padStart(2, '0') + amountStr;
    }

    // Tag 58: Country Code (Value "TH")
    payload += '5802TH';

    // Tag 63: CRC16 Checksum
    // Add Tag 63, length 04, then calculate checksum on everything up to this point
    payload += '6304';
    const checksum = crc16(payload);
    payload += checksum;

    return new Response(
      JSON.stringify({
        success: true,
        payload: payload,
        promptpayId: promptpayId,
        formattedId: formattedPP,
        type: targetTag === '01' ? 'MOBILE' : (targetTag === '02' ? 'NATIONAL_ID' : 'E_WALLET'),
        amount: hasAmount ? parseFloat(String(amount)) : null,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
