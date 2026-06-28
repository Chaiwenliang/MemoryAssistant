import Foundation

struct ConsumeRequest: Equatable {
    let itemQuery: String
    let placeQuery: String?
}

struct MoveRequest: Equatable {
    let itemQuery: String
    let fromPlaceQuery: String?
    let toPlaceQuery: String
}

enum MemoryUpdateAction: Equatable {
    case consume(ConsumeRequest)
    case move(MoveRequest)
}

enum MemoryUpdateResult {
    case notFound(item: String)
    case ambiguous(item: String, candidates: [MemoryRecord])
    case consumed([MemoryRecord])
    case moved(MemoryRecord, to: String)
}

/// 用自然语言更新已有记录：吃完、挪位置。始终只动「你说到的那一条」。
enum MemoryUpdateRouter {
    private static let consumeMarkers = [
        "吃完了", "吃掉了", "用完了", "用掉了", "没有了", "不再有了",
        "没了", "不见了", "丢了", "删掉了", "删除了", "删掉", "不要了", "扔了", "喝完了", "喝掉了"
    ]

    private static let movePatterns: [(String, Int, Int, Int?)] = [
        (#"^(.+?)从(.+?)(?:拿到|移到|搬到|放到|放在|挪到|转移至|转到)(.+)$"#, 1, 2, 3),
        (#"^(.+?)(?:拿到|移到|搬到|放到|放在|挪到|转移至|转到)(.+)$"#, 1, -1, 2),
        (#"^(.+?)不在(.+?)了$"#, 1, 2, nil)
    ]

    static func findExistingRecord(itemQuery: String, in records: [MemoryRecord]) -> MemoryRecord? {
        let item = MemoryDraftParser.extractCoreItemName(itemQuery)
        let candidates = findCandidates(itemQuery: item, placeQuery: nil, in: records)
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 {
            return candidates[0]
        }
        return candidates.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    static func parseUpdate(_ text: String) -> MemoryUpdateAction? {
        if let move = parseMove(text) {
            return .move(move)
        }
        if let consume = parseConsume(text) {
            return .consume(consume)
        }
        return nil
    }

    static func isUpdateStatement(_ text: String) -> Bool {
        parseUpdate(text) != nil
    }

    static func apply(
        _ action: MemoryUpdateAction,
        in records: [MemoryRecord],
        allowsBatch: Bool = false
    ) -> MemoryUpdateResult {
        switch action {
        case .consume(let request):
            return applyConsume(request, in: records, allowsBatch: allowsBatch)
        case .move(let request):
            return applyMove(request, in: records)
        }
    }

    static func message(for result: MemoryUpdateResult) -> String {
        switch result {
        case .notFound(let item):
            return "没有找到和「\(item)」相关的记录。可以说得更具体些，例如：冰箱里的西瓜吃完了。"
        case .ambiguous(let item, let candidates):
            let hints = candidates.prefix(3).map { hint(for: $0) }.joined(separator: "；")
            return "找到多条「\(item)」，请说清楚是哪一个，例如：\(hints)。"
        case .consumed(let archived):
            return confirmation(for: archived)
        case .moved(let record, let place):
            return "好的，已将\(record.title)更新为在\(place)。"
        }
    }

    // MARK: - Consume

    private static func parseConsume(_ text: String) -> ConsumeRequest? {
        guard consumeMarkers.contains(where: { text.contains($0) }) else { return nil }

        var cleaned = MemoryQueryRouter.normalize(text)
        for marker in consumeMarkers.sorted(by: { $0.count > $1.count }) {
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }
        cleaned = stripNoise(cleaned)
        guard !cleaned.isEmpty else { return nil }

        if let parsed = parseItemAndPlace(from: cleaned) {
            return ConsumeRequest(itemQuery: parsed.item, placeQuery: parsed.place)
        }
        return ConsumeRequest(itemQuery: cleaned, placeQuery: nil)
    }

    private static func applyConsume(
        _ request: ConsumeRequest,
        in records: [MemoryRecord],
        allowsBatch: Bool
    ) -> MemoryUpdateResult {
        let item = MemoryDraftParser.extractCoreItemName(request.itemQuery)
        let candidates = findCandidates(
            itemQuery: item,
            placeQuery: request.placeQuery,
            in: records
        )

        let canPickLatest = allowsBatch || request.allowsBatch || request.placeQuery != nil
        if let record = resolveSingle(
            itemQuery: item,
            candidates: candidates,
            allowsBatch: canPickLatest
        ) {
            return .consumed([record])
        }
        return ambiguousOrNotFound(item: item, candidates: candidates)
    }

    // MARK: - Move

    private static func parseMove(_ text: String) -> MoveRequest? {
        let normalized = MemoryQueryRouter.normalize(text)
        if consumeMarkers.contains(where: { normalized.contains($0) }) { return nil }

        if let relocate = parseRelocateMove(normalized) {
            return relocate
        }

        let moveMarkers = ["拿到", "移到", "搬到", "放到", "放在", "挪到", "转移至", "转到", "不在"]
        guard moveMarkers.contains(where: { normalized.contains($0) }) else { return nil }

        for (pattern, itemGroup, fromGroup, toGroup) in movePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            guard let match = regex.firstMatch(in: normalized, range: range) else { continue }

            let rawItem = capture(normalized, match: match, group: itemGroup)
            let item = MemoryDraftParser.extractCoreItemName(rawItem)
            let fromPlace = fromGroup >= 0 ? capture(normalized, match: match, group: fromGroup) : nil
            let toPlace = toGroup.map { capture(normalized, match: match, group: $0) } ?? ""

            if normalized.contains("不在"), let from = fromPlace, !from.isEmpty, toPlace.isEmpty {
                return MoveRequest(itemQuery: item, fromPlaceQuery: from, toPlaceQuery: "")
            }

            guard !item.isEmpty, !toPlace.isEmpty else { continue }
            return MoveRequest(itemQuery: item, fromPlaceQuery: fromPlace, toPlaceQuery: toPlace)
        }

        return nil
    }

    private static func parseRelocateMove(_ text: String) -> MoveRequest? {
        let patterns = [
            #"^(.+?)(?:已经)?(?:切好|准备好|弄好|煮好|洗好)?放(?:在)?(.+?)上了?$"#,
            #"^(.+?)(?:已经)?(?:切好|准备好|弄好)?放(?!在)(.+)$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            let rawItem = capture(text, match: match, group: 1)
            let place = sanitizePlace(capture(text, match: match, group: 2))
            let item = MemoryDraftParser.extractCoreItemName(rawItem)

            guard !item.isEmpty, !place.isEmpty else { continue }
            return MoveRequest(itemQuery: item, fromPlaceQuery: nil, toPlaceQuery: place)
        }
        return nil
    }

    private static func sanitizePlace(_ place: String) -> String {
        var result = place.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("了") {
            result = String(result.dropLast())
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))
    }

    private static func applyMove(_ request: MoveRequest, in records: [MemoryRecord]) -> MemoryUpdateResult {
        let candidates = findCandidates(
            itemQuery: request.itemQuery,
            placeQuery: request.fromPlaceQuery,
            in: records
        )

        guard let record = resolveSingle(
            itemQuery: request.itemQuery,
            candidates: candidates,
            allowsBatch: false
        ) else {
            if candidates.count > 1 {
                return .ambiguous(item: request.itemQuery, candidates: candidates)
            }
            return .notFound(item: request.itemQuery)
        }

        if request.toPlaceQuery.isEmpty {
            return .consumed([record])
        }
        return .moved(record, to: request.toPlaceQuery)
    }

    // MARK: - Matching

    static func findTargets(_ request: ConsumeRequest, in records: [MemoryRecord]) -> [MemoryRecord] {
        let item = MemoryDraftParser.extractCoreItemName(request.itemQuery)
        return findCandidates(itemQuery: item, placeQuery: request.placeQuery, in: records)
    }

    private static func findCandidates(
        itemQuery: String,
        placeQuery: String?,
        in records: [MemoryRecord]
    ) -> [MemoryRecord] {
        var candidates = records.filter { !$0.isArchived }

        if let place = placeQuery, !place.isEmpty {
            let placeKey = normalizePlaceToken(place)
            candidates = candidates.filter { record in
                guard let recordPlace = record.placeDescription, !recordPlace.isEmpty else {
                    return false
                }
                return placesMatch(placeKey, recordPlace)
            }
        }

        let itemKey = itemQuery.lowercased()
        return candidates.filter { matchesItem(itemKey, record: $0) }
    }

    private static func resolveSingle(
        itemQuery: String,
        candidates: [MemoryRecord],
        allowsBatch: Bool
    ) -> MemoryRecord? {
        switch candidates.count {
        case 0:
            return nil
        case 1:
            return candidates[0]
        default:
            if let exact = candidates.first(where: { $0.title.lowercased() == itemQuery.lowercased() }) {
                return exact
            }
            if allowsBatch {
                return candidates.sorted { $0.updatedAt > $1.updatedAt }.first
            }
            return nil
        }
    }

    private static func ambiguousOrNotFound(item: String, candidates: [MemoryRecord]) -> MemoryUpdateResult {
        if candidates.count > 1 {
            return .ambiguous(item: item, candidates: candidates)
        }
        return .notFound(item: item)
    }

    private static func confirmation(for archived: [MemoryRecord]) -> String {
        guard let record = archived.first else {
            return "没有找到可以更新的记录。"
        }
        if let place = record.placeDescription, !place.isEmpty {
            return "好的，已更新：\(place)的\(record.title)不再计入库存。下次查询\(place)时不会出现。"
        }
        return "好的，已更新：\(record.title)不再计入库存。"
    }

    private static func hint(for record: MemoryRecord) -> String {
        if let place = record.placeDescription, !place.isEmpty {
            return "\(place)的\(record.title)吃完了"
        }
        return "\(record.title)吃完了"
    }

    private static func parseItemAndPlace(from text: String) -> (item: String, place: String?)? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let containerSuffixes = ["上的", "里的", "中的", "内的", "上边", "里边"]
        for suffix in containerSuffixes {
            if let range = normalized.range(of: suffix) {
                let place = String(normalized[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let item = MemoryDraftParser.extractCoreItemName(
                    String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                )
                if !item.isEmpty, !place.isEmpty {
                    return (item, place)
                }
            }
        }

        if let liRange = text.range(of: "里的") {
            let place = String(text[..<liRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let item = String(text[liRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !item.isEmpty, !place.isEmpty {
                return (item, place)
            }
        }
        if let inRange = text.range(of: "在") {
            let item = String(text[..<inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var place = String(text[inRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            place = place.trimmingCharacters(in: CharacterSet(charactersIn: "的"))
            if !item.isEmpty, !place.isEmpty {
                return (item, place)
            }
        }
        return nil
    }

    private static func normalizePlaceToken(_ place: String) -> String {
        place
            .replacingOccurrences(of: "上面的", with: "")
            .replacingOccurrences(of: "上面", with: "")
            .replacingOccurrences(of: "上的", with: "")
            .replacingOccurrences(of: "里的", with: "")
            .replacingOccurrences(of: "中的", with: "")
            .replacingOccurrences(of: "上", with: "")
            .replacingOccurrences(of: "里", with: "")
            .replacingOccurrences(of: "的", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func placesMatch(_ query: String, _ recordPlace: String) -> Bool {
        let queryToken = normalizePlaceToken(query)
        let recordToken = normalizePlaceToken(recordPlace)
        guard !queryToken.isEmpty, !recordToken.isEmpty else { return false }
        if recordToken.contains(queryToken) || queryToken.contains(recordToken) { return true }
        return recordToken.hasPrefix(queryToken) || queryToken.hasPrefix(recordToken)
    }

    private static func stripNoise(_ text: String) -> String {
        text
            .replacingOccurrences(of: "已经", with: "")
            .replacingOccurrences(of: "把", with: "")
            .replacingOccurrences(of: "将", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? 了"))
    }

    private static func capture(_ text: String, match: NSTextCheckingResult, group: Int) -> String {
        guard group >= 0, group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: text) else {
            return ""
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesItem(_ itemKey: String, record: MemoryRecord) -> Bool {
        let title = record.title.lowercased()
        let ingredientNames = CompoundIngredientExpander.expandNames(record.title).map { $0.lowercased() }

        if title == itemKey { return true }
        if ingredientNames.contains(itemKey) { return true }

        if itemKey.count >= 2, (title.contains(itemKey) || itemKey.contains(title)) {
            return true
        }
        return ingredientNames.contains { $0.contains(itemKey) || itemKey.contains($0) }
    }
}

private extension ConsumeRequest {
    var allowsBatch: Bool {
        itemQuery.contains("都") || itemQuery.contains("全") || itemQuery.contains("全部")
    }
}

extension Array where Element == MemoryRecord {
    var activeOnly: [MemoryRecord] {
        filter { !$0.isArchived }
    }
}
