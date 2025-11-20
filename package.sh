#!/bin/bash
APP_NAME="Ruan Cleaner"
EXECUTABLE_NAME="MacCleanerPro"
BUILD_PATH=".build/release/$EXECUTABLE_NAME"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="RuanCleanerInstaller.dmg"

echo "📦 Packaging $APP_NAME..."

# Create App Bundle Structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "⚠️ Warning: AppIcon.icns not found."
fi

# Create Info.plist
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App Bundle created: $APP_BUNDLE"

# Create DMG
echo "💿 Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"

echo "🎉 DMG created: $DMG_NAME"
