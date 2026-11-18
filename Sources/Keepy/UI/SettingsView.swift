import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let store: HistoryStore

    var body: some View {
        TabView {
            GeneralSettings(store: store)
                .tabItem { Label("일반", systemImage: "gearshape") }
            IgnoredAppsSettings()
                .tabItem { Label("제외 앱", systemImage: "hand.raised") }
        }
        .frame(width: 480)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

private struct GeneralSettings: View {
    let store: HistoryStore

    @AppStorage(Prefs.Key.hotKey) private var hotKey = HotKeyPreset.shiftCmdV.rawValue
    @AppStorage(Prefs.Key.panelPosition) private var panelPosition = PanelPosition.mouse.rawValue
    @AppStorage(Prefs.Key.pasteAutomatically) private var pasteAutomatically = true
    @AppStorage(Prefs.Key.historyLimit) private var historyLimit = Prefs.defaultHistoryLimit

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Paster.isTrusted(prompt: false)
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section {
                Picker("기록 열기 단축키", selection: $hotKey) {
                    ForEach(HotKeyPreset.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .onChange(of: hotKey) { AppCore.shared.applyHotKey() }

                Picker("창 위치", selection: $panelPosition) {
                    ForEach(PanelPosition.allCases) { Text($0.label).tag($0.rawValue) }
                }

                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section {
                Toggle("선택하면 바로 붙여넣기", isOn: $pasteAutomatically)
                if pasteAutomatically {
                    HStack {
                        Label(isTrusted ? "손쉬운 사용 권한 허용됨" : "손쉬운 사용 권한이 필요합니다",
                              systemImage: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(isTrusted ? .green : .orange)
                        Spacer()
                        if !isTrusted {
                            Button("시스템 설정 열기") { Paster.openAccessibilitySettings() }
                        }
                    }
                    .font(.callout)
                }
            } footer: {
                Text("끄면 항목을 클립보드에 복사만 하고, ⌘V는 직접 누릅니다.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("보관할 항목 수", selection: $historyLimit) {
                    ForEach([50, 100, 200, 500, 1000], id: \.self) { Text("\($0)개").tag($0) }
                }
                .onChange(of: historyLimit) { store.trim() }

                HStack {
                    Text("저장 위치")
                    Spacer()
                    Button("Finder에서 보기") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.directory])
                    }
                }

                Button("모든 기록 지우기 (고정 항목 포함)…", role: .destructive) {
                    confirmClear = true
                }
            } footer: {
                Text("고정한 항목은 개수 제한에 포함되지 않습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 470)
        .confirmationDialog("모든 클립보드 기록을 지울까요?", isPresented: $confirmClear) {
            Button("모두 지우기", role: .destructive) { store.clear(includingPinned: true) }
        } message: {
            Text("고정한 항목까지 모두 지워지며 되돌릴 수 없습니다.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isTrusted = Paster.isTrusted(prompt: false)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Keepy: 로그인 항목 설정 실패 \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct IgnoredAppsSettings: View {
    @AppStorage(Prefs.Key.ignoredApps) private var ignoredApps = Prefs.defaultIgnoredApps

    var body: some View {
        Form {
            Section {
                TextEditor(text: $ignoredApps)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 220)
            } header: {
                Text("이 앱에서 복사한 내용은 기록하지 않습니다 (번들 ID, 한 줄에 하나)")
            } footer: {
                Text("비밀번호 관리자가 숨김 표시(ConcealedType)로 복사한 내용은 앱과 관계없이 기록하지 않습니다.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Menu("실행 중인 앱에서 추가") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            add(app.bundleIdentifier)
                        }
                    }
                }
                Button("기본값으로 되돌리기") { ignoredApps = Prefs.defaultIgnoredApps }
            }
        }
        .formStyle(.grouped)
        .frame(height: 470)
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID, !Prefs.ignoredBundleIDs.contains(bundleID) else { return }
        let trimmed = ignoredApps.trimmingCharacters(in: .whitespacesAndNewlines)
        ignoredApps = trimmed.isEmpty ? bundleID : trimmed + "\n" + bundleID
    }
}
