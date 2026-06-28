import Foundation

enum MemoryDraftParser {
    /// 标题是否仍像整句描述，而非核心物品/事项名。
    static func looksLikeSentence(_ title: String) -> Bool {
        let markers = [
            "买了", "放在", "放到", "搁在", "藏在", "塞进",
            "今天是", "昨天是", "明天是", "端午节", "春节", "节日",
            "刚才", "刚刚", "采购了", "放在冰箱",
            "已经切好", "切好了", "准备好了", "弄好了",
            "煮好", "洗好", "做好", "完成了", "处理了"
        ]
        if markers.contains(where: { title.contains($0) }) { return true }

        // 整句通常包含明确的动词+地点结构，而不只是物品描述
        let sentencePatterns = ["我买", "我放", "买了", "放在", "放在", "装在", "摆在", "放在了"]
        if sentencePatterns.contains(where: { title.contains($0) }) { return true }

        // 纯量词"斤/个/条"等出现在短描述中也可能像整句
        if title.count > 18 { return true }
        return false
    }

    /// 从已有记录文本提取展示用物品名。
    static func coreItemTitle(from text: String) -> String {
        let draft = draft(from: text)
        return draft.title
    }

    /// 从物品短语提取核心名称（去掉「已经切好」等状态描述）。
    static func extractCoreItemName(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let noise = [
            "已经切好", "已经准备好", "已经弄好", "已经煮好", "已经洗好",
            "切好了", "准备好了", "弄好了", "煮好了", "洗好了",
            "已经", "切好", "准备好"
        ]
        for phrase in noise {
            result = result.replacingOccurrences(of: phrase, with: "")
        }

        // 去掉位置修饰词：冰箱里的/桌上的/厨房的 → 保留核心物品名
        let locationPrefixes = [
            "冰箱里的", "冰箱的", "桌上的", "桌子上的", "客厅的", "厨房的",
            "房间里的", "卧室里的", "抽屉里的", "柜子里的", "书房的"
        ]
        for prefix in locationPrefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }

        // 去掉数量单位前缀：2斤苹果 → 苹果；一个西瓜 → 西瓜
        if let quantityStripped = stripLeadingQuantity(from: result) {
            result = quantityStripped
        }

