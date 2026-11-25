#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Ruan Cleaner"
EXECUTABLE_NAME="MacCleanerPro"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="RuanCleanerInstaller.dmg"

echo "🔨 Building release..."
swift build -c release

echo "📦 Packaging $APP_NAME..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Executable
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Images used by the app (logo, background). The old script left these out,
# so the app only worked on the Mac it was built on.
cp Sources/MacCleanerPro/Assets/*.png "$APP_BUNDLE/Contents/Resources/"

# Icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "⚠️ Warning: AppIcon.icns not found."
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ruan.MacCleanerPro</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign so macOS keeps Full Disk Access and Downloads permissions between launches.
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || echo "⚠️ codesign skipped"

echo "✅ App Bundle created: $APP_BUNDLE"

echo "💿 Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"

echo "🎉 DMG created: $DMG_NAME"
