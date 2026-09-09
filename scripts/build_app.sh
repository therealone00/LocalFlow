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
SIGNING_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | sed -n 's/.*"\(.*\)".*/\1/p')

if [ -n "${SIGNING_IDENTITY}" ]; then
    echo "==> Using detected developer identity: ${SIGNING_IDENTITY}"
else
    echo "==> No Apple Development identity found, using ad-hoc signing (-)..."
    SIGNING_IDENTITY="-"
fi

echo "==> Signing application bundle..."
codesign --force --deep --sign "${SIGNING_IDENTITY}" --entitlements "${ROOT_DIR}/Config/LocalFlow.entitlements" "${APP_BUNDLE}"

echo ""
echo "=================================================="
echo " BUILD SUCCESSFUL!"
echo " App location: ${APP_BUNDLE}"
echo "=================================================="
