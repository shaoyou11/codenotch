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
xcodegen generate
xcodebuild -project Codenotch.xcodeproj -scheme Codenotch \
  -destination 'platform=macOS,arch=arm64' -configuration Release \
  -derivedDataPath build/CustomDerivedData \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Automatic build
mkdir -p build/custom
# ZIP preserves executable permissions and app bundle metadata for Downloads/Actions.
ditto -c -k --sequesterRsrc --keepParent \
  build/CustomDerivedData/Build/Products/Release/Codenotch.app \
  build/custom/Codenotch-50percent.zip
