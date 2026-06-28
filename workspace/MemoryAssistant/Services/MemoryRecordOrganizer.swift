import Foundation

struct MemoryRecordGroup: Identifiable {
    enum Kind {
        case place
        case schedule
        case note
    }

    let id: String
    let title: String
    let subtitle: String
    let records: [MemoryRecord]
    let kind: Kind

    var itemCount: Int { records.count }
}

/// 自动整理：把旧格式记录重新解析，并按地点/类型分组压缩展示。
enum MemoryRecordOrganizer {
    static func normalizeAll(_ records: [MemoryRecord]) -> (records: [MemoryRecord], changedCount: Int) {
        var changedCount = 0
        var normalized: [MemoryRecord] = []

        for record in records {
            if record.isExpanded {
                let light = normalizePlaceFields(record)
                if light != record { changedCount += 1 }
                normalized.append(light)
                continue
            }
            let reparsed = normalize(record)
            if reparsed != record { changedCount += 1 }
            let expanded = CompoundIngredientExpander.expandRecords([reparsed])
            if expanded.count != 1 { changedCount += 1 }
            normalized.append(contentsOf: expanded)
        }

        return (normalized, changedCount)
    }

    static func normalize(_ record: MemoryRecord) -> MemoryRecord {
        let sourceText = sourceText(for: record)
        guard !sourceText.isEmpty else { return record }

        if isWellStructured(record), !MemoryDraftParser.looksLikeSentence(record.title) {
            return normalizePlaceFields(record)
        }

        let reparsed = MemoryDraftParser.draft(from: sourceText).makeRecord(from: record)
        var result = reparsed

        if result.placeDescription != nil || result.dueDate != nil || result.category == .location {
            if result.details.isEmpty || result.details == result.title {
                result.details = sourceText
            }
            result = normalizePlaceFields(result)
            return result
        }

        if MemoryDraftParser.looksLikeSentence(record.title),
           reparsed.title != record.title,
           reparsed.title.count < sourceText.count {
            if result.details.isEmpty {
                result.details = sourceText
            }
            return result
        }

        return normalizePlaceFields(record)
    }

    static func group(_ records: [MemoryRecord]) -> [MemoryRecordGroup] {
        var placeBuckets: [String: [MemoryRecord]] = [:]
        var schedules: [MemoryRecord] = []
        var notes: [MemoryRecord] = []

        for record in records {
            // 日程优先：有 dueDate 的记录归为日程，即使同时有 placeDescription
            if record.dueDate != nil {
                schedules.append(record)
                continue
            }
            if let place = record.placeDescription, !place.isEmpty {
                let key = placeClusterKey(place)
                placeBuckets[key, default: []].append(record)
            } else {
                notes.append(record)
            }
        }

        var groups: [MemoryRecordGroup] = []

        for (key, items) in placeBuckets.sorted(by: { $0.value.count > $1.value.count }) {
            let expanded = CompoundIngredientExpander.expandRecords(items)
            let sorted = expanded.sorted { $0.updatedAt > $1.updatedAt }
            groups.append(MemoryRecordGroup(
                id: "place-\(key)",
                title: key,
                subtitle: sorted.map(\.title).joined(separator: "、"),
                records: sorted,
                kind: .place
            ))
        }

        for record in schedules.sorted(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }) {
            let time = record.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? ""
            groups.append(MemoryRecordGroup(
                id: "schedule-\(record.id.uuidString)",
                title: record.title,
                subtitle: time,
                records: [record],
                kind: .schedule
            ))
        }

        if !notes.isEmpty {
            let sorted = notes.sorted { $0.updatedAt > $1.updatedAt }
            for record in sorted {
                let subtitle: String
                if !record.details.isEmpty, record.details != record.title {
                    subtitle = record.details
                } else {
                    subtitle = record.updatedAt.formatted(date: .abbreviated, time: .omitted)
                }
                groups.append(MemoryRecordGroup(
                    id: "note-\(record.id.uuidString)",
                    title: record.title,
                    subtitle: subtitle,
                    records: [record],
                    kind: .note
                ))
            }
        }

        return groups.sorted { lhs, rhs in
            let leftDate = lhs.records.map(\.updatedAt).max() ?? .distantPast
            let rightDate = rhs.records.map(\.updatedAt).max() ?? .distantPast
            return leftDate > rightDate
        }
    }

    // MARK: - Private

    private static func isWellStructured(_ record: MemoryRecord) -> Bool {
        if MemoryDraftParser.looksLikeSentence(record.title) {
            return false
        }

        if let place = record.placeDescription, !place.isEmpty {
            return !record.title.contains("在") && record.title.count <= 12
        }
        if record.dueDate != nil, !record.title.isEmpty {
            return true
        }
        return false
    }

    private static func normalizePlaceFields(_ record: MemoryRecord) -> MemoryRecord {
        var result = record
        if let place = result.placeDescription {
            result.placeDescription = normalizePlaceName(place)
        }
        if result.category == .location, MemoryDraftParser.looksLikeSentence(result.title) {
            let source = sourceText(for: result)
            let title = MemoryDraftParser.coreItemTitle(from: source)
            if !title.isEmpty, title.count < source.count {
                result.title = title
            }
        }
        return result
    }

    private static func normalizePlaceName(_ place: String) -> String {
        var result = place.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("里了") {
            result = String(result.dropLast())
        }
        if result.hasSuffix("了") {
            result = String(result.dropLast())
        }
        return result
    }

    private static func sourceText(for record: MemoryRecord) -> String {
        if !record.details.isEmpty { return record.details }
        if record.title.contains("在") || record.title.contains("里有") { return record.title }
        return record.title
    }

    private static func placeClusterKey(_ place: String) -> String {
        let anchors = [
            "冰箱冷藏", "冰箱冷冻", "冰箱",
            "客厅桌子", "客厅",
            "厨房", "阳台", "卧室", "书房", "玄关",
            "卫生间", "抽屉", "柜子", "桌子", "车上"
        ]
        for anchor in anchors {
            if place.contains(anchor) {
                return anchor
            }
        }
        if place.count > 8 {
            return String(place.suffix(8))
        }
        return place
    }
}
