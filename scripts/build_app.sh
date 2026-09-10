#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Building LocalFlow in release mode..."
cd "${ROOT_DIR}"
swift build -c release

APP_NAME="LocalFlow"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Packaging into ${APP_NAME}.app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${ROOT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/"

# Copy Info.plist
cp "${ROOT_DIR}/Config/Info.plist" "${CONTENTS_DIR}/"

# Generate minimalist native app icon if iconutil is available
ICONSET_DIR="/tmp/${APP_NAME}.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

# Create 512x512 PNG using Swift / CoreGraphics
cat << 'EOF' > /tmp/generate_icon.swift
import AppKit

let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)
image.lockFocus()

// Black rounded background
let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 16, dy: 16), xRadius: 100, yRadius: 100)
NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).setFill()
path.fill()

// Draw subtle border
NSColor(white: 1.0, alpha: 0.15).setStroke()
path.lineWidth = 4
path.stroke()

// Draw stylized waveform / mic bars
let barCount = 7
let barWidth: CGFloat = 20
let spacing: CGFloat = 16
let heights: [CGFloat] = [70, 140, 220, 280, 210, 130, 60]
let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
let startX = (size.width - totalWidth) / 2
let centerY = size.height / 2

for i in 0..<barCount {
    let h = heights[i]
    let x = startX + CGFloat(i) * (barWidth + spacing)
    let y = centerY - h / 2
    let barRect = NSRect(x: x, y: y, width: barWidth, height: h)
    let barPath = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
    NSColor(white: 0.95, alpha: 1.0).setFill()
    barPath.fill()
}

image.unlockFocus()

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "/tmp/LocalFlow_512.png"))
}
EOF

swift /tmp/generate_icon.swift 2>/dev/null || true

if [ -f "/tmp/LocalFlow_512.png" ]; then
    sips -z 16 16     /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null 2>&1 || true
    sips -z 32 32     /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null 2>&1 || true
    sips -z 32 32     /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null 2>&1 || true
    sips -z 64 64     /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null 2>&1 || true
    sips -z 128 128   /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null 2>&1 || true
    sips -z 256 256   /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null 2>&1 || true
    sips -z 256 256   /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null 2>&1 || true
    sips -z 512 512   /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null 2>&1 || true
    sips -z 512 512   /tmp/LocalFlow_512.png --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null 2>&1 || true
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns" > /dev/null 2>&1 || true
    rm -rf "${ICONSET_DIR}" /tmp/LocalFlow_512.png /tmp/generate_icon.swift
fi

echo "==> Resolving code signing identity..."

# Distribution outside the App Store requires a "Developer ID Application"
# certificate. "Apple Development" is for your own machines and "Apple
# Distribution" is for App Store submission — neither lets someone else open
# the app without Gatekeeper getting in the way.
find_identity() {
    security find-identity -p codesigning -v 2>/dev/null \
        | grep "$1" | head -n 1 | sed -n 's/.*"\(.*\)".*/\1/p'
}

SIGNING_IDENTITY="$(find_identity "Developer ID Application")"
IDENTITY_KIND="developer-id"

if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY="$(find_identity "Apple Development")"
    IDENTITY_KIND="development"
fi

if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY="-"
    IDENTITY_KIND="ad-hoc"
fi

echo "==> Signing with: ${SIGNING_IDENTITY}"

# The hardened runtime is mandatory for notarization, and harmless without it.
# --deep is deliberately not used: Apple discourages it, and this bundle has no
# nested code to descend into anyway.
CODESIGN_FLAGS=(--force --options runtime --entitlements "${ROOT_DIR}/Config/LocalFlow.entitlements")
if [ "${IDENTITY_KIND}" != "ad-hoc" ]; then
    # A secure timestamp is required for notarization and keeps the signature
    # valid after the certificate eventually expires.
    CODESIGN_FLAGS+=(--timestamp)
fi

codesign "${CODESIGN_FLAGS[@]}" --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"

echo "==> Verifying signature..."
codesign --verify --strict --verbose=2 "${APP_BUNDLE}" 2>&1 | sed 's/^/    /'

SIGN_INFO="$(codesign -d -vv "${APP_BUNDLE}" 2>&1 || true)"
if [[ "${SIGN_INFO}" == *"flags="*"runtime"* ]]; then
    echo "    hardened runtime: enabled"
else
    echo "    hardened runtime: MISSING — notarization will be rejected"
fi

echo ""
echo "=================================================="
echo " BUILD SUCCESSFUL"
echo " ${APP_BUNDLE}"
echo "=================================================="

case "${IDENTITY_KIND}" in
    developer-id)
        echo " Signed for distribution. Notarize before shipping:"
        echo "   ./scripts/notarize.sh"
        ;;
    development)
        cat <<'WARNING'

 WARNING — this build is signed with an Apple Development certificate.

 That certificate is for running the app on your own machines. On someone
 else's Mac, Gatekeeper will refuse it, and "right-click, Open" is not a
 reliable way around that. Do not publish this build.

 You already have a paid Apple Developer Program membership, so creating the
 right certificate costs nothing:

   Xcode -> Settings -> Accounts -> your team -> Manage Certificates
   -> + -> Developer ID Application

 Then run this script again and notarize with ./scripts/notarize.sh
WARNING
        ;;
    ad-hoc)
        cat <<'WARNING'

 WARNING — ad-hoc signed. Fine for local work, unusable for distribution.
 macOS will report the app as damaged on any other machine.
WARNING
        ;;
esac
