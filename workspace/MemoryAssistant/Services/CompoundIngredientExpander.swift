import Foundation

/// 把「葱姜蒜」这类复合食材拆成独立条目，便于查询、分组和做饭建议。
enum CompoundIngredientExpander {
    private static let knownCompounds: [(compound: String, parts: [String])] = [
        ("葱姜蒜", ["葱", "姜", "蒜"]),
        ("姜蒜", ["姜", "蒜"]),
        ("葱姜", ["葱", "姜"]),
        ("葱蒜", ["葱", "蒜"])
    ]

    static func expandNames(_ name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        for entry in knownCompounds {
            if trimmed == entry.compound {
                return entry.parts
            }
        }

        if let range = trimmed.range(of: "和") {
            let left = String(trimmed[..<range.lowerBound])
            let right = String(trimmed[range.upperBound...])
            let merged = expandNames(left) + expandNames(right)
            if merged.count > 1 { return merged }
        }

        let separators = CharacterSet(charactersIn: "、,，/")
        if trimmed.unicodeScalars.contains(where: separators.contains) {
            let parts = trimmed
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.count > 1 {
                return parts.flatMap { expandNames($0) }
            }
        }

        return [trimmed]
    }

    static func expandRecords(_ records: [MemoryRecord]) -> [MemoryRecord] {
        records.flatMap { expandRecord($0) }
    }

    static func expandRecord(_ record: MemoryRecord) -> [MemoryRecord] {
        if record.isExpanded { return [record] }
        let names = expandNames(record.title)
        guard names.count > 1 else { return [record] }

        return names.enumerated().map { index, name in
            var expanded = MemoryRecord(
                id: index == 0 ? record.id : UUID(),
                title: name,
                details: record.details,
                category: record.category,
                tags: record.tags,
                placeDescription: record.placeDescription,
                dueDate: record.dueDate,
                isArchived: record.isArchived,
                isExpanded: true,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            return expanded
        }
    }

    static func joinedNames(from records: [MemoryRecord]) -> String {
        records.map(\.title).joined(separator: "、")
    }
}
