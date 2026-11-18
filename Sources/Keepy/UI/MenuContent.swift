import SwiftUI

struct MenuContent: View {
    @ObservedObject var store: HistoryStore
    @AppStorage(Prefs.Key.isPaused) private var isPaused = false
    @AppStorage(Prefs.Key.hotKey) private var hotKey = HotKeyPreset.shiftCmdV.rawValue

    var body: some View {
        Button("클립보드 기록 열기  \(HotKeyPreset(rawValue: hotKey)?.label ?? "")") {
            AppCore.shared.showPanel()
        }

        Divider()

        let recent = Array(store.items.prefix(10))
        if recent.isEmpty {
            Text("기록 없음")
        } else {
            Section("최근 항목") {
                ForEach(recent) { item in
                    Button(menuTitle(item)) {
                        AppCore.shared.paste(item, plainText: false)
                    }
                }
            }
        }

        Divider()

        Toggle("기록 일시 정지", isOn: $isPaused)
        Button("기록 지우기 (고정 항목 제외)") {
            store.clear(includingPinned: false)
        }

        Divider()

        SettingsLink {
            Text("설정…")
        }
        .keyboardShortcut(",")
        Button("Keepy 종료") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func menuTitle(_ item: ClipItem) -> String {
        let prefix = item.pinned ? "📌 " : ""
        let title = item.kind == .image ? "🖼 \(item.summary)" : item.title
        return prefix + (title.count > 45 ? String(title.prefix(45)) + "…" : title)
    }
}
