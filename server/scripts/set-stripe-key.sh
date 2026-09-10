#!/bin/bash
#
# Sets (or replaces) the Stripe secret key on the deployed Worker.
#
# Separate from setup.sh because this is the one thing likely to need a second
# attempt, and re-running the whole deployment for it is overkill.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${SERVER_DIR}"

WORKER_URL="https://localflow-licensing.maxleinz.workers.dev"

die() { printf '\n\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

# Repairs the two things that silently break a pasted key.
#
# A paste that arrives twice produces one string of exactly double length. That
# is invisible at a prompt that echoes nothing, and Stripe just answers
# "Invalid API Key" — which is how an hour got lost once already.
clean_key() {
    local key="$1"
    key="$(printf '%s' "${key}" | tr -d '[:space:]')"

    local half=$(( ${#key} / 2 ))
    if [ $(( ${#key} % 2 )) -eq 0 ] && [ "${half}" -gt 20 ]; then
        local first="${key:0:half}" second="${key:half}"
        if [ "${first}" = "${second}" ]; then
            printf '%s' "${first}"
            return 0
        fi
    fi
    printf '%s' "${key}"
}

printf '\033[1mStripe secret key\033[0m\n\n'
cat <<'NOTE'
Stripe dashboard -> Developers -> API keys -> Secret key -> Reveal, then copy.

Paste it below and press Return. Nothing appears while you type — that is
normal. The number of characters is shown back so you can tell the paste
arrived exactly once.

NOTE

read -rsp "Paste the key: " RAW </dev/tty
echo

[ -n "${RAW}" ] || die "Nothing was pasted."

KEY="$(clean_key "${RAW}")"
unset RAW

printf 'Read %s characters.\n' "${#KEY}"

case "${KEY}" in
    sk_live_*) echo "Live key detected — real payments." ;;
    sk_test_*) echo "Test key detected — no real money will move." ;;
    whsec_*)   die "That is the webhook signing secret, not the secret key.
Use: npx wrangler secret put STRIPE_WEBHOOK_SECRET" ;;
    pk_*)      die "That is the publishable key. You need the secret one (sk_…)." ;;
    *)         die "That does not start with sk_live_ or sk_test_." ;;
esac

echo
echo "Asking Stripe whether the key works…"
STATUS="$(curl -s -o /dev/null -w '%{http_code}' -u "${KEY}:" https://api.stripe.com/v1/balance || echo 000)"

case "${STATUS}" in
    200) printf '\033[32mStripe accepted it.\033[0m\n' ;;
    401) die "Stripe rejected this key.

Either it was rolled again after you copied it, or the paste is incomplete.
Reveal the current key in Stripe, copy the whole line, and run this again." ;;
    000) die "Could not reach Stripe. Check your internet connection." ;;
    *)   die "Stripe answered HTTP ${STATUS}. Not uploading a key it is unhappy with." ;;
esac

echo
echo "Uploading to Cloudflare…"
printf '%s' "${KEY}" | npx wrangler secret put STRIPE_SECRET_KEY
unset KEY

echo
echo "Testing the live checkout endpoint…"
sleep 3
CHECKOUT="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Origin: https://therealone00.github.io" "${WORKER_URL}/api/checkout" || echo 000)"

echo
if [ "${CHECKOUT}" = "200" ]; then
    printf '\033[32m==================================================\033[0m\n'
    printf '\033[32m Checkout works. People can buy LocalFlow Pro now.\033[0m\n'
    printf '\033[32m==================================================\033[0m\n'
else
    printf '\033[31mCheckout still answers HTTP %s.\033[0m\n' "${CHECKOUT}"
    echo "See what the Worker says with:  cd server && npx wrangler tail"
fi
