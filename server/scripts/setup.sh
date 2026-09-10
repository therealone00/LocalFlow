#!/bin/bash
#
# One-shot setup for LocalFlow Pro licensing.
#
# Does everything except type your secrets: installs wrangler, logs in to
# Cloudflare, creates the KV namespace, wires wrangler.toml, deploys the Worker
# and patches the deployed URL into both website pages.
#
# You are prompted for the two Stripe secrets. They are read without echoing,
# go straight into Cloudflare's secret store, and are never written to disk,
# to this repo, or to your shell history.
#
# Usage:  ./server/scripts/setup.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SERVER_DIR}/.." && pwd)"

cd "${SERVER_DIR}"

# Runs a command with a real terminal attached while capturing its output.
#
# Piping wrangler through tee makes it believe it is non-interactive, at which
# point it silently answers its own prompts with defaults — that is how the
# workers.dev subdomain question got auto-answered "no". `script` gives it a
# genuine PTY, so prompts still reach the user.
run_capture() {
    local logfile="$1"; shift
    script -q "${logfile}" "$@" </dev/tty
}

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }
die()  { printf '\033[31mError: %s\033[0m\n' "$1" >&2; exit 1; }

command -v node >/dev/null || die "Node.js is required. Install it from https://nodejs.org"

# ---------------------------------------------------------------- 0. signing key
step "Checking the license signing key"
if [ ! -f "${SERVER_DIR}/.signing-key.json" ]; then
    warn "No signing key found — generating one."
    node "${SCRIPT_DIR}/generate-keypair.mjs"
    warn ""
    warn "Copy the public key printed above into publicKeyBase64 in"
    warn "Sources/LocalFlow/Licensing/LicenseVerifier.swift, then run this again."
    exit 1
fi

