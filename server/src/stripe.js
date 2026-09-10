/**
 * Minimal Stripe REST client.
 *
 * The official SDK pulls in a lot for two endpoints, and Workers are happier
 * with plain fetch.
 */

const API = 'https://api.stripe.com/v1';

async function call(path, secretKey, { method = 'GET', form } = {}) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Stripe-Version': '2024-06-20',
    },
    body: form ? new URLSearchParams(form).toString() : undefined,
  });

  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message ?? `Stripe responded ${response.status}`);
  }
  return body;
}

export function createCheckoutSession(secretKey, { priceCents, productName, successUrl, cancelUrl }) {
  return call('/checkout/sessions', secretKey, {
    method: 'POST',
    form: {
      mode: 'payment',
      'line_items[0][quantity]': '1',
      'line_items[0][price_data][currency]': 'eur',
      'line_items[0][price_data][unit_amount]': String(priceCents),
      'line_items[0][price_data][product_data][name]': productName,
      'line_items[0][price_data][product_data][description]':
        'One-time purchase. Works on every Mac you own, with free updates.',
      // Needed to email the key and to let a customer recover it later.
      customer_creation: 'always',
      'payment_intent_data[description]': productName,
      success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl,
      // EU one-time digital sale: let Stripe handle VAT.
      'automatic_tax[enabled]': 'true',
      billing_address_collection: 'auto',
    },
  });
}

export function retrieveCheckoutSession(secretKey, sessionId) {
  return call(`/checkout/sessions/${encodeURIComponent(sessionId)}`, secretKey);
}

/**
 * Verifies the `Stripe-Signature` header.
 *
 * Without this anyone could POST a fabricated `checkout.session.completed` and
 * mint themselves a license, so an unverifiable payload is dropped outright.
 */
export async function verifyWebhookSignature(rawBody, signatureHeader, webhookSecret, toleranceSeconds = 300) {
  if (!signatureHeader) return false;

  const parts = Object.fromEntries(
    signatureHeader.split(',').map((piece) => piece.split('=', 2)),
  );
  const timestamp = parts.t;
  const provided = parts.v1;
  if (!timestamp || !provided) return false;

  // Reject replays of an old, genuinely-signed payload.
  const age = Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp));
  if (!Number.isFinite(age) || age > toleranceSeconds) return false;

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );

  const expected = [...new Uint8Array(mac)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');

  return timingSafeEqual(expected, provided);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i += 1) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}
