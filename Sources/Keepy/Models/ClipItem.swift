import Foundation

struct ClipItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case text, image, file
    }

    let id: UUID
    let kind: Kind
    /// 일반 텍스트. 파일이면 경로 목록, 이미지면 빈 문자열.
    var text: String
    var rtfFile: String?
    var imageFile: String?
    var filePaths: [String]
    /// 이미지 크기 등 부가 정보
    var detail: String?
    var sourceBundleID: String?
    var sourceAppName: String?
    let createdAt: Date
    var lastUsedAt: Date
    var pinned: Bool
    let contentHash: String

    var title: String {
        switch kind {
        case .text:
            let line = text.split(whereSeparator: \.isNewline)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? text
            return String(line.prefix(300))
        case .image:
            return "이미지"
        case .file:
            let names = filePaths.map { ($0 as NSString).lastPathComponent }
            return names.joined(separator: ", ")
        }
    }

    var summary: String {
        switch kind {
        case .text:
            let lines = text.split(whereSeparator: \.isNewline).count
            return lines > 1 ? "\(text.count)자 · \(lines)줄" : "\(text.count)자"
        case .image:
            return detail ?? "이미지"
        case .file:
            return filePaths.count > 1 ? "파일 \(filePaths.count)개" : "파일"
        }
    }

    var tooltip: String {
        switch kind {
        case .text: String(text.prefix(1500))
        case .image: detail ?? "이미지"
        case .file: filePaths.joined(separator: "\n")
        }
    }

    func matches(_ query: String) -> Bool {
        if text.localizedCaseInsensitiveContains(query) { return true }
        if let app = sourceAppName, app.localizedCaseInsensitiveContains(query) { return true }
        if kind == .image, "이미지 image".localizedCaseInsensitiveContains(query) { return true }
        return false
    }
}