PUBLIC_KEY="$(node -e "console.log(require('${SERVER_DIR}/.signing-key.json').publicKey)")"
EMBEDDED_KEY="$(grep -o 'publicKeyBase64 = "[^"]*"' \
    "${ROOT_DIR}/Sources/LocalFlow/Licensing/LicenseVerifier.swift" | sed 's/.*"\(.*\)"/\1/')"

if [ "${PUBLIC_KEY}" != "${EMBEDDED_KEY}" ]; then
    die "The app is built against a different public key than server/.signing-key.json.
     App:  ${EMBEDDED_KEY}
     Here: ${PUBLIC_KEY}
     Licenses signed by this Worker would not activate. Fix LicenseVerifier.swift first."
fi
echo "Signing key matches the key compiled into the app."

# ---------------------------------------------------------------- 1. deps
step "Installing wrangler"
npm install --silent

# Wrangler sends anonymous usage telemetry by default. Not on this project.
npx wrangler telemetry disable >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 2. login
step "Connecting to Cloudflare"

# `wrangler whoami` exits 0 whether or not you are logged in, so the exit code
# says nothing. The output is what has to be read.
is_authenticated() {
    local out
    out="$(npx wrangler whoami 2>&1 || true)"
    if echo "${out}" | grep -qiE "not authenticated|you are not logged in"; then
        return 1
    fi
    echo "${out}" | grep -qiE "account name|account id|associated with the email"
}

if is_authenticated; then
    npx wrangler whoami 2>&1 | grep -iE "email|account name" | head -3
    echo "Already connected."
else
    if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
        die "CLOUDFLARE_API_TOKEN is set but Cloudflare rejected it. Unset it to log in
     through the browser instead, or replace it with a valid token."
    fi
    echo "Not logged in yet. A browser window will open — approve the request,"
    echo "then come back to this window."
    echo
    # Deliberately not captured: wrangler needs a real terminal to run the
    # OAuth flow, and any redirection here makes it bail out as non-interactive.
    npx wrangler login
    is_authenticated || die "Cloudflare login did not complete. Run it again with:
       cd server && npx wrangler login
     Or, if this machine cannot open a browser, create an API token at
     https://developers.cloudflare.com/fundamentals/api/get-started/create-token/
     and re-run this script with CLOUDFLARE_API_TOKEN=... in front of it."
    echo "Connected."
fi

# ---------------------------------------------------------------- 3. KV
step "Setting up the KV namespace"
if grep -q 'REPLACE_WITH_KV_NAMESPACE_ID' wrangler.toml; then
    # tee rather than $(...) so wrangler keeps printing to the terminal and its
    # output can still be parsed.
    KV_LOG="$(mktemp)"
    run_capture "${KV_LOG}" npx wrangler kv namespace create LICENSES || true
    KV_ID="$(grep -oE 'id[[:space:]]*=[[:space:]]*"[0-9a-f]{32}"' "${KV_LOG}" \
        | grep -oE '[0-9a-f]{32}' | head -1)"
    [ -n "${KV_ID}" ] || KV_ID="$(grep -oE '[0-9a-f]{32}' "${KV_LOG}" | head -1)"
    rm -f "${KV_LOG}"
    [ -n "${KV_ID}" ] || die "Could not read the namespace id from wrangler's output. Paste it into wrangler.toml by hand and re-run."
    # Portable in-place edit; BSD sed needs the empty -i argument.
    sed -i '' "s/REPLACE_WITH_KV_NAMESPACE_ID/${KV_ID}/" wrangler.toml
    echo "wrangler.toml now points at namespace ${KV_ID}"
else
    echo "wrangler.toml already has a namespace id — leaving it alone."
fi

# ---------------------------------------------------------------- 4. secrets
step "Stripe secrets"
cat <<'NOTE'
These are read without echoing and piped straight into Cloudflare's secret
store. They are never written to a file and never enter your shell history.

Get them from the Stripe dashboard:
  Secret key      Developers -> API keys -> Secret key
  Webhook secret  Developers -> Webhooks -> your endpoint -> Signing secret
                  (create the endpoint after this script prints the Worker URL,
                   then re-run with --secrets-only to set it)

If a key has ever been shared anywhere, roll it in Stripe first and paste the
new one.
NOTE

EXISTING_SECRETS="$(npx wrangler secret list 2>/dev/null || true)"

secret_already_set() {
    echo "${EXISTING_SECRETS}" | grep -q "\"$1\""
}

ask_replace() {
    local answer
    read -rp "$1 is already set. Replace it? [y/N] " answer </dev/tty
    case "${answer}" in [yY]*) return 0 ;; *) return 1 ;; esac
}

SKIP_STRIPE_KEY=false
if secret_already_set "STRIPE_SECRET_KEY" && ! ask_replace "STRIPE_SECRET_KEY"; then
    SKIP_STRIPE_KEY=true
    echo "Keeping the existing Stripe secret key."
fi

if [ "${SKIP_STRIPE_KEY}" = true ]; then
    STRIPE_KEY=""
else
    read -rsp $'\nStripe secret key (sk_live_… or sk_test_…): ' STRIPE_KEY </dev/tty; echo
fi
if [ -n "${STRIPE_KEY}" ]; then
    case "${STRIPE_KEY}" in
        sk_live_*|sk_test_*) : ;;
        *) die "That does not look like a Stripe secret key (expected sk_live_ or sk_test_)." ;;
    esac
    printf '%s' "${STRIPE_KEY}" | npx wrangler secret put STRIPE_SECRET_KEY
    unset STRIPE_KEY
else
    warn "Skipped — the Worker will not be able to reach Stripe until this is set."
fi

SKIP_WEBHOOK=false
if secret_already_set "STRIPE_WEBHOOK_SECRET" && ! ask_replace "STRIPE_WEBHOOK_SECRET"; then
    SKIP_WEBHOOK=true
    echo "Keeping the existing webhook signing secret."
fi

if [ "${SKIP_WEBHOOK}" = true ]; then
    WEBHOOK_SECRET=""
else
    read -rsp $'Stripe webhook signing secret (whsec_…, blank to skip): ' WEBHOOK_SECRET </dev/tty; echo
