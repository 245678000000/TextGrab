#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=build/TextGrab.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
swiftc -O -target arm64-apple-macos13.0 main.swift -o $APP/Contents/MacOS/TextGrab -framework Cocoa -framework Vision -framework Carbon
cp AppIcon.icns $APP/Contents/Resources/
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>TextGrab</string>
<key>CFBundleIdentifier</key><string>local.textgrab</string>
<key>CFBundleExecutable</key><string>TextGrab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PL
# 用固定证书签名可让“屏幕录制”授权在重新编译后保持有效：SIGN_ID=<证书SHA1> ./build.sh
codesign --force --deep -s "${SIGN_ID:--}" $APP
mkdir -p ~/Applications
rm -rf ~/Applications/TextGrab.app && cp -R $APP ~/Applications/
echo "Installed to ~/Applications/TextGrab.app"