        return collapseWhitespaces(in: result)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))
    }

    static func draft(from rawText: String, now: Date = Date(), calendar: Calendar = .current) -> MemoryDraft {
        let cleaned = normalize(rawText)

        if let contained = parseContainedLocationDraft(from: cleaned) {
            return contained
        }

        if let purchaseDraft = parsePurchaseLocationDraft(from: cleaned) {
            return purchaseDraft
        }

        if let relocateDraft = parseRelocateDraft(from: cleaned) {
            return relocateDraft
        }

        if let shortPlaceDraft = parseShortPlaceDraft(from: cleaned) {
            return shortPlaceDraft
        }

        if let locationDraft = parseLocationDraft(from: cleaned) {
            return locationDraft
        }

        if isScheduleText(cleaned) {
            var draft = MemoryDraft()
            draft.category = .schedule
            draft.hasDueDate = true
            draft.dueDate = extractDate(from: cleaned, now: now, calendar: calendar) ?? now
            draft.title = extractScheduleTitle(from: cleaned)
            draft.details = cleaned
            return draft
        }

        var draft = MemoryDraft()
        draft.category = .note
        draft.title = extractNoteTitle(from: cleaned)
        draft.details = cleaned
        return draft
    }

    /// 「冰箱里有西瓜」「桌上放着钥匙」
    private static func parseContainedLocationDraft(from text: String) -> MemoryDraft? {
        let markers: [(String, String)] = [
            ("里有", "里"),
            ("上有", "上"),
            ("内有", "内"),
            ("放着", ""),
            ("放了", "")
        ]

        for (marker, suffix) in markers {
            guard let range = text.range(of: marker) else { continue }

            let placePart = sanitizeLeadingPhrase(String(text[..<range.lowerBound]))
            var itemPart = String(text[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))

            guard placePart.count >= 2, !itemPart.isEmpty, itemPart.count <= 24 else { continue }

            itemPart = sanitizeLeadingPhrase(itemPart)
            guard !itemPart.isEmpty else { continue }

            var place = placePart
            if !suffix.isEmpty, !place.hasSuffix(suffix) {
                place += suffix
            }

            var draft = MemoryDraft()
            draft.category = .location
            draft.title = itemPart
            draft.placeDescription = place
            draft.details = text
            return draft
        }

        return nil
    }

    /// 「西瓜已经切好放客厅桌子上」「鱼放厨房了」
    private static func parseRelocateDraft(from text: String) -> MemoryDraft? {
        let patterns = [
            #"^(.+?)(?:已经)?(?:切好|准备好|弄好|煮好|洗好)?放(?!在)(.+)$"#,
            #"^(.+?)放(?:在)?(.+?)上了$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            let item = extractCoreItemName(sanitizeItemPhrase(nsSubstring(in: text, range: match.range(at: 1))))
            let place = sanitizePlacePhrase(nsSubstring(in: text, range: match.range(at: 2)))

            guard !item.isEmpty, !place.isEmpty else { continue }

            var draft = MemoryDraft()
            draft.category = .location
            draft.title = item
            draft.placeDescription = place
            draft.details = text
            return draft
        }

        return nil
    }

    /// 「西瓜放冰箱」「鱼放冰箱里」
    private static func parseShortPlaceDraft(from text: String) -> MemoryDraft? {
        let pattern = #"^(.{1,14})放(?!在)(.{2,20})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let item = extractCoreItemName(sanitizeItemPhrase(nsSubstring(in: text, range: match.range(at: 1))))
        let place = sanitizePlacePhrase(nsSubstring(in: text, range: match.range(at: 2)))

        guard !item.isEmpty, !place.isEmpty else { return nil }

        var draft = MemoryDraft()
        draft.category = .location
        draft.title = item
        draft.placeDescription = place
        draft.details = text
        return draft
    }

    /// 「买了粽子放在冰箱」「今天买了糯米酒放在冰箱」
    private static func parsePurchaseLocationDraft(from text: String) -> MemoryDraft? {
        let pattern = #"(?:买了|购买了|采购了)(.+?)(?:放在|放到|搁在|藏在|塞进)(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        var item = nsSubstring(in: text, range: match.range(at: 1))
        var place = nsSubstring(in: text, range: match.range(at: 2))

        item = sanitizePurchasedItem(item)
        place = sanitizePlacePhrase(place)

        guard !item.isEmpty, !place.isEmpty else { return nil }

        var draft = MemoryDraft()
        draft.category = .location
        draft.title = item
        draft.placeDescription = place
        draft.details = text
        return draft
    }

    private static func sanitizePurchasedItem(_ text: String) -> String {
        var result = collapseWhitespaces(in: text)
        let trimSuffixes = CharacterSet(charactersIn: "。；，,！!？? ")
        result = result.trimmingCharacters(in: trimSuffixes)

        let noisePatterns = [
            #"^(?:一点|一些|些)"#,
            #"^是"#
        ]
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..<result.endIndex, in: result)),
               let range = Range(match.range, in: result) {
                result = String(result[range.upperBound...])
            }
        }

        if let quantityStripped = stripLeadingQuantity(from: result) {
            result = quantityStripped
        }

        return collapseWhitespaces(in: result)
            .trimmingCharacters(in: trimSuffixes)
    }

    private static func stripLeadingQuantity(from text: String) -> String? {
        let unit = "(?:斤|克|千克|公斤|kg|个|只|条|瓶|袋|盒|包|箱|件|把|捆|罐|桶|听|杯|份|盘|碗|勺|块|粒|颗|片)"
        let patterns = [
            #"^\d+(?:\.\d+)?"# + unit,
            #"^(?:几|数|半|一两|两|三|四|五|六|七|八|九|十|多)"# + unit,
            #"^[一二三四五六七八九十两]+"# + unit,
            #"^\d+\s*"# + unit
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let swiftRange = Range(match.range, in: text) else {
                continue
            }
            let remainder = String(text[swiftRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty {
                return remainder
            }
        }
        return nil
    }

    private static func sanitizePlacePhrase(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("了") {
            result = String(result.dropLast())
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))
    }

    private static func parseLocationDraft(from text: String) -> MemoryDraft? {
        let separators = ["放在", "放到", "搁在", "藏在", "塞进", "位于", "在"]

        for separator in separators {
            let parts = text.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }

            let subject = sanitizeItemPhrase(parts[0])
            let place = parts.dropFirst().joined(separator: separator)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,"))

            guard !subject.isEmpty, !place.isEmpty else { continue }

            var draft = MemoryDraft()
            draft.category = .location
            draft.title = subject
            draft.placeDescription = place
            draft.details = text
            return draft
        }

        return nil
    }

    private static func extractScheduleTitle(from text: String) -> String {
        let phrasesToRemove = [
            "帮我记一下", "记一下", "提醒我", "安排", "明天", "今天",
            "上午", "中午", "下午", "晚上", "点", "会议", "开会"
        ]

        var title = text
        for phrase in phrasesToRemove {
            title = title.replacingOccurrences(of: phrase, with: " ")
        }

        title = collapseWhitespaces(in: title)
        return title.isEmpty ? "新日程" : title
    }

    private static func extractNoteTitle(from text: String) -> String {
        let cleaned = sanitizeLeadingPhrase(text)
        if cleaned.count <= 18 {
            return cleaned.isEmpty ? "新备忘" : cleaned
        }

        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 18)
        return String(cleaned[..<endIndex])
    }

    private static func isScheduleText(_ text: String) -> Bool {
        let hasTimeHint = text.contains("点")
            || text.contains(":")
            || text.contains("：")
            || extractHourMinute(from: text) != nil
        let hasDayHint = text.contains("明天") || text.contains("今天")
        let scheduleKeywords = ["会议", "开会", "安排", "日程", "几点", "提醒", "饭局", "约会"]

        if hasDayHint && (hasTimeHint || scheduleKeywords.contains { text.contains($0) }) {
            return true
        }
        return scheduleKeywords.contains { text.contains($0) } && (hasTimeHint || hasDayHint)
    }

    private static func extractDate(from text: String, now: Date, calendar: Calendar) -> Date? {
        let baseDate: Date
        if text.contains("明天") {
            baseDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        } else {
            baseDate = now
        }

        let hourMinute = extractHourMinute(from: text)
        guard let hourMinute else { return baseDate }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hourMinute.hour
        components.minute = hourMinute.minute
        return calendar.date(from: components)
    }

    private static func extractHourMinute(from text: String) -> (hour: Int, minute: Int)? {
        let normalized = text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "点半", with: ":30")

        // 必须带「点」或「:」，避免把「5斤」「3个」误判成时间。
        let pattern = #"([上下中晚早]午)?\s*(\d{1,2})\s*(?:点|:)\s*(\d{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, range: range) else {
            return nil
        }

        let period = nsSubstring(in: normalized, range: match.range(at: 1))
        let hourString = nsSubstring(in: normalized, range: match.range(at: 2))
        let minuteString = nsSubstring(in: normalized, range: match.range(at: 3))

        guard var hour = Int(hourString) else { return nil }
        let minute = Int(minuteString) ?? 0

        if period == "上午", hour == 12 {
            hour = 0
        }

        if ["下午", "晚上"].contains(period), hour < 12 {
            hour += 12
        }

        if period == "中午", hour < 11 {
            hour += 12
        }

        // 无时段时：口语「明天 3 点」通常指下午，1～6 点默认加 12。
        if period.isEmpty, (1...6).contains(hour) {
            hour += 12
        }

        return (min(hour, 23), min(minute, 59))
    }

    /// 从物品描述里去掉「今天买了」这类前缀，保留核心物品名。
    private static func sanitizeItemPhrase(_ text: String) -> String {
        var result = sanitizeLeadingPhrase(text)

        if let purchase = extractPurchasedItemFragment(from: result) {
            return purchase
        }

        let prefixes = [
            "今天是", "昨天是", "明天是",
            "今天", "昨天", "明天", "刚才", "刚刚",
            "买了些", "买了点", "买了一些", "采购了", "买了"
        ]
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
            }
        }

        if let quantityStripped = stripLeadingQuantity(from: result) {
            result = quantityStripped
        }

        return collapseWhitespaces(in: result)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。；，, "))
    }

    private static func extractPurchasedItemFragment(from text: String) -> String? {
        let pattern = #"(?:买了|购买了|采购了)(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let item = sanitizePurchasedItem(nsSubstring(in: text, range: match.range(at: 1)))
        return item.isEmpty ? nil : item
    }

    private static func sanitizeLeadingPhrase(_ text: String) -> String {
        let phrases = [
            "帮我记一下", "帮我记录", "记一下", "记录一下", "提醒我",
            "请帮我记住", "用记忆助手记录", "记忆助手记录"
        ]
        var result = text
        for phrase in phrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        result = collapseWhitespaces(in: result)
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "。；，, "))
    }

    private static func normalize(_ text: String) -> String {
        var result = collapseWhitespaces(in: text)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let buyRange = result.range(of: "买了") {
            let prefix = String(result[..<buyRange.lowerBound])
            if prefix.contains("今天是") || prefix.contains("昨天是") || prefix.contains("明天是")
                || prefix.contains("节") || prefix.hasSuffix("天") {
                result = String(result[buyRange.lowerBound...])
            }
        }

        return result
    }

    private static func collapseWhitespaces(in text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func nsSubstring(in text: String, range: NSRange) -> String {
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
            return ""
        }
        return String(text[swiftRange])
    }
}
