> 문서·UI 규칙은 ../mac-app/STYLE.md를 따른다. 다르게 할 때는 여기에 이유를 적는다.

> 업데이트 코드(`AppUpdater.swift`)와 정보 칸(`AppAbout.swift`)은 여러 앱 공통이다. 여기서 고치지 않고 ../mac-app/shared/를 고친 뒤 ../mac-app/scripts/sync-shared.sh로 복사한다. 이 앱에만 해당하는 값은 `UpdaterSetup.swift`에 있다.

# Keepy 개발 메모

macOS 메뉴바 클립보드 기록 앱. Swift Package 실행 파일 하나로, Xcode 없이 Command Line Tools만으로 빌드한다.
Apple 실리콘, macOS 14 이상. 저장소: `eddieee-git/mac-app-keepy` (공개).

## 지켜야 할 것

- **Apple 계정이 필요한 기능은 만들지 않는다.** iCloud 동기화, 공증, Developer ID 서명 등. 그래서 앱은 임시(ad-hoc) 서명이고, dmg로 처음 열면 Gatekeeper 경고가 뜬다.
- **복사한 내용을 밖으로 보내지 않는다.** 네트워크는 공통 업데이트 확인뿐이다.
- **비밀번호를 기록하지 않는다.** `PasteboardReader.ignoredTypes`(nspasteboard.org 관례)와 기본 제외 앱 목록을 줄이지 않는다.
- **스크린샷에 개인 내용이 나오지 않게 한다.** 실제 기록이 아니라 데모 내용으로 찍는다.
- **다른 클립보드 앱의 이름이나 그 앱을 분석한 내용을 공개 문서·커밋 메시지에 쓰지 않는다.** (코드 안의 단축키 겹침 경고용 번들 ID 목록은 예외)
- 사용자 문구는 한국어로 쓰고 영어 번역을 함께 넣는다. 말투는 "~해요".
- `main`에 바로 커밋하지 않고 작업 브랜치에서 한 뒤 합친다. GitHub에 올리기와 릴리스는 사용자에게 먼저 묻는다.

## 명령

```bash
./scripts/test.sh                       # 번역 빠짐 확인 + 빌드 + 자체 점검(--self-test). 실제 기록·설정·클립보드는 건드리지 않음
./scripts/build-app.sh                  # build/Keepy.app + build/Keepy-<버전>.dmg (+ .sig) (릴리스 빌드)
KEEPY_DEBUG=1 ./scripts/build-app.sh    # 디버그 빌드, dmg 없음. -showInDock YES 인자가 동작함
./scripts/release.sh                    # 점검 → 빌드 → 태그 push → gh release create (dmg, .sig 첨부)
./scripts/make-signing-cert.sh          # (선택) 이 Mac 전용 서명 인증서
swift scripts/sign-update.swift public  # 업데이트 서명 키의 공개 키 출력 (keygen | public | sign 파일)
swift scripts/make-icon.swift           # Resources/AppIcon.icns, docs/images/icon.png 다시 그리기
```

## 릴리스 순서

1. `Resources/Info.plist`의 `CFBundleShortVersionString`(그리고 `CFBundleVersion` +1)을 올린다.
2. `docs/releases/v<버전>.md`에 릴리스 노트를 쓴다(../mac-app/templates/release-note.md).
3. README 두 개와 변경 기록 두 개(`CHANGELOG.md`, `CHANGELOG.en.md`, "릴리스 전"을 날짜로)를 함께 고친다.
4. 커밋하고 `main`을 push한 뒤 `./scripts/release.sh`.
5. 확인: `gh api repos/eddieee-git/mac-app-keepy/releases/latest --jq '.tag_name, .assets[].digest'`의 digest가 `shasum -a 256 build/Keepy-<버전>.dmg`와 같은지.

