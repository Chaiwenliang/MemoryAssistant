import Foundation

/// 清单类提问：「家里有什么水果」「有哪些吃的」「有什么喝的」
enum MemoryInventoryAnswer {
    private static let fruitKeywords = [
        "西瓜", "苹果", "甜瓜", "香瓜", "哈密瓜", "香蕉", "葡萄", "草莓",
        "梨", "桃", "橙", "柚", "芒果", "樱桃", "蓝莓", "猕猴桃", "橘子",
        "桃子", "李子", "樱桃", "枣", "柠檬", "木瓜", "瓜"
    ]

    private static let vegetableKeywords = [
        "白菜", "青菜", "生菜", "菠菜", "油菜", "空心菜", "韭菜", "芹菜",
        "土豆", "番茄", "西红柿", "茄子", "辣椒", "青椒", "豆角", "四季豆",
        "黄瓜", "丝瓜", "苦瓜", "南瓜", "冬瓜", "玉米", "胡萝卜", "白萝卜",
        "萝卜", "洋葱", "西兰花", "花椰菜", "菜", "蔬菜"
    ]

    private static let drinkKeywords = [
        "水", "矿泉水", "可乐", "雪碧", "果汁", "牛奶", "酸奶", "豆浆",
        "茶", "红茶", "绿茶", "奶茶", "咖啡", "啤酒", "红酒", "白酒",
        "酒", "饮料", "椰子水", "椰子汁", "椰汁", "苏打水", "气泡水"
    ]

    private static let stapleKeywords = [
        "米", "饭", "面条", "面条", "面", "馒头", "包子", "饺子", "面包", "吐司",
        "年糕", "方便面", "挂面", "饼干"
    ]

    private static let proteinKeywords = [
        "鸡蛋", "鸡蛋", "鸡肉", "猪肉", "牛肉", "羊肉", "鱼", "虾", "蟹",
        "肉", "蛋", "火腿", "培根", "香肠", "腊肉", "培根", "鸡块", "排骨",
        "丸子", "豆腐", "豆干"
    ]

    private static let foodKeywords = fruitKeywords + vegetableKeywords + stapleKeywords + proteinKeywords + [
        "油", "盐", "糖", "酱", "醋", "酱油", "葱", "姜", "蒜", "辣椒", "花椒"
    ]

    private static let snackKeywords = [
        "饼干", "薯片", "巧克力", "糖", "蛋糕", "面包", "饼干", "坚果",
        "瓜子", "花生", "核桃", "杏仁", "零食", "冰淇淋", "雪糕"
    ]

    static func answer(question: String, in records: [MemoryRecord]) -> MemoryQueryResult? {
        let normalized = MemoryQueryRouter.normalize(question)
        guard isInventoryQuery(normalized) else { return nil }

        let subject = extractSubject(from: normalized)
        let matches = matchRecords(subject: subject, in: records.activeOnly)

        guard !matches.isEmpty else { return nil }

        let summary = matches
            .prefix(8)
            .map { item in
                if let place = item.placeDescription, !place.isEmpty {
                    return "\(item.title)（\(place)）"
                }
                return item.title
            }
            .joined(separator: "、")

        let scope = normalized.contains("家里") ? "家里" : "你的记录中"
        let subjectText = subject.map { "的\($0)" } ?? ""

        return MemoryQueryResult(
            found: true,
            answer: "根据你的记录，\(scope)\(subjectText)有：\(summary)。",
            records: Array(matches.prefix(8))
        )
    }

    // MARK: - Private

    private static func isInventoryQuery(_ question: String) -> Bool {
        question.contains("有什么") || question.contains("有哪些") || question.contains("有啥")
    }

    private static func extractSubject(from question: String) -> String? {
        var text = question
        let noise = [
            "家里", "家中", "屋内", "有什么", "有哪些", "有啥", "吗", "？", "?", "一下"
        ]
        for word in noise {
            text = text.replacingOccurrences(of: word, with: " ")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func matchRecords(subject: String?, in records: [MemoryRecord]) -> [MemoryRecord] {
        guard let subject, !subject.isEmpty else {
            return records.sorted { $0.updatedAt > $1.updatedAt }
        }

        let key = subject.lowercased()

        // 先判断是否是类别查询，再做标题匹配
        if isFruitQuery(key) {
            return records.filter { isFruit($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        }
        if isVegetableQuery(key) {
            return records.filter { isVegetable($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        }
        if isDrinkQuery(key) {
            return records.filter { isDrink($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        }
        if isFoodQuery(key) {
            return records.filter { isFood($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        }
        if isSnackQuery(key) {
            return records.filter { isSnack($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        }

        // 标题精确匹配
        return records.filter { record in
            let title = record.title.lowercased()
            if title.contains(key) || key.contains(title) { return true }
            return false
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 类别识别

    private static func isFruitQuery(_ key: String) -> Bool {
        key.contains("水果") || key.contains("果")
    }

    private static func isVegetableQuery(_ key: String) -> Bool {
        key.contains("蔬菜") || key.contains("菜") || key.contains("蔬")
    }

    private static func isDrinkQuery(_ key: String) -> Bool {
        key.contains("喝") || key.contains("饮料") || key.contains("饮品") || key.contains("酒") || key.contains("水")
    }

    private static func isFoodQuery(_ key: String) -> Bool {
        key.contains("食") || key == "吃的" || key.contains("吃什么")
    }

    private static func isSnackQuery(_ key: String) -> Bool {
        key.contains("零食") || key.contains("点心") || key.contains("甜点") || key.contains("甜品")
    }

    // MARK: - 标题判断

    private static func isFruit(_ name: String) -> Bool {
        fruitKeywords.contains { name.contains($0) }
    }

    private static func isVegetable(_ name: String) -> Bool {
        vegetableKeywords.contains { name.contains($0) }
    }

    private static func isDrink(_ name: String) -> Bool {
        drinkKeywords.contains { name.contains($0) }
    }

    private static func isFood(_ name: String) -> Bool {
        foodKeywords.contains { name.contains($0) }
    }

    private static func isSnack(_ name: String) -> Bool {
        snackKeywords.contains { name.contains($0) }
    }
}
