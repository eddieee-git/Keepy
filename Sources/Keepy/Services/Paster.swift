import AppKit
import ApplicationServices

enum Paster {
    @MainActor
    static func write(_ item: ClipItem, store: HistoryStore, plainText: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text, forType: .string)
            if !plainText, let rtf = store.blobData(item.rtfFile) {
                pb.setData(rtf, forType: .rtf)
            }
        case .image:
            guard let png = store.blobData(item.imageFile) else { return }
            pb.setData(png, forType: .png)
            if let tiff = NSImage(data: png)?.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            if plainText {
                pb.setString(item.text, forType: .string)
            } else {
                pb.writeObjects(urls)
            }
        }
    }

    private static var didPrompt = false

    /// ⌘V 키 입력을 보내려면 손쉬운 사용 권한이 필요합니다.
    static func isTrusted(prompt: Bool) -> Bool {
        let shouldPrompt = prompt && !didPrompt
        if shouldPrompt { didPrompt = true }
        let options = ["AXTrustedCheckOptionPrompt": shouldPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