**업데이트 서명 키**
- 비밀 키는 저장소 밖 `~/.config/keepy/update-signing.key`(`KEEPY_UPDATE_KEY`로 바꿀 수 있음)에 있다. 공개 키는 `UpdaterSetup.swift`의 `appPublicKey`. **읽어서 출력하거나 커밋하지 않는다.**
- `build-app.sh`가 키가 있으면 `.sig`를 만들고, `release.sh`는 `.sig`가 없으면 멈춘다.
- **키를 잃어버리면 이미 설치된 앱은 새 버전을 자동으로 받지 못한다.** 따로 백업해 둔다.

## 구조 (Sources/Keepy)

| 파일 | 하는 일 |
|---|---|
| `main.swift` | 시작점. `--self-test`면 점검만 돌리고 끝냄. 하나만 실행 |
| `AppDelegate.swift` | 메뉴바 아이콘과 메뉴, 앱 메뉴(편집·창 닫기), 단축키 등록, 붙여 넣기(`paste`), `keepy://show` |
| `AppSettings.swift` | 설정(UserDefaults). 단축키를 끄면 빈 값을 저장해 "기본값"과 구분 |
| `ClipboardMonitor.swift` | 0.4초마다 `changeCount` 확인. 일시 정지·제외 앱 거름 |
| `PasteboardReader.swift` | 클립보드 읽기(파일 > 텍스트+RTF > 이미지), 숨김 표시 거름, SHA-256 |
| `HistoryStore.swift` | 기록 목록, `~/Library/Application Support/Keepy/history.json` + `blobs/`, 한도, 삭제 되돌리기 |
| `Paster.swift` | 클립보드에 다시 쓰기, ⌘V 보내기(손쉬운 사용 권한) |
| `PanelController.swift` / `PanelViewModel.swift` / `HistoryView.swift` | 포커스를 빼앗지 않는 기록 창(`.nonactivatingPanel`)과 키 처리 |
| `HotKey.swift` | `KeyCombo`(기본 ⌃⌥V), Carbon 전역 단축키, 겹칠 수 있는 앱 목록 |
| `SettingsWindow.swift` | 설정 창: 일반 · 제외 앱 · 단축키 · 정보 |
| `WelcomeWindow.swift` | 시작 안내(권한, 단축키, 쓰는 방법). esc로 닫히는 창 `EscClosableWindow` |
| `Localization.swift` | `L()`과 영어 사전 |
| `AppUpdater.swift`·`AppAbout.swift`(공통) / `UpdaterSetup.swift` | 업데이트, 정보 칸 / Keepy 값 |
| `SelfTest.swift` | 자체 점검 |

## 규칙과 함정

- **번역**: 한국어 문구를 키로 `L("…")`을 쓰고 `Localization.swift`의 `pairs`에 영어를 더한다. `test.sh`가 빠진 번역을 찾아 실패하고, 같은 키가 두 번 들어가면 자체 점검이 실패한다. 안 쓰게 된 문구는 사전에서도 지운다.
- **기록 창**은 포커스를 빼앗지 않는 `NSPanel`이라, 닫은 뒤 보낸 ⌘V가 원래 앱으로 들어간다. 패널을 활성 앱으로 바꾸지 않는다.
- **Keepy가 쓴 클립보드 변경**은 `monitor.syncChangeCount()`로 건너뛴다. 빠뜨리면 붙여 넣을 때마다 같은 항목이 다시 기록된다.
- **손쉬운 사용 권한**은 서명을 따른다. 인증서가 없으면 `build-app.sh`가 번들 ID로 서명 조건을 정해서 다시 빌드해도 권한이 유지된다.
- **점검(self-test)** 은 임시 폴더, 이름 없는 임시 클립보드, 임시 UserDefaults를 쓴다. 새 기능에는 `SelfTest.swift`에 묶음을 더한다.
- 점검용 앱을 실행하면 실제 앱과 같은 UserDefaults와 기록 폴더를 쓴다. 실제 기록이 들어 있으니 지우지 않는다.
