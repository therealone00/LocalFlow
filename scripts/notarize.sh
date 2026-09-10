#!/bin/bash
#
# Notarizes and staples the built app and disk image.
#
# Apple must see and approve every build before other people's Macs will open
# it without a fight. This submits the app, staples the ticket to it, rebuilds
# the DMG around the stapled app, then notarizes and staples the DMG as well —
# so the app works whether it is launched from the image or dragged out of it,
# online or offline.
#
# One-time setup:
#   ./scripts/notarize.sh --setup
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="LocalFlow"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
KEYCHAIN_PROFILE="LocalFlow"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${ROOT_DIR}/Config/Info.plist")"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-v${VERSION}.dmg"
DMG_STABLE_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
die()  { printf '\n\033[31mError: %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- setup mode
if [ "${1:-}" = "--setup" ]; then
    cat <<'NOTE'
Storing your Apple notarization credentials in the login keychain.

You need:
  1. Your Apple ID (the developer account email)
  2. Your Team ID  — appleid.apple.com or the Apple Developer portal
  3. An APP-SPECIFIC PASSWORD, not your Apple ID password:
       appleid.apple.com -> Sign-In and Security -> App-Specific Passwords

notarytool will prompt for these itself. They go straight into your keychain
and are never written to this repository.

NOTE
    xcrun notarytool store-credentials "${KEYCHAIN_PROFILE}"
    echo
    echo "Stored as keychain profile '${KEYCHAIN_PROFILE}'. Run ./scripts/notarize.sh to use it."
    exit 0
fi

# ---------------------------------------------------------------- preflight
command -v xcrun >/dev/null || die "Xcode command line tools are required."
xcrun --find notarytool >/dev/null 2>&1 || die "notarytool not found. Install Xcode 13 or later."

[ -d "${APP_BUNDLE}" ] || die "No app bundle at ${APP_BUNDLE}. Run ./scripts/build_app.sh first."

step "Checking the signature"
# Captured in one go rather than piped: under `set -o pipefail`, grep -q closes
# the pipe on its first match, codesign takes SIGPIPE, and the whole pipeline
# reports failure — which made this script reject its own correct build.
SIGN_INFO="$(codesign -dvv "${APP_BUNDLE}" 2>&1 || true)"
AUTHORITY="$(printf '%s\n' "${SIGN_INFO}" | awk -F= '/^Authority=/ {print substr($0, index($0, "=") + 1); exit}')"
echo "    ${AUTHORITY}"

case "${AUTHORITY}" in
    "Developer ID Application"*) : ;;
    *) die "The app is signed with '${AUTHORITY}'.

     Apple only notarizes builds signed with a Developer ID Application
     certificate. Create one in Xcode -> Settings -> Accounts -> Manage
     Certificates -> + -> Developer ID Application, then re-run
     ./scripts/build_app.sh" ;;
esac

case "${SIGN_INFO}" in
    *"flags="*"runtime"*) : ;;
    *) die "The app is not signed with the hardened runtime. Re-run ./scripts/build_app.sh" ;;
esac

xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" >/dev/null 2>&1 \
    || die "No notarization credentials stored.

     Run once:  ./scripts/notarize.sh --setup"

# ---------------------------------------------------------------- app
step "Submitting the app to Apple"
APP_ZIP="$(mktemp -d)/${APP_NAME}.zip"
# ditto rather than zip: it preserves the bundle's symlinks and metadata, and a
# mangled bundle is rejected without a useful explanation.
ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_ZIP}"

xcrun notarytool submit "${APP_ZIP}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait \
    || die "Notarization failed. See the log with:
     xcrun notarytool log <submission-id> --keychain-profile ${KEYCHAIN_PROFILE}"

rm -f "${APP_ZIP}"

step "Stapling the ticket to the app"
xcrun stapler staple "${APP_BUNDLE}"

# ---------------------------------------------------------------- dmg
step "Rebuilding the disk image around the stapled app"
# SKIP_BUILD keeps create_dmg.sh from recompiling and re-signing, which would
# throw away the ticket that was just stapled on.
SKIP_BUILD=1 "${ROOT_DIR}/scripts/create_dmg.sh" >/dev/null

step "Signing the disk image"
SIGNING_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
    | grep "Developer ID Application" | head -n 1 | sed -n 's/.*"\(.*\)".*/\1/p')"
codesign --force --timestamp --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"

step "Submitting the disk image to Apple"
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait \
    || die "DMG notarization failed."

step "Stapling the ticket to the disk image"
xcrun stapler staple "${DMG_PATH}"
cp "${DMG_PATH}" "${DMG_STABLE_PATH}"

# ---------------------------------------------------------------- verify
step "Verifying the result the way Gatekeeper will"
spctl -a -t exec -vvv "${APP_BUNDLE}" 2>&1 | sed 's/^/    /'
xcrun stapler validate "${APP_BUNDLE}" 2>&1 | sed 's/^/    /'
xcrun stapler validate "${DMG_PATH}" 2>&1 | sed 's/^/    /'

printf '\n\033[32m==================================================\033[0m\n'
printf '\033[32m Notarized and stapled — v%s\033[0m\n' "${VERSION}"
printf '\033[32m %s\033[0m\n' "${DMG_PATH}"
printf '\033[32m==================================================\033[0m\n'
echo
echo "This build opens on other people's Macs without a Gatekeeper warning."
