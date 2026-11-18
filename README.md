# Keepy

macOS 메뉴 막대용 클립보드 관리자. Maccy, Paste, Clipy, Raycast 클립보드 기록에 공통으로 있는 기능을 기준으로 만들었습니다.

## 기능

- **기록**: 텍스트(서식 RTF 포함), 이미지, Finder 파일 복사를 기록합니다. 같은 내용을 다시 복사하면 맨 위로 올라갑니다.
- **패널**: `⇧⌘V`(설정에서 변경)로 마우스 위치나 화면 가운데에 띄웁니다. 앞에 있던 앱의 포커스를 뺏지 않습니다.
  - 입력하면 바로 검색 · `↑↓` 이동 · `↩` 붙여넣기 · `⌥↩` 서식 없이 · `⌘1–9` 바로 선택
  - `⌘P` 고정 · `⌘⌫` 삭제 · `esc` 검색어 지우기/닫기 · 오른쪽 클릭 메뉴
- **고정 항목**: 목록 위에 표시되고 개수 제한과 일괄 삭제에서 빠집니다.
- **개인정보**: `org.nspasteboard.ConcealedType` 같은 비밀번호 관리자 표시가 붙은 복사는 기록하지 않고, 제외할 앱(키체인, 1Password, Bitwarden, 암호 앱 기본 포함)을 설정할 수 있습니다. 메뉴 막대에서 기록을 일시 정지할 수 있습니다.
- **메뉴 막대**: 최근 10개 항목, 일시 정지, 기록 지우기, 설정.
- **설정**: 단축키, 창 위치, 바로 붙여넣기, 보관 개수(50–1000), 로그인 시 실행, 제외 앱.
- **URL 스킴**: `open keepy://show`로 패널을 엽니다(단축어, Raycast 등에서 사용).

데이터는 `~/Library/Application Support/Keepy/`(`history.json` + `blobs/`)에 저장됩니다.

## 빌드

Xcode 없이 Command Line Tools만으로 빌드됩니다 (macOS 14 이상).

```bash
./scripts/build-app.sh
cp -R build/Keepy.app ~/Applications/
open ~/Applications/Keepy.app
```

선택한 항목을 바로 붙여넣으려면(⌘V 입력을 보내려면) **시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용**에서 Keepy를 허용해야 합니다. 이 권한은 코드 서명 기준으로 유지됩니다. 빌드 스크립트는 키체인에 있는 코드 서명 인증서를 자동으로 사용하고, 인증서가 없으면 ad-hoc 서명을 합니다. ad-hoc 서명이면 다시 빌드할 때마다 권한을 다시 허용해야 합니다.

## 구조

```
Sources/Keepy/
  App/       KeepyApp(메뉴 막대·설정 씬), AppCore(전체 연결), Prefs(설정 키·기본값)
  Models/    ClipItem
  Services/  ClipboardMonitor(changeCount 폴링), PasteboardReader, HistoryStore(저장),
             Paster(클립보드 쓰기·⌘V 입력), HotKey(Carbon 전역 단축키), IconCache
  UI/        PanelController(NSPanel·키 처리), PanelViewModel, HistoryView, MenuContent, SettingsView
```
