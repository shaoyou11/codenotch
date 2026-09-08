#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ]; then
  if [ -d /Applications/Xcode-beta.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  elif [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi
version=$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)
[[ "$version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || { echo "无法读取有效版本号"; exit 1; }
xcodegen generate
xcodebuild -project Codenotch.xcodeproj -scheme Codenotch \
  -destination 'platform=macOS,arch=arm64' -configuration Release \
  -derivedDataPath build/CustomDerivedData \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Automatic \
  ENABLE_HARDENED_RUNTIME=NO build
app=build/CustomDerivedData/Build/Products/Release/CodenotchT.app
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.shaoyou11.codenotcht ]
codesign --verify --deep --strict "$app"
mkdir -p build/custom
# ZIP preserves executable permissions and app bundle metadata for Downloads/Actions.
ditto -c -k --sequesterRsrc --keepParent \
  build/CustomDerivedData/Build/Products/Release/CodenotchT.app \
  "build/custom/CodenotchT-${version}.zip"
