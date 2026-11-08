#!/usr/bin/env bash
set -e

echo "🔨 Building Personal Task AI (Swift Release Build)..."
swift build -c release

APP_EXEC="PersonalTaskAI"
APP_NAME="Personal Task AI"
APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

echo "📦 Creating macOS .app Bundle: ${APP_DIR}..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp ".build/release/${APP_EXEC}" "${MACOS_DIR}/${APP_EXEC}"
chmod +x "${MACOS_DIR}/${APP_EXEC}"

cat << 'EOF' > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PersonalTaskAI</string>
    <key>CFBundleIdentifier</key>
    <string>com.personaltaskai.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Personal Task AI</string>
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

echo "✓ Personal Task AI.app พร้อมใช้งานแล้ว!"
echo "👉 คุณสามารถเปิดแอปได้ด้วยคำสั่ง: open \"Personal Task AI.app\""
