import Foundation

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var records: [MemoryRecord] = []
    @Published var errorMessage: String?

    init() {
        load()
    }

    func load() {
        do {
            records = try MemoryRecordIO.loadNormalized()
            errorMessage = nil
        } catch {
            records = []
            errorMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
    }

    func reload() {
        load()
    }

    @discardableResult
    func organizeRecords() -> Int {
        let result = MemoryRecordOrganizer.normalizeAll(records)
        records = result.records.sorted { $0.updatedAt > $1.updatedAt }
        persist()
        return result.changedCount
    }

    var activeRecords: [MemoryRecord] {
        records.filter { !$0.isArchived }
    }

    var archivedRecords: [MemoryRecord] {
        records.filter { $0.isArchived }
    }

    func archive(_ record: MemoryRecord) {
        var updated = record
        updated.isArchived = true
        updated.updatedAt = Date()
        update(updated)
    }

    func unarchive(_ record: MemoryRecord) {
        var updated = record
        updated.isArchived = false
        updated.updatedAt = Date()
        update(updated)
    }

    func archiveRecords(_ recordsToArchive: [MemoryRecord]) {
        for record in recordsToArchive {
            archive(record)
        }
    }

    func moveRecord(_ record: MemoryRecord, to place: String) {
        var updated = record
        updated.placeDescription = place
        updated.updatedAt = Date()
        update(updated)
    }

    func add(_ record: MemoryRecord) {
        let expanded = CompoundIngredientExpander.expandRecords([record])
        for item in expanded {
            records.insert(item, at: 0)
        }
        persist()
    }

    func addFromText(_ text: String) throws -> [MemoryRecord] {
        let parsed = try MemoryRecordIO.appendFromText(text)
        syncRecords(with: parsed)
        errorMessage = nil
        return parsed
    }

    func saveFromCapture(_ state: CaptureEditState) throws -> [MemoryRecord] {
        guard state.canSave else {
            throw MemoryBrainError.invalidCapture(state.gateMessage ?? "请检查填写内容")
        }

        if state.existingRecordID != nil {
            let built = state.makeRecords()
            guard !built.isEmpty else {
                throw MemoryBrainError.invalidCapture("无法更新这条记录")
            }
            for record in built {
                if let message = MemoryCaptureGate.recordMessage(for: record) {
                    throw MemoryBrainError.invalidCapture(message)
                }
            }
            let prepared = MemoryRecordIO.prepareForPersistence(built)
            var saved: [MemoryRecord] = []
            for (index, record) in prepared.enumerated() {
                if index == 0 {
                    update(record)
                    saved.append(record)
                } else {
                    records.insert(record, at: 0)
                    saved.append(record)
                }
            }
            persist()
            if let first = prepared.first {
                archiveDuplicates(for: first.title, keeping: first.id)
            }
            errorMessage = nil
            return saved
        }

        let built = state.makeRecords()
        let prepared = MemoryRecordIO.prepareForPersistence(built)
        for record in prepared {
            if let message = MemoryCaptureGate.recordMessage(for: record) {
                throw MemoryBrainError.invalidCapture(message)
            }
        }

        let saved = try MemoryRecordIO.appendRecords(prepared)
        syncRecords(with: saved)
        errorMessage = nil
        return saved
    }

    private func archiveDuplicates(for title: String, keeping id: UUID) {
        let itemKey = MemoryDraftParser.extractCoreItemName(title).lowercased()
        let duplicates = activeRecords.filter { record in
            guard record.id != id else { return false }
            let recordTitle = record.title.lowercased()
            return recordTitle == itemKey || recordTitle.contains(itemKey) || itemKey.contains(recordTitle)
        }
        archiveRecords(duplicates)
    }

    @available(*, deprecated, renamed: "saveFromCapture")
    func addFromCapture(_ state: CaptureEditState) throws -> [MemoryRecord] {
        try saveFromCapture(state)
    }

    private func syncRecords(with newRecords: [MemoryRecord]) {
        for record in newRecords {
            records.removeAll { $0.id == record.id }
            records.insert(record, at: 0)
        }
        records.sort { $0.updatedAt > $1.updatedAt }
    }

    func update(_ record: MemoryRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        records.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func delete(_ record: MemoryRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func previewAnswer(for question: String) -> String {
        MemoryBrain.answer(question: question, in: records).answer
    }

    func record(id: UUID) -> MemoryRecord? {
        records.first { $0.id == id }
    }

    private func persist() {
        do {
            try MemoryRecordIO.saveAll(records)
            errorMessage = nil
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
