import Foundation

enum MemorySearchEngine {
    static func tomorrowSchedules(from records: [MemoryRecord], calendar: Calendar = .current) -> [MemoryRecord] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return records.activeOnly
            .filter { $0.category == .schedule && $0.isOnSameDay(as: tomorrow, calendar: calendar) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    static func todaySchedules(from records: [MemoryRecord], calendar: Calendar = .current) -> [MemoryRecord] {
        records.activeOnly
            .filter { $0.category == .schedule && $0.isOnSameDay(as: Date(), calendar: calendar) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    static func primarySearchTerm(from query: String) -> String {
        let tokens = queryTokens(from: query.lowercased())
        return tokens.first(where: { $0.count >= 2 }) ?? query
    }

    // MARK: - 反向位置查询（「客厅桌子上有什么」）

    static func isReverseLocationQuery(_ query: String) -> Bool {
        guard !query.contains("明天"), !query.contains("今天") else { return false }
        let markers = ["有什么", "有哪些", "放着什么", "放了什么", "有啥", "有什么东西"]
        return markers.contains { query.contains($0) }
    }

    static func extractLocationPhrase(from query: String) -> String {
        var text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = ["有什么东西", "有什么", "有哪些", "放着什么", "放了什么", "有啥", "吗", "？", "?"]
        for suffix in suffixes {
            text = text.replacingOccurrences(of: suffix, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func reverseLocationSearch(query: String, in records: [MemoryRecord]) -> [MemoryRecord] {
        guard isReverseLocationQuery(query) else { return [] }

        let activeRecords = records.activeOnly
        let locationPhrase = extractLocationPhrase(from: query).lowercased()
        guard locationPhrase.count >= 2 else { return [] }

        let variants = locationMatchVariants(for: locationPhrase)

        let matched = activeRecords.compactMap { record -> (MemoryRecord, Int)? in
            let searchable = searchablePlaceText(for: record).lowercased()
            guard !searchable.isEmpty else { return nil }
            let score = reverseLocationScore(place: searchable, variants: variants, query: locationPhrase)
            return score > 0 ? (record, score) : nil
        }

        return matched
            .sorted {
                if $0.1 == $1.1 { return $0.0.updatedAt > $1.0.updatedAt }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private static func locationMatchVariants(for phrase: String) -> [String] {
        var variants = [phrase]
        if phrase.hasSuffix("上"), phrase.count > 1 {
            variants.append(String(phrase.dropLast()))
        }
        if phrase.hasSuffix("里"), phrase.count > 1 {
            variants.append(String(phrase.dropLast()))
        }
        if phrase.hasSuffix("中"), phrase.count > 1 {
            variants.append(String(phrase.dropLast()))
        }
        if phrase.count >= 4 {
            variants.append(String(phrase.prefix(phrase.count - 1)))
        }
        return Array(Set(variants)).filter { $0.count >= 2 }
    }

    private static func reverseLocationScore(place: String, variants: [String], query: String) -> Int {
        var score = 0
        for variant in variants {
            if place == variant { score += 200 }
            if place.contains(variant) { score += 120 }
            if variant.contains(place) { score += 100 }
        }
        if place.contains(query) { score += 80 }
        return score
    }

    private static func hasPlaceInformation(_ record: MemoryRecord) -> Bool {
        if record.category == .location { return true }
        if let place = record.placeDescription, !place.isEmpty { return true }
        let text = record.title + record.details
        return text.contains("在") || text.contains("放在") || text.contains("里有") || text.contains("上有")
    }

    static func displayItemName(for record: MemoryRecord, locationPhrase: String = "") -> String {
        let cleanTitle: String
        if MemoryDraftParser.looksLikeSentence(record.title) {
            let source = !record.details.isEmpty ? record.details : record.title
            cleanTitle = MemoryDraftParser.coreItemTitle(from: source)
        } else {
            cleanTitle = record.title
        }

        if record.category == .location, !cleanTitle.isEmpty {
            return cleanTitle
        }

        if !locationPhrase.isEmpty {
            let extracted = itemName(for: record, locationPhrase: locationPhrase)
            if !MemoryDraftParser.looksLikeSentence(extracted) {
                return extracted
            }
        }

        return cleanTitle.isEmpty ? record.title : cleanTitle
    }

    static func formatReverseLocationAnswer(place: String, items: String) -> String {
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPlace = trimmedPlace.isEmpty ? "那里" : trimmedPlace

        if displayPlace.hasSuffix("里") || displayPlace.hasSuffix("内")
            || displayPlace.hasSuffix("上") || displayPlace.hasSuffix("中") {
            return "根据你的记录：\(displayPlace)有 \(items)。"
        }

        let containerMarkers = ["冰箱", "冰柜", "厨房", "阳台", "卧室", "书房", "客厅", "卫生间", "浴室", "抽屉", "柜子", "包", "袋", "盒"]
        if containerMarkers.contains(where: { displayPlace.contains($0) }) {
            return "根据你的记录：\(displayPlace)里有 \(items)。"
        }

        let surfaceMarkers = ["桌", "台", "架", "沙发", "床", "地"]
        if surfaceMarkers.contains(where: { displayPlace.contains($0) }) {
            return "根据你的记录：\(displayPlace)上有 \(items)。"
        }

        return "根据你的记录：\(displayPlace)有 \(items)。"
    }

    static func itemName(for record: MemoryRecord, locationPhrase: String) -> String {
        if record.category == .location {
            return displayItemName(for: record, locationPhrase: locationPhrase)
        }

        let variants = locationMatchVariants(for: locationPhrase.lowercased())
        for text in [record.title, record.details] where !text.isEmpty {
            if let item = extractItem(from: text, locationVariants: variants) {
                return item
            }
        }
        return record.title
    }

    private static func extractItem(from text: String, locationVariants: [String]) -> String? {
        for location in locationVariants.sorted(by: { $0.count > $1.count }) {
            let patterns = ["\(location)里有", "\(location)上有", "\(location)内有", "在\(location)的", "在\(location)"]
            for pattern in patterns {
                guard let range = text.range(of: pattern) else { continue }
                let remainder = String(text[range.upperBound...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))
                if !remainder.isEmpty {
                    return remainder
                }
            }
        }
        return nil
    }

    private static func searchablePlaceText(for record: MemoryRecord) -> String {
        [
            record.placeDescription,
            record.title,
            record.details,
            record.tags.joined(separator: " ")
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private static func placeText(for record: MemoryRecord) -> String {
        if let place = record.placeDescription, !place.isEmpty {
            return place
        }
        if record.category == .location, !record.details.isEmpty {
            return record.details
        }
        return record.details
    }

    static func search(query: String, in records: [MemoryRecord]) -> [MemoryRecord] {
        let activeRecords = records.activeOnly
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return activeRecords.sorted { $0.updatedAt > $1.updatedAt }
        }

        let normalizedQuery = trimmedQuery.lowercased()
        let tokens = queryTokens(from: normalizedQuery)
        let existenceSubjects = extractExistenceSubjects(from: normalizedQuery)
        let searchTerms = Array(Set(tokens + existenceSubjects + [normalizedQuery, primarySearchTerm(from: normalizedQuery)]))

        let scored = activeRecords.compactMap { record -> (MemoryRecord, Int)? in
            let score = score(
                record: record,
                normalizedQuery: normalizedQuery,
                tokens: searchTerms,
                existenceSubjects: existenceSubjects
            )
            return score > 0 ? (record, score) : nil
        }

        return scored
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.updatedAt > $1.0.updatedAt
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private static func score(
        record: MemoryRecord,
        normalizedQuery: String,
        tokens: [String],
        existenceSubjects: [String] = []
    ) -> Int {
        let corpus = record.searchableText
        let title = record.title.lowercased()
        let details = record.details.lowercased()
        let place = (record.placeDescription ?? "").lowercased()
        let ingredientNames = CompoundIngredientExpander.expandNames(record.title).map { $0.lowercased() }

        var score = 0

        if corpus.contains(normalizedQuery) { score += 100 }
        if title.contains(normalizedQuery) { score += 80 }
        if place.contains(normalizedQuery) { score += 70 }
        if details.contains(normalizedQuery) { score += 50 }

        for subject in existenceSubjects where subject.count >= 1 {
            if matchesIngredient(subject, title: title, ingredientNames: ingredientNames) {
                score += 120
            }
            if place.contains(subject) { score += 25 }
            if details.contains(subject) { score += 20 }
        }

        for token in tokens where token.count >= 2 {
            if title == token { score += 60 }
            if title.contains(token) { score += 25 }
            if ingredientNames.contains(token) { score += 55 }
            if ingredientNames.contains(where: { $0.contains(token) || token.contains($0) }) { score += 35 }
            if place.contains(token) { score += 20 }
            if details.contains(token) { score += 15 }
            if corpus.contains(token) { score += 10 }
        }

        for token in tokens where token.count == 1 {
            if ingredientNames.contains(token) { score += 70 }
            if title == token { score += 80 }
            if title.contains(token) { score += 40 }
        }

        if isLocationQuery(normalizedQuery), !place.isEmpty {
            score += 20
        }

        if normalizedQuery.contains("明天"), record.dueDate != nil,
           record.isOnSameDay(as: tomorrowDate()) {
            score += 80
        }

        if normalizedQuery.contains("今天"), record.dueDate != nil,
           record.isOnSameDay(as: Date()) {
            score += 60
        }

        return score
    }

    /// 「家里有葱吗」「有没有葱」→ 提取「葱」
    static func extractExistenceSubjects(from query: String) -> [String] {
        let text = query
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let patterns = [
            #"家里有没有(.+)$"#,
            #"有没有(.+)$"#,
            #"家里有(.+)$"#,
            #"家中有(.+)$"#,
            #"^(?:有)(.+)$"#
        ]

        var subjects: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }
            let subject = String(text[Range(match.range(at: 1), in: text)!])
                .trimmingCharacters(in: CharacterSet(charactersIn: "吗呢么吧 "))
            if !subject.isEmpty {
                subjects.append(subject)
            }
        }

        return Array(Set(subjects))
    }

    private static func matchesIngredient(
        _ subject: String,
        title: String,
        ingredientNames: [String]
    ) -> Bool {
        if title == subject || title.contains(subject) { return true }
        if ingredientNames.contains(subject) { return true }
        if ingredientNames.contains(where: { $0.contains(subject) || subject.contains($0) }) { return true }
        return false
    }

    private static func isLocationQuery(_ query: String) -> Bool {
        ["哪里", "在哪儿", "在哪", "放哪", "放哪儿", "放在", "位置", "哪儿"].contains { query.contains($0) }
    }

    private static func queryTokens(from query: String) -> [String] {
        let stopPhrases = [
            "放在哪里", "放在哪儿", "放哪儿了", "放哪了", "放哪儿", "放哪",
            "在哪里", "在哪儿", "在哪", "什么地方", "啥地方",
            "明天的", "明天", "今天的", "今天",
            "安排", "工作", "查询", "查找", "看看", "一下",
            "什么", "怎么", "请问", "帮我", "记忆助手",
            "有什么", "有哪些", "有啥",
            "家里", "家中", "有没有", "有"
        ]

        var cleaned = query
        for phrase in stopPhrases {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
        }

        let splitTokens = cleaned
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        if splitTokens.isEmpty {
            return [query]
        }

        return Array(Set(splitTokens + [query]))
    }

    private static func tomorrowDate(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
}
