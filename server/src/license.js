/**
 * License key issuing.
 *
 * A key is `LF1.<base64url payload>.<base64url signature>`, signed with Ed25519.
 * The app verifies it entirely offline against the matching public key, so this
 * Worker is only ever touched at purchase time — never while someone dictates.
 */

/** PKCS#8 DER prefix for a raw Ed25519 private key seed. */
const PKCS8_ED25519_PREFIX = new Uint8Array([
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
]);

export function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function bytesToBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * Imports the raw signing seed. WebCrypto will not take a bare 32-byte Ed25519
 * private key, so it is wrapped in its PKCS#8 envelope first.
 */
async function importSigningKey(rawBase64) {
  const seed = base64ToBytes(rawBase64.trim());
  if (seed.length !== 32) {
    throw new Error(`LICENSE_SIGNING_KEY must decode to 32 bytes, got ${seed.length}`);
  }

  const pkcs8 = new Uint8Array(PKCS8_ED25519_PREFIX.length + seed.length);
  pkcs8.set(PKCS8_ED25519_PREFIX, 0);
  pkcs8.set(seed, PKCS8_ED25519_PREFIX.length);

  // Newer Workers runtimes use "Ed25519"; older ones only know "NODE-ED25519".
  for (const algorithm of ['Ed25519', 'NODE-ED25519']) {
    try {
      return await crypto.subtle.importKey('pkcs8', pkcs8, { name: algorithm }, false, ['sign']);
    } catch (error) {
      if (algorithm === 'NODE-ED25519') throw error;
    }
  }
  throw new Error('Ed25519 is unavailable in this runtime');
}

/**
 * Signs a license for one purchase.
 *
 * The payload deliberately carries nothing beyond what support needs: the email
 * the receipt went to and the checkout session id.
 */
export async function issueLicense({ email, orderId, signingKey }) {
  const payload = JSON.stringify({
    v: 1,
    p: 'pro',
    e: email,
    o: orderId,
    t: Math.floor(Date.now() / 1000),
  });

  const payloadBytes = new TextEncoder().encode(payload);
  const key = await importSigningKey(signingKey);

  let signature;
  try {
    signature = await crypto.subtle.sign('Ed25519', key, payloadBytes);
  } catch {
    signature = await crypto.subtle.sign('NODE-ED25519', key, payloadBytes);
  }

  return `LF1.${bytesToBase64Url(payloadBytes)}.${bytesToBase64Url(new Uint8Array(signature))}`;
}
