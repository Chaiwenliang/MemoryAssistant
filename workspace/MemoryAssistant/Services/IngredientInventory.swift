import Foundation

enum FreshnessLevel: Comparable {
    case fresh
    case useSoon
    case caution

    var label: String {
        switch self {
        case .fresh: return "较新鲜"
        case .useSoon: return "建议尽快用"
        case .caution: return "优先处理"
        }
    }
}

struct IngredientItem: Identifiable {
    let id: UUID
    let name: String
    let place: String
    let daysStored: Int
    let freshness: FreshnessLevel
    let record: MemoryRecord

    var storedDescription: String {
        if daysStored <= 0 { return "今天记的" }
        if daysStored == 1 { return "昨天记的" }
        return "已记录 \(daysStored) 天"
    }
}

enum IngredientInventory {
    /// 从记录中提取冰箱/厨房相关食材，用录入时间近似购买/存入时间。
    static func fromRecords(_ records: [MemoryRecord], now: Date = Date(), calendar: Calendar = .current) -> [IngredientItem] {
        let expanded = CompoundIngredientExpander.expandRecords(records)
        return expanded.compactMap { record in
            guard let place = place(for: record) else { return nil }
            guard isFoodStoragePlace(place) else { return nil }

            let name = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 12 else { return nil }

            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: record.createdAt), to: calendar.startOfDay(for: now)).day ?? 0
            let freshness = evaluateFreshness(name: name, daysStored: max(days, 0))

            return IngredientItem(
                id: record.id,
                name: name,
                place: place,
                daysStored: max(days, 0),
                freshness: freshness,
                record: record
            )
        }
        .sorted {
            if $0.freshness == $1.freshness {
                return $0.daysStored > $1.daysStored
            }
            return $0.freshness > $1.freshness
        }
    }

    static func inPlace(_ placeKeyword: String, from records: [MemoryRecord]) -> [IngredientItem] {
        fromRecords(records).filter {
            $0.place.localizedCaseInsensitiveContains(placeKeyword)
                || placeKeyword.localizedCaseInsensitiveContains($0.place)
        }
    }

    // MARK: - Private

    private static func place(for record: MemoryRecord) -> String? {
        if let place = record.placeDescription, !place.isEmpty { return place }
        let text = record.details + record.title
        if text.contains("冰箱") { return "冰箱" }
        if text.contains("厨房") { return "厨房" }
        return nil
    }

    private static func isFoodStoragePlace(_ place: String) -> Bool {
        ["冰箱", "冷冻", "冷藏", "厨房", "阳台"].contains { place.contains($0) }
    }

    private static func evaluateFreshness(name: String, daysStored: Int) -> FreshnessLevel {
        let shelfLife = shelfLifeDays(for: name)
        if daysStored <= shelfLife.fresh { return .fresh }
        if daysStored <= shelfLife.useSoon { return .useSoon }
        return .caution
    }

    private static func shelfLifeDays(for name: String) -> (fresh: Int, useSoon: Int) {
        if matches(name, keywords: ["鱼", "虾", "蟹", "海鲜", "贝"]) {
            return (0, 1)
        }
        if matches(name, keywords: ["肉", "排骨", "鸡", "鸭", "牛羊"]) {
            return (1, 2)
        }
        if matches(name, keywords: ["豆腐", "牛奶", "酸奶"]) {
            return (1, 3)
        }
        if matches(name, keywords: ["菜", "菠菜", "生菜", "番茄", "黄瓜", "青椒", "蘑菇"]) {
            return (2, 5)
        }
        if matches(name, keywords: ["葱", "姜", "蒜", "洋葱"]) {
            return (7, 14)
        }
        if matches(name, keywords: ["西瓜", "苹果", "梨", "橙", "葡萄", "香蕉", "水果"]) {
            return (3, 7)
        }
        return (2, 5)
    }

    private static func matches(_ name: String, keywords: [String]) -> Bool {
        keywords.contains { name.localizedCaseInsensitiveContains($0) }
    }
}
