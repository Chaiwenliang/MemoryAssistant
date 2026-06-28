import Foundation

enum MemoryQueryIntent {
    case cookingAdvice
    case reverseLocation
    case forwardLocation
    case scheduleToday
    case scheduleTomorrow
    case general
}

enum MemoryQueryRouter {
    static func intent(for question: String) -> MemoryQueryIntent {
        let q = normalize(question)

        if isTomorrowScheduleQuery(q) { return .scheduleTomorrow }
        if isTodayScheduleQuery(q) { return .scheduleToday }
        if isCookingQuery(q) { return .cookingAdvice }
        if MemorySearchEngine.isReverseLocationQuery(q) { return .reverseLocation }
        if isForwardLocationQuery(q) { return .forwardLocation }
        return .general
    }

    /// 开放性问题，适合走 Pro + LLM。
    static func needsLLM(for question: String) -> Bool {
        let q = normalize(question)
        let routed = intent(for: q)

        switch routed {
        case .cookingAdvice:
            return true
        case .scheduleToday, .scheduleTomorrow, .reverseLocation, .forwardLocation:
            return false
        case .general:
            return isOpenEndedQuestion(q)
                || isLifestyleAdvisoryQuery(q)
                || isPersonalStateStatement(q)
        }
    }

    /// Pro 用户：规则引擎找不到时，短句自然表达也交给 LLM。
    static func shouldLLMFallback(for question: String, ruleResult: MemoryQueryResult) -> Bool {
        guard !ruleResult.found else { return false }

        let q = normalize(question)
        guard intent(for: q) == .general else { return false }
        guard q.count <= 24 else { return false }

        return !isForwardLocationQuery(q)
            && !MemorySearchEngine.isReverseLocationQuery(q)
            && !isTomorrowScheduleQuery(q)
            && !isTodayScheduleQuery(q)
    }

    /// Pro 是否应走 LLM（含兜底）。
    static func shouldUseLLM(for question: String, ruleResult: MemoryQueryResult, isPro: Bool) -> Bool {
        guard isPro else { return false }
        return needsLLM(for: question) || shouldLLMFallback(for: question, ruleResult: ruleResult)
    }

    static func normalize(_ question: String) -> String {
        var text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "帮我查一下", "帮我找一下", "查一下", "找一下", "请问",
            "我想知道", "告诉我", "记忆助手", "用记忆助手"
        ]
        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
            }
        }

        let dateNoiseWords = ["今天", "明天", "后天", "昨天", "本周", "这周", "上午", "中午", "下午", "晚上", "早上"]
        for word in dateNoiseWords {
            if let range = text.range(of: word) {
                // 只移除作为时间修饰词出现的情况，保留物品名中的字（如"今天"的粽子）
                let before = text[..<range.lowerBound]
                let after = text[range.upperBound...]
                // 如果前后是标点/空格/句子开头/与"的""是"等连接词，认为是时间修饰词
                let trimmedBefore = before.trimmingCharacters(in: .whitespaces)
                if trimmedBefore.isEmpty || trimmedBefore.hasSuffix("，") || trimmedBefore.hasSuffix(",")
                    || trimmedBefore.hasSuffix("。") || after.isEmpty || after.hasPrefix("的")
                    || after.hasPrefix("是") || after.hasPrefix("有") || after.hasPrefix("在") {
                    text = String(before) + String(after)
                }
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isOpenEndedQuestion(_ question: String) -> Bool {
        let openKeywords = [
            "建议", "推荐", "怎么办", "怎么做", "帮我想", "规划", "搭配", "值得",
            "有什么", "哪些", "总结", "还行吗", "能吃吗", "适合", "好不好", "帮帮我"
        ]
        if openKeywords.contains(where: { question.contains($0) }) {
            return true
        }

        let endsWithQuestion = question.hasSuffix("吗")
            || question.hasSuffix("呢")
            || question.hasSuffix("？")
            || question.hasSuffix("?")

        if endsWithQuestion {
            return !isForwardLocationQuery(question)
                && !MemorySearchEngine.isReverseLocationQuery(question)
                && !isTomorrowScheduleQuery(question)
                && !isTodayScheduleQuery(question)
        }

        return false
    }

    private static func isLifestyleAdvisoryQuery(_ question: String) -> Bool {
        let keywords = [
            "渴", "饿", "累", "困", "无聊", "冷", "热",
            "想喝", "想吃", "喝点", "吃点", "口渴", "肚子饿", "好渴", "好饿"
        ]
        return keywords.contains { question.contains($0) }
    }

    /// 「我渴了」「我饿了」等短句状态表达。
    private static func isPersonalStateStatement(_ question: String) -> Bool {
        guard question.count >= 3, question.count <= 12 else { return false }
        guard question.hasPrefix("我"), question.hasSuffix("了") else { return false }
        return isLifestyleAdvisoryQuery(question)
            || ["难受", "不舒服", "不开心", "烦"].contains { question.contains($0) }
    }

    private static func isCookingQuery(_ question: String) -> Bool {
        let keywords = [
            "做饭", "做菜", "下厨", "菜谱", "吃什么", "做什么菜",
            "晚餐", "午饭", "午餐", "晚饭", "夜宵", "吃点什么",
            "怎么烧", "怎么煮", "推荐菜", "食材"
        ]
        return keywords.contains { question.contains($0) }
    }

    private static func isForwardLocationQuery(_ question: String) -> Bool {
        ["在哪", "在哪儿", "哪里", "什么地方", "放哪", "放哪儿"].contains { question.contains($0) }
    }

    private static func isTomorrowScheduleQuery(_ question: String) -> Bool {
        let keywords = ["明天安排", "明天干嘛", "明天做什么", "明天有什么事", "明天有什么", "明天的安排"]
        return keywords.contains { question.contains($0) }
            || (question.contains("明天") && ["安排", "日程", "计划", "做什么", "干嘛"].contains { question.contains($0) })
    }

    private static func isTodayScheduleQuery(_ question: String) -> Bool {
        let keywords = ["今天安排", "今天干嘛", "今天做什么", "今天有什么事"]
        return keywords.contains { question.contains($0) }
            || (question.contains("今天") && ["安排", "日程", "计划"].contains { question.contains($0) })
    }
}
