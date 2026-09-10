#!/usr/bin/env node
// Generates the Ed25519 keypair used to sign LocalFlow Pro licenses.
//
// The private key is written to server/.signing-key.json, which is gitignored
// and must never be committed. Only the public key is printed — it is embedded
// in the app so licenses can be verified offline.
//
// Usage:  node server/scripts/generate-keypair.mjs

import { generateKeyPairSync } from 'node:crypto';
import { writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const outPath = join(here, '..', '.signing-key.json');

if (existsSync(outPath) && !process.argv.includes('--force')) {
  console.error(`Refusing to overwrite ${outPath}.`);
  console.error('Rotating the key invalidates every license already issued.');
  console.error('Pass --force if that is really what you want.');
  process.exit(1);
}

const { publicKey, privateKey } = generateKeyPairSync('ed25519');

// Raw 32-byte keys, base64. DER wrappers are stripped so both the Worker's
// WebCrypto import and CryptoKit on the app side get what they expect.
const rawPublic = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
const rawPrivate = privateKey.export({ type: 'pkcs8', format: 'der' }).subarray(-32);

writeFileSync(
  outPath,
  JSON.stringify(
    {
      algorithm: 'Ed25519',
      privateKey: rawPrivate.toString('base64'),
      publicKey: rawPublic.toString('base64'),
      createdAt: new Date().toISOString(),
    },
    null,
    2,
  ),
  { mode: 0o600 },
);

console.log('Keypair written to server/.signing-key.json (gitignored, mode 600).');
console.log('');
console.log('1. Embed this public key in Sources/LocalFlow/Licensing/LicenseVerifier.swift:');
console.log('');
console.log(`   ${rawPublic.toString('base64')}`);
console.log('');
console.log('2. Push the private key to Cloudflare (it is never printed here):');
console.log('');
console.log('   node -e "console.log(require(\'./server/.signing-key.json\').privateKey)" \\');
console.log('     | npx wrangler secret put LICENSE_SIGNING_KEY');
console.log('');