fi
if [ -n "${WEBHOOK_SECRET}" ]; then
    case "${WEBHOOK_SECRET}" in
        whsec_*) : ;;
        *) die "That does not look like a webhook signing secret (expected whsec_)." ;;
    esac
    printf '%s' "${WEBHOOK_SECRET}" | npx wrangler secret put STRIPE_WEBHOOK_SECRET
    unset WEBHOOK_SECRET
else
    warn "Skipped — set it once you have created the webhook endpoint."
fi

step "Uploading the license signing key"
if secret_already_set "LICENSE_SIGNING_KEY"; then
    echo "Already uploaded — leaving it alone."
    echo "Replacing it would invalidate every license already issued."
else
    node -e "process.stdout.write(require('${SERVER_DIR}/.signing-key.json').privateKey)" \
        | npx wrangler secret put LICENSE_SIGNING_KEY
fi

# ---------------------------------------------------------------- 5. deploy
step "Deploying the Worker"
cat <<'NOTE'
If this is your first Worker, Cloudflare will ask whether to register a
workers.dev subdomain. Answer yes — that is the address your Worker gets.
NOTE

DEPLOY_LOG="$(mktemp)"
run_capture "${DEPLOY_LOG}" npx wrangler deploy || true
WORKER_URL="$(grep -oE 'https://[a-zA-Z0-9.-]+\.workers\.dev' "${DEPLOY_LOG}" \
    | grep -v 'dash.cloudflare.com' | head -1)"

if [ -z "${WORKER_URL}" ]; then
    if grep -q 'workers.dev subdomain' "${DEPLOY_LOG}"; then
        ONBOARDING="$(grep -oE 'https://dash\.cloudflare\.com/[a-f0-9]+/workers/onboarding' "${DEPLOY_LOG}" | head -1)"
        rm -f "${DEPLOY_LOG}"
        die "Your Cloudflare account has no workers.dev subdomain yet.

     Register one here (one-time, takes a minute):
       ${ONBOARDING:-https://dash.cloudflare.com/ -> Workers & Pages -> Get started}

     Then double-click this file again. Your KV namespace and secrets are
     already in place, so it will pick up where it left off."
    fi
    rm -f "${DEPLOY_LOG}"
    die "Deploy did not produce a Worker URL. The output above says why."
fi
rm -f "${DEPLOY_LOG}"

# ---------------------------------------------------------------- 6. wire the site
step "Pointing the website at ${WORKER_URL}"
for page in "${ROOT_DIR}/docs/index.html" "${ROOT_DIR}/docs/success.html"; do
    sed -i '' -E "s#(const LICENSING_API = ')[^']*(';)#\1${WORKER_URL}\2#" "${page}"
    echo "  updated $(basename "${page}")"
done

# ---------------------------------------------------------------- 7. smoke test
step "Checking the Worker responds"
CHECKOUT_STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Origin: https://therealone00.github.io" "${WORKER_URL}/api/checkout" || true)"
case "${CHECKOUT_STATUS}" in
    200) echo "Checkout endpoint is live and talking to Stripe." ;;
    403) warn "Got 403 — check ALLOWED_ORIGINS in wrangler.toml." ;;
    500) warn "Got 500 — the Stripe secret is probably missing or wrong. Try: npx wrangler tail" ;;
    *)   warn "Got HTTP ${CHECKOUT_STATUS}. Try: npx wrangler tail" ;;
esac

# ---------------------------------------------------------------- done
bold ""
bold "=================================================="
bold " Worker deployed: ${WORKER_URL}"
bold "=================================================="
cat <<NEXT

Remaining steps:

  1. Stripe dashboard -> Developers -> Webhooks -> Add endpoint
       URL:    ${WORKER_URL}/api/webhook
       Event:  checkout.session.completed
     Copy the signing secret it shows you, then run:
       npx wrangler secret put STRIPE_WEBHOOK_SECRET

  2. Commit the website change:
       git add docs/ server/wrangler.toml
       git commit -m "chore(licensing): point the site at the deployed Worker"
       git push

  3. Test with Stripe in test mode and card 4242 4242 4242 4242.
     Watch it live with:  npx wrangler tail

NEXT
