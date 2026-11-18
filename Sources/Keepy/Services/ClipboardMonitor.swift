import AppKit

/// NSPasteboard에는 변경 알림이 없어서 changeCount를 주기적으로 확인합니다.
@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let onCapture: (CapturedContent, NSRunningApplication?) -> Void

    init(onCapture: @escaping (CapturedContent, NSRunningApplication?) -> Void) {
        self.onCapture = onCapture
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Keepy가 직접 클립보드에 쓴 변경은 새 항목으로 기록하지 않습니다.
    func syncChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        guard !Prefs.isPaused else { return }
        let app = NSWorkspace.shared.frontmostApplication
        if let id = app?.bundleIdentifier, Prefs.ignoredBundleIDs.contains(id) { return }
        guard let content = PasteboardReader.read(pasteboard) else { return }
        onCapture(content, app)
    }
}
