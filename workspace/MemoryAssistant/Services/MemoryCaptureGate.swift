import Foundation

/// 入库闸门：标题/位置必须是结构化字段，不能是整句描述。
enum MemoryCaptureGate {
    static func canSave(_ state: CaptureEditState) -> Bool {
        message(for: state) == nil
    }

    static func canSaveRecord(_ record: MemoryRecord) -> Bool {
        recordMessage(for: record) == nil
    }

    static func message(for state: CaptureEditState) -> String? {
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = state.placeDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            return "请填写要记下的内容"
        }
        if MemoryDraftParser.looksLikeSentence(title) {
            return "内容请只填物品或事项名，不要用整句话"
        }

        if state.isUpdatingExisting {
            if place.isEmpty {
                return "请填写新位置以更新这条记录"
            }
            if MemoryDraftParser.looksLikeSentence(place) {
                return "位置请只填地点，不要用整句话"
            }
            return nil
        }

        if state.hasDueDate {
            return nil
        }

        if !place.isEmpty {
            if MemoryDraftParser.looksLikeSentence(place) {
                return "位置请只填地点，不要用整句话"
            }
            return nil
        }

        return nil
    }

    static func recordMessage(for record: MemoryRecord) -> String? {
        let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return "内容不能为空"
        }
        if MemoryDraftParser.looksLikeSentence(title) {
            return "内容请只填物品或事项名"
        }

        if let place = record.placeDescription, !place.isEmpty {
            if MemoryDraftParser.looksLikeSentence(place) {
                return "位置请只填地点"
            }
        } else if record.category == .location {
            return "位置类记录缺少地点"
        }

        return nil
    }
}
