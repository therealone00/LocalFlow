# LocalFlow licensing Worker

Creates Stripe Checkout sessions and issues offline-verifiable Pro licenses.

The app never calls this Worker. Licenses are Ed25519-signed and verified
locally, so buying Pro is the only moment LocalFlow touches a network at all.

## Endpoints

| Method | Path                       | Purpose                                       |
| ------ | -------------------------- | --------------------------------------------- |
| `POST` | `/api/checkout`            | Returns a Stripe Checkout URL                  |
| `POST` | `/api/webhook`             | Stripe calls this once payment completes       |
| `GET`  | `/api/license?session_id=` | Returns the signed key for the success page    |

## Setup

### 1. Signing keypair

```bash
npm run keypair
```

Writes `server/.signing-key.json` (gitignored, mode 600) and prints the public
key. **Rotating this key invalidates every license already sold**, so back the
file up somewhere safe.

Paste the printed public key into `LicenseVerifier.publicKeyBase64` in
`Sources/LocalFlow/Licensing/LicenseVerifier.swift`.

### 2. KV namespace

```bash
npx wrangler kv namespace create LICENSES
```

Put the returned id into `wrangler.toml`.

### 3. Secrets

Never in `wrangler.toml` — these go into Cloudflare's secret store:

```bash
npx wrangler secret put STRIPE_SECRET_KEY        # sk_live_… or sk_test_…
npx wrangler secret put STRIPE_WEBHOOK_SECRET    # whsec_… (step 5)

node -e "console.log(require('./.signing-key.json').privateKey)" \
  | npx wrangler secret put LICENSE_SIGNING_KEY
```

### 4. Deploy

```bash
npm install
npm run deploy
```

Take the deployed URL and set it as `LICENSING_API` in `docs/index.html` and
`docs/success.html`.

### 5. Stripe webhook

In the Stripe dashboard, add an endpoint pointing at
`https://<your-worker>/api/webhook` subscribed to `checkout.session.completed`.
Copy the signing secret it gives you back into `STRIPE_WEBHOOK_SECRET`.

### 6. Test the whole path

Use Stripe test mode and card `4242 4242 4242 4242`. Buy, land on the success
page, copy the key, paste it into Settings › Pro. If it activates, the loop is
closed.

```bash
npm run tail   # live Worker logs while you test
```

## Notes

- `automatic_tax` is on, so Stripe handles EU VAT on a one-time digital sale.
  Register for OSS/MOSS before selling into the EU for real.
- Licenses are stored in KV keyed by checkout session, so a customer can
  re-fetch their key from the success page URL. Webhook delivery is at-least-once
  and issuing is idempotent.
- `ALLOWED_ORIGINS` gates `/api/checkout`, so the endpoint cannot be driven from
  someone else's page.
