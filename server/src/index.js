import { issueLicense } from './license.js';
import {
  createCheckoutSession,
  retrieveCheckoutSession,
  verifyWebhookSignature,
} from './stripe.js';

/**
 * LocalFlow Pro licensing.
 *
 *   POST /api/checkout          → a Stripe Checkout URL
 *   POST /api/webhook           → Stripe calls this once a payment completes
 *   GET  /api/license?session_id → the signed key, for the success page
 *
 * This Worker exists only around a purchase. The app never talks to it: license
 * keys are verified offline, so dictation keeps working with no network at all.
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin');

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin, env) });
    }

    try {
      switch (`${request.method} ${url.pathname}`) {
        case 'POST /api/checkout':
          return await handleCheckout(request, env, origin);
        case 'POST /api/webhook':
          return await handleWebhook(request, env);
        case 'GET /api/license':
          return await handleLicenseLookup(url, env, origin);
        default:
          return json({ error: 'Not found' }, 404, origin, env);
      }
    } catch (error) {
      // Never leak Stripe or key-handling detail to the browser.
      console.error(`${url.pathname} failed:`, error?.message ?? error);
      return json({ error: 'Something went wrong. Please try again.' }, 500, origin, env);
    }
  },
};

// ---------------------------------------------------------------- checkout

async function handleCheckout(request, env, origin) {
  if (!isAllowedOrigin(origin, env)) {
    return json({ error: 'Origin not allowed' }, 403, origin, env);
  }

  const session = await createCheckoutSession(env.STRIPE_SECRET_KEY, {
    priceCents: Number(env.PRICE_EUR_CENTS ?? 1500),
    productName: env.PRODUCT_NAME ?? 'LocalFlow Pro',
    successUrl: env.SUCCESS_URL,
    cancelUrl: env.CANCEL_URL,
  });

  return json({ url: session.url }, 200, origin, env);
}

// ----------------------------------------------------------------- webhook

async function handleWebhook(request, env) {
  const rawBody = await request.text();
  const signature = request.headers.get('Stripe-Signature');

  const isAuthentic = await verifyWebhookSignature(
    rawBody,
    signature,
    env.STRIPE_WEBHOOK_SECRET,
  );
  if (!isAuthentic) {
    // 400 rather than 401: Stripe retries on 5xx, and a forged call should not
    // be retried at all.
    return new Response('Invalid signature', { status: 400 });
  }

  const event = JSON.parse(rawBody);
  if (event.type !== 'checkout.session.completed') {
    return new Response('Ignored', { status: 200 });
  }

  const session = event.data.object;
  if (session.payment_status !== 'paid') {
    return new Response('Not paid', { status: 200 });
  }

  await storeLicenseForSession(session, env);
  return new Response('OK', { status: 200 });
}

// ------------------------------------------------------------------ lookup

async function handleLicenseLookup(url, env, origin) {
  const sessionId = url.searchParams.get('session_id');
  if (!sessionId || !sessionId.startsWith('cs_')) {
    return json({ error: 'Missing session_id' }, 400, origin, env);
  }

  const stored = await env.LICENSES.get(sessionId, { type: 'json' });
  if (stored) {
    return json({ key: stored.key, email: stored.email }, 200, origin, env);
  }

  // The success page usually loads before the webhook lands. Confirm payment
  // directly with Stripe rather than making the customer wait or refresh.
  let session;
  try {
    session = await retrieveCheckoutSession(env.STRIPE_SECRET_KEY, sessionId);
  } catch (error) {
    // An id Stripe does not recognise is the customer's problem to see, not a
    // server fault: returning 500 here made a mistyped link look like an outage.
    console.error(`license lookup for ${sessionId}:`, error?.message ?? error);
    return json({ error: 'We could not find that order.' }, 404, origin, env);
  }

  if (session.payment_status !== 'paid') {
    return json({ error: 'This purchase is not complete yet.' }, 402, origin, env);
  }

  const record = await storeLicenseForSession(session, env);
  return json({ key: record.key, email: record.email }, 200, origin, env);
}

/**
 * Issues and stores exactly one license per checkout session. Stripe delivers
 * webhooks at least once, so this must be safe to run twice.
 */
async function storeLicenseForSession(session, env) {
  const existing = await env.LICENSES.get(session.id, { type: 'json' });
  if (existing) return existing;

  const email =
    session.customer_details?.email ?? session.customer_email ?? 'unknown@localflow.app';

  const key = await issueLicense({
    email,
    orderId: session.id,
    signingKey: env.LICENSE_SIGNING_KEY,
  });

  const record = { key, email, issuedAt: new Date().toISOString() };
  await env.LICENSES.put(session.id, JSON.stringify(record));
  return record;
}

// ------------------------------------------------------------------- utils

function allowedOrigins(env) {
  return (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

function isAllowedOrigin(origin, env) {
  return Boolean(origin) && allowedOrigins(env).includes(origin);
}

function corsHeaders(origin, env) {
  const headers = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
  if (isAllowedOrigin(origin, env)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  return headers;
}

function json(body, status, origin, env) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...corsHeaders(origin, env),
    },
  });
}
