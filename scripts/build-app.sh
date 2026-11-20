#!/bin/zsh
# build/Keepy.app과 배포용 build/Keepy-<버전>.dmg를 만든다. Xcode 없이 Command Line Tools만으로 빌드한다.
# Apple 실리콘 Mac 전용이다.
set -e
cd "$(dirname "$0")/.."

# 점검용으로 `-showInDock` 인자를 쓰려면 KEEPY_DEBUG=1로 디버그 빌드를 만든다(dmg는 만들지 않음).
config=release
[[ -n "$KEEPY_DEBUG" ]] && config=debug
swift build -c $config --arch arm64

app=build/Keepy.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/arm64-apple-macosx/$config/Keepy "$app/Contents/MacOS/Keepy"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

# scripts/make-signing-cert.sh로 만든 인증서가 있으면 그것으로 서명한다.
# 없으면 임시 서명을 하되, 서명 조건을 번들 ID로 지정해서 다시 빌드해도 같은 앱으로 인식되게 한다(손쉬운 사용 권한 유지).
# 강화 런타임(--options runtime)을 켜서 다른 라이브러리를 끼워 넣지 못하게 한다.
identity="Keepy Local Signing"
if security find-identity -p codesigning 2>/dev/null | grep -q "$identity" \
   || security find-certificate -c "$identity" >/dev/null 2>&1; then
    codesign --force --sign "$identity" --options runtime "$app"
else
    codesign --force --sign - --options runtime -r='designated => identifier "com.eddieee.Keepy"' "$app"
fi

if [[ $config == debug ]]; then
    echo "$app (디버그)"
    exit 0
fi

# 내려받은 쪽에서 응용 프로그램 폴더로 끌어다 놓을 수 있게 바로가기를 함께 넣는다.
# dmg 이름에 Info.plist의 버전을 넣는다(예: build/Keepy-0.1.0.dmg).
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
dmg="build/Keepy-$version.dmg"
staging=build/dmg
rm -rf "$staging" "$dmg" "$dmg.sig"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname Keepy -srcfolder "$staging" -format UDZO "$dmg"
rm -rf "$staging"

# 앱 안 업데이트가 확인하는 Ed25519 서명. 릴리스에 dmg와 함께 .sig를 올린다.
# 키가 없으면 .sig를 만들지 않고, 그 릴리스는 앱 안에서 자동 설치되지 않는다.
if [[ -f "${KEEPY_UPDATE_KEY:-$HOME/.config/keepy/update-signing.key}" ]]; then
    swift scripts/sign-update.swift sign "$dmg" >/dev/null
fi

echo "$app"
echo "$dmg"
[[ -f "$dmg.sig" ]] && echo "$dmg.sig"
exit 0
