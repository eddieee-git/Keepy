import AppKit

/// 기록 목록과 디스크 저장을 담당합니다.
/// ~/Library/Application Support/Keepy/history.json + blobs/(이미지·RTF)
@MainActor
final class HistoryStore: ObservableObject {
    /// 최근 사용 순 (0번이 가장 최근)
    @Published private(set) var items: [ClipItem] = []

    let directory: URL
    let blobDirectory: URL
    private let indexURL: URL
    private var pendingSave: DispatchWorkItem?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Keepy", isDirectory: true)
        blobDirectory = directory.appendingPathComponent("blobs", isDirectory: true)
        indexURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: blobDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - 변경

    func add(_ content: CapturedContent, source: NSRunningApplication?) {
        let now = Date()
        if let index = items.firstIndex(where: { $0.contentHash == content.hash }) {
            // 같은 내용을 다시 복사하면 맨 위로 올립니다.
            var existing = items.remove(at: index)
            existing.lastUsedAt = now
            items.insert(existing, at: 0)
            scheduleSave()
            return
        }

        let id = UUID()
        var item = ClipItem(
            id: id, kind: content.kind, text: content.text,
            rtfFile: nil, imageFile: nil, filePaths: content.filePaths,
            detail: content.detail,
            sourceBundleID: source?.bundleIdentifier, sourceAppName: source?.localizedName,
            createdAt: now, lastUsedAt: now, pinned: false, contentHash: content.hash
        )
        if let png = content.pngData {
            item.imageFile = writeBlob(png, name: "\(id.uuidString).png")
        }
        if let rtf = content.rtfData {
            item.rtfFile = writeBlob(rtf, name: "\(id.uuidString).rtf")
        }
        items.insert(item, at: 0)
        trim()
        scheduleSave()
    }

    func markUsed(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.lastUsedAt = Date()
        items.insert(item, at: 0)
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].pinned.toggle()
        trim()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        removeBlobs(of: items.remove(at: index))
        scheduleSave()
    }

    func clear(includingPinned: Bool) {
        let (removed, kept) = items.reduce(into: ([ClipItem](), [ClipItem]())) { result, item in
            if item.pinned && !includingPinned { result.1.append(item) } else { result.0.append(item) }
        }
        removed.forEach(removeBlobs)
        items = kept
        scheduleSave()
    }

    /// 고정되지 않은 항목이 한도를 넘으면 오래된 것부터 지웁니다.
    func trim() {
        let limit = Prefs.historyLimit
        var unpinned = 0
        var kept: [ClipItem] = []
        for item in items {
            if item.pinned { kept.append(item); continue }
            unpinned += 1
            if unpinned > limit { removeBlobs(of: item) } else { kept.append(item) }
        }
        if kept.count != items.count { items = kept }
    }

    // MARK: - Blob

    func blobURL(_ name: String) -> URL {
        blobDirectory.appendingPathComponent(name)
    }

    func blobData(_ name: String?) -> Data? {
        guard let name else { return nil }
        return try? Data(contentsOf: blobURL(name))
    }

    private func writeBlob(_ data: Data, name: String) -> String? {
        do {
            try data.write(to: blobURL(name), options: .atomic)
            return name
        } catch {
            NSLog("Keepy: blob 저장 실패 \(error)")
            return nil
        }
    }

    private func removeBlobs(of item: ClipItem) {
        for name in [item.imageFile, item.rtfFile].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: blobURL(name))
        }
    }

    // MARK: - 저장

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            items = try decoder.decode([ClipItem].self, from: data)
        } catch {
            NSLog("Keepy: 기록을 읽지 못했습니다 \(error)")
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            NSLog("Keepy: 기록 저장 실패 \(error)")
        }
    }
}
