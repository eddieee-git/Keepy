import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = AppSettings.shared
    let store = HistoryStore()
    private var statusItem: NSStatusItem!
    private lazy var monitor = ClipboardMonitor(settings: settings) { [weak self] content, app in
        self?.store.add(content, source: app)
    }
    private lazy var panel = PanelController(store: store) { [weak self] item, plainText in
        self?.paste(item, plainText: plainText)
    }
    private let settingsWindow = SettingsWindowController()
    private let welcomeWindow = WelcomeWindowController()
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon()

        settings.$isPaused
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateStatusIcon() } }
            .store(in: &cancellables)
        // @Published는 값이 저장되기 전에 알리므로, 다음 차례에 다시 등록한다.
        settings.$hotKey
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyHotKey() } }
            .store(in: &cancellables)
        settings.$historyLimit
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.store.trim() } }
            .store(in: &cancellables)

        monitor.start()
        applyHotKey()
        AppUpdater.shared.start()

        // 처음 켤 때는 시작 안내를 띄운다.
        // 그다음부터 직접 켜면(응용 프로그램 폴더, Spotlight) 기록 창을 바로 보여 준다. 고르면 복사만 하므로 권한이 없어도 된다.
        // 로그인할 때 저절로 켜졌으면 창 없이 지내다가, 바로 붙여 넣기에 필요한 권한이 없을 때만 시작 안내를 띄운다.
        let needsPermission = settings.pasteAutomatically && !Paster.isTrusted
        if !settings.hasLaunchedBefore {
            settings.hasLaunchedBefore = true
            showWelcome()
        } else if !launchedAsLoginItem {
            showPanel(copyOnly: true)
        } else if needsPermission && settings.showWelcome {
            showWelcome()
        }
    }

    /// 로그인할 때 저절로 켜진 경우에는 창을 띄우지 않는다.
    private var launchedAsLoginItem: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// 이미 켜져 있는 Keepy를 다시 열면 기록 창을 띄운다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showPanel(copyOnly: true) }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.commitDeletion()
        store.saveNow()
    }

    /// keepy://show — 다른 도구(단축어 등)에서 기록 창을 연다.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "keepy" && (url.host == nil || url.host == "show") {
            showPanel()
        }
    }

    // MARK: 동작

    /// copyOnly: 앱 아이콘으로 열었을 때. 붙여 넣을 앞 앱이 없으니 고른 항목을 클립보드에 올리기만 한다.
    func showPanel(copyOnly: Bool = false) {
        // 메뉴가 닫힌 뒤에 패널이 키 윈도우가 되도록 한 박자 늦춘다.
        DispatchQueue.main.async { self.panel.show(copyOnly: copyOnly) }
    }

    @objc func openSettings() { showSettings() }
    func showSettings() { settingsWindow.show(store: store) }
    @objc func showWelcome() { welcomeWindow.show() }
    @objc func relaunch() { AppRelauncher.relaunch() }

    /// 항목을 클립보드에 올리고, 설정에 따라 앞에 있던 앱에 ⌘V를 보낸다.
    func paste(_ item: ClipItem, plainText: Bool) {
        let copyOnly = panel.isVisible && panel.viewModel.copyOnly
        panel.hide()
        Paster.write(item, store: store, plainText: plainText)
        monitor.syncChangeCount()
        store.markUsed(item.id)

        if copyOnly {
            // Keepy를 숨겨서 앞에 쓰던 앱으로 돌아가게 한다. 거기서 ⌘V로 붙여 넣으면 된다.
            NSApp.hide(nil)
            return
        }
        guard settings.pasteAutomatically else { return }
        if Paster.isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.sendPasteKeystroke() }
        } else {
            // 권한이 없으면 복사만 하고, 권한을 켜는 방법을 알려 준다.
            showWelcome()
        }
    }

    private func applyHotKey() {
        hotKey = nil
        settings.hotKeyFailed = false
        guard let combo = settings.hotKey else { return }
        hotKey = HotKey(id: 1, combo: combo) { [weak self] in
            DispatchQueue.main.async { self?.panel.toggle() }
        }
        settings.hotKeyFailed = hotKey == nil
    }

    private func updateStatusIcon() {
        let name = settings.isPaused ? "pause.circle" : "doc.on.clipboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Keepy")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = settings.isPaused ? L("Keepy · 기록 일시 정지 중") : "Keepy"
    }

    // MARK: 메뉴바 메뉴

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = menu.addItem(withTitle: L("클립보드 기록 열기"), action: #selector(menuOpenPanel), keyEquivalent: "")
        open.target = self
        if let combo = settings.hotKey {
            open.keyEquivalent = combo.menuKey
            open.keyEquivalentModifierMask = combo.menuModifiers
        }
        menu.addItem(.separator())

        let recent = store.items.prefix(10)
        if recent.isEmpty {
            let empty = menu.addItem(withTitle: L("아직 복사한 항목이 없어요"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
        } else {
            menu.addItem(.sectionHeader(title: L("최근 항목")))
            for item in recent {
                let entry = menu.addItem(withTitle: menuTitle(item), action: #selector(menuPasteItem(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = item.id
                entry.toolTip = item.tooltip
                if item.pinned {
                    entry.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: L("고정"))
                }
            }
        }
        menu.addItem(.separator())

        let pause = menu.addItem(withTitle: L("기록 일시 정지"), action: #selector(menuTogglePause), keyEquivalent: "")
        pause.target = self
        pause.state = settings.isPaused ? .on : .off
        let clear = menu.addItem(withTitle: L("기록 지우기…"), action: #selector(menuClearHistory), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = store.items.contains { !$0.pinned }
        menu.addItem(.separator())

        menu.addItem(withTitle: L("설정…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(AppUpdater.shared.makeMenuItem())
        menu.addItem(withTitle: L("시작 안내"), action: #selector(showWelcome), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Keepy 종료"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func menuTitle(_ item: ClipItem) -> String {
        let title = item.kind == .image ? L("이미지 %@", item.summary) : item.title
        return title.count > 45 ? String(title.prefix(45)) + "…" : title
    }

    @objc private func menuOpenPanel() { showPanel() }

    @objc private func menuPasteItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        paste(item, plainText: false)
    }

    @objc private func menuTogglePause() { settings.isPaused.toggle() }

    @objc private func menuClearHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("기록을 지울까요?")
        alert.informativeText = L("고정한 항목은 남겨요. 지운 기록은 되돌릴 수 없어요.")
        alert.addButton(withTitle: L("지우기"))
        alert.addButton(withTitle: L("취소"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear(includingPinned: false)
        }
    }

    // MARK: 앱 메뉴 (설정 창에서 ⌘W, 복사·붙이기가 되도록)

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = main.addItem(withTitle: "Keepy", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Keepy")
        appMenu.addItem(withTitle: L("설정…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Keepy 종료"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = main.addItem(withTitle: L("편집"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: L("편집"))
        edit.addItem(withTitle: L("실행 취소"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: L("실행 복귀"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: L("오려두기"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("복사"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("붙이기"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("전체 선택"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let windowItem = main.addItem(withTitle: L("윈도우"), action: nil, keyEquivalent: "")
        let window = NSMenu(title: L("윈도우"))
        window.addItem(withTitle: L("창 닫기"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = window
        return main
    }
}
