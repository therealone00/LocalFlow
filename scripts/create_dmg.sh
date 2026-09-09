#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="LocalFlow"
VERSION="1.0.0"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DMG_TMP_DIR="/tmp/${APP_NAME}_dmg_staging"

echo "==> Preparing DMG staging area..."
rm -rf "${DMG_TMP_DIR}" "${DMG_PATH}"
mkdir -p "${DMG_TMP_DIR}"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Building app bundle first..."
    "${ROOT_DIR}/scripts/build_app.sh"
fi

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

echo "=================================================="
echo " DMG created successfully at:"
echo " ${DMG_PATH}"
echo " Size: $(du -h "${DMG_PATH}" | awk '{print $1}')"
echo "=================================================="
