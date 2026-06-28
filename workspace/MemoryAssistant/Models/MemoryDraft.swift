import Foundation

struct MemoryDraft {
    var title: String = ""
    var details: String = ""
    var category: MemoryCategory = .note
    var tagsText: String = ""
    var placeDescription: String = ""
    var dueDate: Date = Date()
    var hasDueDate: Bool = false

    init() {}

    init(record: MemoryRecord) {
        title = record.title
        details = record.details
        category = record.category
        tagsText = record.tags.joined(separator: ", ")
        placeDescription = record.placeDescription ?? ""
        if let dueDate = record.dueDate {
            self.dueDate = dueDate
            hasDueDate = true
        }
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func applyParsedDraft(_ parsed: MemoryDraft) {
        if !parsed.title.isEmpty {
            title = parsed.title
        }

        if !parsed.details.isEmpty {
            details = parsed.details
        }

        category = parsed.category

        if !parsed.placeDescription.isEmpty {
            placeDescription = parsed.placeDescription
        }

        hasDueDate = parsed.hasDueDate
        if parsed.hasDueDate {
            dueDate = parsed.dueDate
        }
    }

    func makeRecord(from existing: MemoryRecord? = nil) -> MemoryRecord {
        let tags = tagsText
            .replacingOccurrences(of: "，", with: ",")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return MemoryRecord(
            id: existing?.id ?? UUID(),
            title: title,
            details: details,
            category: category,
            tags: tags,
            placeDescription: placeDescription.isEmpty ? nil : placeDescription,
            dueDate: hasDueDate ? dueDate : nil,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}
