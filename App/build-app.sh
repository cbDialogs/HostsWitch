#!/bin/zsh
# Assembles HostsWitch.app from the release build.
set -e
cd "$(dirname "$0")"

swift build -c release

APP="../HostsWitch.app"
BIN=".build/release/HostsWitch"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts"

cp "$BIN" "$APP/Contents/MacOS/HostsWitch"
cp Fonts/*.ttf Fonts/OFL-*.txt "$APP/Contents/Resources/Fonts/"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>HostsWitch</string>
    <key>CFBundleDisplayName</key><string>HostsWitch</string>
    <key>CFBundleIdentifier</key><string>com.clearskycb.HostsWitch</string>
    <key>CFBundleExecutable</key><string>HostsWitch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key><string>HostsWitch runs a privileged copy to write /etc/hosts.</string>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "built: $APP"
