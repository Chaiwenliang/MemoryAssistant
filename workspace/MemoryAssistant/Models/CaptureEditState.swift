import Foundation

/// 记下确认前的可编辑结构化草稿。
struct CaptureEditState: Equatable {
    var rawText: String
    var title: String
    var placeDescription: String
    var hasDueDate: Bool
    var dueDate: Date
    var existingRecordID: UUID?
    var previousPlaceDescription: String?

    var isUpdatingExisting: Bool {
        existingRecordID != nil
    }

    var gateMessage: String? {
        MemoryCaptureGate.message(for: self)
    }

    var canSave: Bool {
        MemoryCaptureGate.canSave(self)
    }

    var inferredCategory: MemoryCategory {
        if hasDueDate { return .schedule }
        if !placeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .location
        }
        return .note
    }

    var categoryLabel: String {
        if isUpdatingExisting { return "更新" }
        switch inferredCategory {
        case .location: return "位置"
        case .schedule: return "日程"
        case .note: return "备忘"
        }
    }

    static func from(rawText: String, existingRecords: [MemoryRecord] = []) -> CaptureEditState {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = MemoryDraftParser.draft(from: trimmed)
        var state = CaptureEditState(
            rawText: trimmed,
            title: MemoryDraftParser.extractCoreItemName(draft.title),
            placeDescription: draft.placeDescription,
            hasDueDate: draft.hasDueDate,
            dueDate: draft.dueDate,
            existingRecordID: nil,
            previousPlaceDescription: nil
        )

        if let existing = MemoryUpdateRouter.findExistingRecord(itemQuery: state.title, in: existingRecords) {
            state.existingRecordID = existing.id
            state.previousPlaceDescription = existing.placeDescription
        }

        return state
    }

    func makeRecords() -> [MemoryRecord] {
        if let existingID = existingRecordID {
            var draft = MemoryDraft()
            draft.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.details = rawText
            draft.category = inferredCategory
            draft.placeDescription = placeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.hasDueDate = hasDueDate
            if hasDueDate {
                draft.dueDate = dueDate
            }

            let placeholder = MemoryRecord(
                id: existingID,
                title: draft.title,
                details: draft.details,
                category: draft.category,
                placeDescription: draft.placeDescription.isEmpty ? nil : draft.placeDescription,
                dueDate: draft.hasDueDate ? draft.dueDate : nil
            )
            return [draft.makeRecord(from: placeholder)]
        }

        var draft = MemoryDraft()
        draft.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.details = rawText
        draft.category = inferredCategory
        draft.placeDescription = placeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.hasDueDate = hasDueDate
        if hasDueDate {
            draft.dueDate = dueDate
        }
        return CompoundIngredientExpander.expandRecords([draft.makeRecord()])
    }
}
