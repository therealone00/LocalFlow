#!/bin/bash
#
# Double-click to set the Stripe secret key on the deployed Worker.
# One paste, then it checks the key with Stripe and tests live checkout.
#
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

clear
cat <<'BANNER'
┌──────────────────────────────────────────────────────────────┐
│  LocalFlow Pro — set the Stripe key                          │
└──────────────────────────────────────────────────────────────┘

The key currently stored was pasted twice by accident: 214 characters
instead of 107. Stripe rejected it, which is why checkout returns an
error. Nothing else is wrong.

Just paste it once more. If it arrives doubled again, this script now
repairs it by itself, and it checks the key with Stripe before saving.

Where to find it:
  Stripe -> Developers -> API keys -> Secret key -> Reveal -> copy

BANNER

read -rp "Press Return when you have the key copied. "
echo

./server/scripts/set-stripe-key.sh
STATUS=$?

echo
[ $STATUS -eq 0 ] || printf '\033[31mStopped. The message above says why.\033[0m\n'
read -rp "Press Return to close. "
