import Foundation

/// 记忆助手的核心逻辑：Siri 与 App 共用同一套录入、检索与回答能力。
enum MemoryBrain {
    // MARK: - 录入

    /// 仅解析文本，不读写磁盘。
    static func parseRecords(from rawText: String) throws -> [MemoryRecord] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MemoryBrainError.emptyInput
        }

        let draft = MemoryDraftParser.draft(from: trimmed)
        let baseRecord = draft.makeRecord()
        return CompoundIngredientExpander.expandRecords([baseRecord])
    }

    /// Siri 等无 MemoryStore 场景：与 App 共用 `MemoryRecordIO` 写入。
    static func capture(from rawText: String) throws -> [MemoryRecord] {
        try MemoryRecordIO.appendFromText(rawText)
    }

    static func captureConfirmation(for records: [MemoryRecord]) -> String {
        if records.count == 1 {
            return "已记下。\(records[0].spokenAnswer())"
        }
        let place = records.first?.placeDescription ?? ""
        let names = records.map(\.title).joined(separator: "、")
        if place.isEmpty {
            return "已记下：\(names)。"
        }
        return "已记下：\(names) 在 \(place)。"
    }

    static func captureConfirmation(for record: MemoryRecord) -> String {
        captureConfirmation(for: [record])
    }

    // MARK: - 查询

    static func answer(question: String, in records: [MemoryRecord]? = nil) -> MemoryQueryResult {
        let source = (records ?? loadRecords()).activeOnly
        let normalized = normalizeQuestion(question)

        switch MemoryQueryRouter.intent(for: normalized) {
        case .scheduleTomorrow:
            return tomorrowAnswer(from: source)
        case .scheduleToday:
            return todayAnswer(from: source)
        case .cookingAdvice:
            return CookingAdvisor.advise(question: normalized, records: source)
        case .reverseLocation:
            if let reverseLocation = reverseLocationAnswer(question: normalized, from: source) {
                return reverseLocation
            }
            if let inventory = MemoryInventoryAnswer.answer(question: normalized, in: source) {
                return inventory
            }
            return notFoundAnswer(for: normalized)
        case .forwardLocation, .general:
            if let inventory = MemoryInventoryAnswer.answer(question: normalized, in: source) {
                return inventory
            }
            break
        }

        let matches = MemorySearchEngine.search(query: normalized, in: source)
        guard let best = matches.first else {
            return notFoundAnswer(for: normalized)
        }

        return MemoryQueryResult(
            found: true,
            answer: "根据你的记录：\(best.spokenAnswer(for: normalized))",
            records: matches
        )
    }

    // MARK: - 日程

    static func tomorrowSummary(from records: [MemoryRecord]? = nil) -> String {
        tomorrowAnswer(from: records ?? loadRecords()).answer
    }

    // MARK: - 持久化

    static func loadRecords() -> [MemoryRecord] {
        MemoryRecordIO.loadNormalizedSafe()
    }

    static func persist(_ record: MemoryRecord) throws {
        try MemoryRecordIO.updateRecord(record)
    }

    static func deleteRecord(id: UUID) throws {
        try MemoryRecordIO.deleteRecord(id: id)
    }

    // MARK: - Private

    private static func tomorrowAnswer(from records: [MemoryRecord]) -> MemoryQueryResult {
        let schedules = MemorySearchEngine.tomorrowSchedules(from: records)
        guard !schedules.isEmpty else {
            return MemoryQueryResult(
                found: false,
                answer: "明天暂时没有已记录的安排。",
                records: []
            )
        }

        let summary = formatScheduleList(schedules)
        return MemoryQueryResult(
            found: true,
            answer: "根据你的记录，明天有：\(summary)。",
            records: schedules
        )
    }

    private static func todayAnswer(from records: [MemoryRecord]) -> MemoryQueryResult {
        let schedules = MemorySearchEngine.todaySchedules(from: records)
        guard !schedules.isEmpty else {
            return MemoryQueryResult(
                found: false,
                answer: "今天暂时没有已记录的安排。",
                records: []
            )
        }

        let summary = formatScheduleList(schedules)
        return MemoryQueryResult(
            found: true,
            answer: "根据你的记录，今天有：\(summary)。",
            records: schedules
        )
    }

    private static func formatScheduleList(_ schedules: [MemoryRecord]) -> String {
        schedules.prefix(5).map { record in
            let timeText = record.dueDate?.formatted(date: .omitted, time: .shortened) ?? "未定时间"
            return "\(timeText) \(record.title)"
        }
        .joined(separator: "；")
    }

    private static func normalizeQuestion(_ question: String) -> String {
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
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func notFoundAnswer(for question: String) -> MemoryQueryResult {
        let keyword = MemorySearchEngine.primarySearchTerm(from: question)
        return MemoryQueryResult(
            found: false,
            answer: "我还没有找到和「\(keyword)」相关的记录。你可以先说「用记忆助手记录 …」把它记下来。",
            records: []
        )
    }

    private static func reverseLocationAnswer(question: String, from records: [MemoryRecord]) -> MemoryQueryResult? {
        let matches = MemorySearchEngine.reverseLocationSearch(query: question, in: records)
        guard !matches.isEmpty else { return nil }

        let placeName = MemorySearchEngine.extractLocationPhrase(from: question)
        let items = matches
            .map { MemorySearchEngine.displayItemName(for: $0, locationPhrase: placeName) }
            .flatMap { CompoundIngredientExpander.expandNames($0) }
            .joined(separator: "、")

        return MemoryQueryResult(
            found: true,
            answer: MemorySearchEngine.formatReverseLocationAnswer(place: placeName, items: items),
            records: matches
        )
    }
}

struct MemoryQueryResult {
    enum AnswerSource {
        case rules
        case llm
    }

    let found: Bool
    let answer: String
    let records: [MemoryRecord]
    var source: AnswerSource = .rules
}

enum MemoryBrainError: LocalizedError {
    case emptyInput
    case invalidCapture(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "没有听到可记录的内容。"
        case .invalidCapture(let message):
            return message
        }
    }
}
