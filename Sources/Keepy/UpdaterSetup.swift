import AppKit

/// 공통 업데이트(AppUpdater.swift)에 Keepy 정보를 넣는다. AppUpdater.swift는 mac-app/shared에서 복사해 오므로 여기만 고친다.
extension AppUpdater {
    /// `~/.config/keepy/update-signing.key`의 공개 키 (scripts/sign-update.swift)
    nonisolated static let appPublicKey = "htjSqoI8xC15sxuQQtv0ghT+pLhQ8oQCSr5oVV8RgMo="
    nonisolated static let appSignatureFormat = SignatureFormat.dmg

    static let shared = AppUpdater(.init(
        appName: "Keepy",
        repo: "eddieee-git/mac-app-keepy",
        publicKey: appPublicKey,
        signatureFormat: appSignatureFormat,
        isEnglish: { !Localization.isKorean },
        didUpdate: { _ in
            // 서명이 바뀐 새 버전을 macOS가 다른 앱으로 보면 손쉬운 사용 권한이 풀린다. 붙여 넣다가 알게 되지 않도록 바로 안내한다.
            if AppSettings.shared.pasteAutomatically && !Paster.isTrusted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    (NSApp.delegate as? AppDelegate)?.showWelcome()
                }
            }
        }
    ))
}
