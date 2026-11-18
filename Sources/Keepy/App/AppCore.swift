import AppKit

/// 앱 전역 객체: 기록 저장소, 클립보드 감시, 패널, 단축키를 묶습니다.
@MainActor
final class AppCore {
    static let shared = AppCore()

    let store = HistoryStore()
    private(set) lazy var monitor = ClipboardMonitor { [weak self] content, app in
        self?.store.add(content, source: app)
    }
    private(set) lazy var panel = PanelController(store: store) { [weak self] item, plainText in
        self?.paste(item, plainText: plainText)
    }
    private var hotKey: HotKey?

    func start() {
        monitor.start()
        applyHotKey()
    }

    func applyHotKey() {
        hotKey = nil
        let preset = Prefs.hotKeyPreset
        hotKey = HotKey(keyCode: preset.keyCode, modifiers: preset.carbonModifiers) { [weak self] in
            self?.panel.toggle()
        }
    }

    func showPanel() {
        // 메뉴가 닫힌 뒤에 패널이 키 윈도우가 되도록 한 박자 늦춥니다.
        DispatchQueue.main.async { self.panel.show() }
    }

    /// 항목을 클립보드에 올리고, 설정에 따라 앞에 있던 앱에 ⌘V를 보냅니다.
    func paste(_ item: ClipItem, plainText: Bool) {
        panel.hide()
        Paster.write(item, store: store, plainText: plainText)
        monitor.syncChangeCount()
        store.markUsed(item.id)

        guard Prefs.pasteAutomatically else { return }
        if Paster.isTrusted(prompt: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                Paster.sendPasteKeystroke()
            }
        }
    }
}
