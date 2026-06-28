import Foundation

/// 记下前的整理预览：解析原文，结构化展示，确认后才入库。
struct OrganizedCapture {
    let rawText: String
    let records: [MemoryRecord]
    let summary: String
    let lines: [Line]
    let isValid: Bool

    struct Line: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }
}

enum MemoryCaptureOrganizer {
    static func organize(_ rawText: String) -> OrganizedCapture {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = MemoryDraftParser.draft(from: trimmed)
        let records = CompoundIngredientExpander.expandRecords([draft.makeRecord()])
        let summary = records.map(\.displaySummary).joined(separator: "；")

        guard draft.isValid else {
            return OrganizedCapture(
                rawText: trimmed,
                records: [],
                summary: trimmed,
                lines: [OrganizedCapture.Line(label: "提示", value: "没能理解这条内容，请补充位置、时间或更完整的描述。")],
                isValid: false
            )
        }

        var lines: [OrganizedCapture.Line] = []

        if records.count == 1, let record = records.first {
            lines.append(.init(label: "类型", value: categoryLabel(for: record)))
            lines.append(.init(label: "内容", value: record.title))
            if let place = record.placeDescription, !place.isEmpty {
                lines.append(.init(label: "位置", value: place))
            }
            if let due = record.dueDate {
                lines.append(.init(
                    label: "时间",
                    value: due.formatted(date: .abbreviated, time: .shortened)
                ))
            }
        } else {
            lines.append(.init(label: "类型", value: "物品组合"))
            lines.append(.init(label: "内容", value: summary))
            lines.append(.init(label: "条数", value: "\(records.count) 条"))
        }

        return OrganizedCapture(
            rawText: trimmed,
            records: records,
            summary: summary,
            lines: lines,
            isValid: true
        )
    }

    private static func categoryLabel(for record: MemoryRecord) -> String {
        if record.placeDescription != nil { return "位置" }
        if record.dueDate != nil { return "日程" }
        return "备忘"
    }
}
