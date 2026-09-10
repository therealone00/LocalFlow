#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="LocalFlow"
# Single source of truth: the version ships in Info.plist, never duplicated here.
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${ROOT_DIR}/Config/Info.plist")"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
# Stable-named copy so https://.../releases/latest/download/LocalFlow.dmg keeps
# working across releases. A versioned filename there breaks every download
# link on the website the moment a new version ships.
DMG_STABLE_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
DMG_TMP_DIR="/tmp/${APP_NAME}_dmg_staging"

echo "==> Building ${APP_NAME} v${VERSION} disk image..."
rm -rf "${DMG_TMP_DIR}" "${DMG_PATH}" "${DMG_STABLE_PATH}"
mkdir -p "${DMG_TMP_DIR}"

# Always rebuild. Reusing an existing bundle silently ships whatever was built
# last time — including a stale version number after a version bump.
echo "==> Building app bundle..."
"${ROOT_DIR}/scripts/build_app.sh"

echo "==> Copying application to staging..."
cp -R "${APP_BUNDLE}" "${DMG_TMP_DIR}/"

echo "==> Creating Applications symlink for drag-and-drop install..."
ln -s /Applications "${DMG_TMP_DIR}/Applications"

echo "==> Creating DMG image: ${DMG_PATH}..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_TMP_DIR}"

echo "==> Verifying DMG..."
hdiutil verify "${DMG_PATH}"

echo "==> Writing stable-named copy for permalinks..."
cp "${DMG_PATH}" "${DMG_STABLE_PATH}"

echo "=================================================="
echo " DMG created successfully:"
echo " ${DMG_PATH}"
echo " ${DMG_STABLE_PATH}"
echo " Version: ${VERSION}"
echo " Size: $(du -h "${DMG_PATH}" | awk '{print $1}')"
echo "=================================================="
