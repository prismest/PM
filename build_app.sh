#!/usr/bin/env bash
set -e

echo "Building Waan (Swift Release Build)..."
swift build -c release

APP_NAME="Waan"
APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

echo "Creating macOS .app Bundle: ${APP_DIR}..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cp "mcp_server.py" "${RESOURCES_DIR}/mcp_server.py"
chmod +x "${RESOURCES_DIR}/mcp_server.py"

cat << 'EOF' > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Waan</string>
    <key>CFBundleIdentifier</key>
    <string>com.waan.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Waan</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing macOS .app Bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "Waan.app is ready."
echo "You can launch the app with: open Waan.app"
