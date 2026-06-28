import Foundation

enum CookingAdvisor {
    static func advise(question: String, records: [MemoryRecord], now: Date = Date()) -> MemoryQueryResult {
        let inventory = IngredientInventory.fromRecords(records, now: now)

        guard !inventory.isEmpty else {
            return MemoryQueryResult(
                found: false,
                answer: "我还没有记录你冰箱或厨房里的食材。你可以先说「鱼放在冰箱冷藏里」「西瓜在冰箱里」之类，再问我要做饭。",
                records: []
            )
        }

        var sections: [String] = []

        let stockLine = inventory.map { item in
            "\(item.name)（\(item.storedDescription)，\(item.freshness.label)）"
        }.joined(separator: "；")
        sections.append("根据你的记录，目前食材有：\(stockLine)。")

        let priority = inventory.filter { $0.freshness >= .useSoon }
        if !priority.isEmpty {
            let names = priority.map(\.name).joined(separator: "、")
            sections.append("建议优先使用：\(names)。")
        }

        let suggestions = recipeSuggestions(from: inventory.map(\.name))
        if !suggestions.isEmpty {
            sections.append("可以参考：\(suggestions.joined(separator: "；"))。")
        }

        if question.contains("冰箱") {
            let fridgeItems = IngredientInventory.inPlace("冰箱", from: records)
            if !fridgeItems.isEmpty {
                let names = fridgeItems.map(\.name).joined(separator: "、")
                sections.append("冰箱里现在有：\(names)。")
            }
        }

        sections.append("新鲜度是按你录入时间估算的，仅供参考；海鲜和肉类建议闻气味、看色泽后再决定是否食用。")

        return MemoryQueryResult(
            found: true,
            answer: sections.joined(separator: ""),
            records: inventory.map(\.record)
        )
    }

    // MARK: - Private

    private static func recipeSuggestions(from ingredients: [String]) -> [String] {
        var results: [String] = []
        let set = Set(ingredients)

        let hasFish = containsAny(in: set, keywords: ["鱼"])
        let hasAromatics = containsAny(in: set, keywords: ["葱", "姜", "蒜"])
        let hasWatermelon = containsAny(in: set, keywords: ["西瓜"])
        let hasApple = containsAny(in: set, keywords: ["苹果"])
        let hasMeat = containsAny(in: set, keywords: ["肉", "排骨", "鸡", "鸭"])
        let hasEgg = containsAny(in: set, keywords: ["蛋", "鸡蛋"])

        if hasFish, hasAromatics {
            results.append("清蒸鱼或红烧鱼（你有鱼和葱姜蒜）")
        } else if hasFish {
            results.append("香煎鱼或酸菜鱼（优先把鱼吃掉）")
        }

        if hasMeat, hasAromatics {
            results.append("葱姜蒜炒肉")
        }

        if hasWatermelon {
            results.append("西瓜切块直接吃，或做简易西瓜沙拉")
        }

        if hasApple, hasAromatics {
            results.append("苹果可凉拌或做甜汤，葱姜蒜另配荤菜更合适")
        }

        if containsAny(in: set, keywords: ["鱼", "豆腐"]) {
            results.append("鱼头豆腐汤")
        }

        if hasEgg, hasAromatics {
            results.append("葱花炒蛋或西红柿炒蛋（如有番茄可搭配）")
        }

        if results.isEmpty, ingredients.count >= 2 {
            results.append("把 \(ingredients.prefix(3).joined(separator: "、")) 搭配做家常小炒")
        } else if results.isEmpty, let only = ingredients.first {
            results.append("先用 \(only) 做一道简单家常菜")
        }

        return Array(results.prefix(3))
    }

    private static func containsAny(in set: Set<String>, keywords: [String]) -> Bool {
        set.contains { name in
            keywords.contains { name.localizedCaseInsensitiveContains($0) }
        }
    }
}
