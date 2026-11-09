import SwiftUI

final class Prefs: ObservableObject {

    static let shared = Prefs()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let dark  = "fc_dark"          // Android: KEY_DARK
        static let skin  = "fc_skin"          // Android: KEY_UI_STYLE
        static let order = "fc_order"         // Android: KEY_ORDER_CODE
    }

    // 默认跟随 App 自身主题，不跟随系统 —— 原文案「跟随你的选择，不跟随系统」
    @Published var darkMode: Bool {
        didSet { defaults.set(darkMode, forKey: Key.dark) }
    }

    @Published var skin: SkinStyle {
        didSet { defaults.set(skin.rawValue, forKey: Key.skin) }
    }

    // 入口顺序，存 key 数组。校验不通过就回默认，避免版本升级后丢入口
    @Published var order: [String] {
        didSet { defaults.set(order, forKey: Key.order) }
    }

    private init() {
        darkMode = defaults.bool(forKey: Key.dark)
        skin = SkinStyle(rawValue: defaults.string(forKey: Key.skin) ?? "") ?? .paper

        let saved = defaults.stringArray(forKey: Key.order) ?? []
        if saved.count == EntryCatalog.defaultOrder.count,
           Set(saved) == Set(EntryCatalog.defaultOrder) {
            order = saved
        } else {
            order = EntryCatalog.defaultOrder
        }
    }

    var theme: Theme { Theme.resolve(skin: skin, dark: darkMode) }

    func entries(in group: EntryGroup) -> [JumpEntry] {
        order
            .compactMap { EntryCatalog.entry(forKey: $0) }
            .filter { $0.group == group }
    }

    // 只重排某一组内部的顺序，其他组的槽位不动
    func move(from source: IndexSet, to destination: Int, in group: EntryGroup) {
        var groupKeys = entries(in: group).map(\.key)
        groupKeys.move(fromOffsets: source, toOffset: destination)

        let slots = order.enumerated()
            .filter { EntryCatalog.entry(forKey: $0.element)?.group == group }
            .map(\.offset)

        guard slots.count == groupKeys.count else { return }
        for (i, key) in groupKeys.enumerated() {
            order[slots[i]] = key
        }
    }

    func resetOrder() {
        order = EntryCatalog.defaultOrder
    }
}
