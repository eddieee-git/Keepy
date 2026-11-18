import Combine
import Foundation

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    @Published var selection = 0
    /// 값이 바뀌면 검색창에 다시 포커스를 줍니다.
    @Published private(set) var focusRequest = 0

    let store: HistoryStore
    private var cancellable: AnyCancellable?

    init(store: HistoryStore) {
        self.store = store
        cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// 고정 항목을 먼저, 나머지는 최근 사용 순
    var visibleItems: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? store.items : store.items.filter { $0.matches(q) }
        return base.filter(\.pinned) + base.filter { !$0.pinned }
    }

    var selectedItem: ClipItem? {
        let items = visibleItems
        return items.indices.contains(selection) ? items[selection] : nil
    }

    func prepareForShow() {
        query = ""
        selection = 0
        focusRequest += 1
    }

    func move(by delta: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        store.delete(item.id)
        selection = min(selection, max(visibleItems.count - 1, 0))
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        store.togglePin(item.id)
        if let index = visibleItems.firstIndex(where: { $0.id == item.id }) {
            selection = index
        }
    }
}
