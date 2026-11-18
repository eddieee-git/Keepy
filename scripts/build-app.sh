#!/bin/bash
# Keepy.app 번들을 build/ 아래에 만듭니다.
#   ./scripts/build-app.sh            # release 빌드
#   ./scripts/build-app.sh debug      # debug 빌드
#   KEEPY_SIGN_IDENTITY="-" ./scripts/build-app.sh   # ad-hoc 서명 강제
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Keepy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Keepy" "$APP/Contents/MacOS/Keepy"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 손쉬운 사용 권한은 서명 기준으로 유지됩니다. ad-hoc 서명은 빌드할 때마다
# 권한이 풀리므로, 키체인에 코드 서명 인증서가 있으면 그것을 씁니다.
SIGN_ID="${KEEPY_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/\)/ {print $2; exit}')"
fi
SIGN_ID="${SIGN_ID:--}"
codesign --force --deep --sign "$SIGN_ID" "$APP"
echo "Built $APP (signed with: $SIGN_ID)"
