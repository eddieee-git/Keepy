import Carbon.HIToolbox
import Foundation

enum Prefs {
    enum Key {
        static let historyLimit = "historyLimit"
        static let pasteAutomatically = "pasteAutomatically"
        static let hotKey = "hotKey"
        static let panelPosition = "panelPosition"
        static let ignoredApps = "ignoredApps"
        static let isPaused = "isPaused"
    }

    static let defaultHistoryLimit = 200

    /// 비밀번호 관리자 등 기록하지 않을 앱 (번들 ID, 줄바꿈 구분)
    static let defaultIgnoredApps = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
    ].joined(separator: "\n")

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.historyLimit: defaultHistoryLimit,
            Key.pasteAutomatically: true,
            Key.hotKey: HotKeyPreset.shiftCmdV.rawValue,
            Key.panelPosition: PanelPosition.mouse.rawValue,
            Key.ignoredApps: defaultIgnoredApps,
            Key.isPaused: false,
        ])
    }

    private static var defaults: UserDefaults { .standard }

    static var historyLimit: Int {
        let value = defaults.integer(forKey: Key.historyLimit)
        return value > 0 ? value : defaultHistoryLimit
    }

    static var pasteAutomatically: Bool { defaults.bool(forKey: Key.pasteAutomatically) }
    static var isPaused: Bool { defaults.bool(forKey: Key.isPaused) }

    static var hotKeyPreset: HotKeyPreset {
        HotKeyPreset(rawValue: defaults.string(forKey: Key.hotKey) ?? "") ?? .shiftCmdV
    }

    static var panelPosition: PanelPosition {
        PanelPosition(rawValue: defaults.string(forKey: Key.panelPosition) ?? "") ?? .mouse
    }

    static var ignoredBundleIDs: Set<String> {
        let raw = defaults.string(forKey: Key.ignoredApps) ?? defaultIgnoredApps
        return Set(
            raw.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case shiftCmdV, optionCmdV, ctrlCmdV, ctrlShiftV

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shiftCmdV: "⇧⌘V"
        case .optionCmdV: "⌥⌘V"
        case .ctrlCmdV: "⌃⌘V"
        case .ctrlShiftV: "⌃⇧V"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_ANSI_V) }

    var carbonModifiers: UInt32 {
        switch self {
        case .shiftCmdV: UInt32(shiftKey | cmdKey)
        case .optionCmdV: UInt32(optionKey | cmdKey)
        case .ctrlCmdV: UInt32(controlKey | cmdKey)
        case .ctrlShiftV: UInt32(controlKey | shiftKey)
        }
    }
}

enum PanelPosition: String, CaseIterable, Identifiable {
    case mouse, center

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mouse: "마우스 포인터 위치"
        case .center: "화면 가운데"
        }
    }
}
