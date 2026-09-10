#!/bin/bash
#
# Double-click this file to set up and deploy the licensing Worker.
#
# It runs setup.sh in a Terminal window. Your only job is pasting the two
# Stripe secrets when it asks; everything else is automatic.
#
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

clear
cat <<'BANNER'
┌──────────────────────────────────────────────────────────────┐
│  LocalFlow Pro — licensing setup                             │
└──────────────────────────────────────────────────────────────┘

This will:
  • install wrangler and log you in to Cloudflare (opens a browser)
  • create the KV namespace and wire wrangler.toml
  • upload your secrets to Cloudflare
  • deploy the Worker
  • point the website at it
  • check that checkout responds

You will be asked for two values. Paste them with Cmd+V — nothing is
shown on screen while you type, that is intentional.

  1. Stripe secret key        sk_live_… or sk_test_…
     Stripe → Developers → API keys

  2. Webhook signing secret   whsec_…    (you can skip this one for now)
     Stripe → Developers → Webhooks → your endpoint

BANNER

printf '\033[33mIf either key has ever been pasted into a chat, an email or a\n'
printf 'ticket, roll it in Stripe first and paste the NEW one here.\033[0m\n\n'

read -rp "Press Return to start, or Ctrl+C to cancel. "

./server/scripts/setup.sh
STATUS=$?

echo
if [ $STATUS -eq 0 ]; then
    printf '\033[32mDone. You can close this window.\033[0m\n'
else
    printf '\033[31mSetup stopped (exit %s). The message above says why.\033[0m\n' "$STATUS"
    printf 'Nothing is half-deployed — fix it and double-click this file again.\n'
fi
echo
read -rp "Press Return to close. "
