import AppIntents
import Foundation

struct MemoryAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "记录")
    static var defaultQuery = MemoryQuery()

    let id: UUID
    let title: String
    let summary: String

    init(record: MemoryRecord) {
        id = record.id
        title = record.title
        summary = record.subtitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")
    }
}

struct MemoryQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [MemoryAppEntity] {
        let records = MemoryBrain.loadRecords()
        return records
            .filter { identifiers.contains($0.id) }
            .map(MemoryAppEntity.init(record:))
    }

    func entities(matching string: String) async throws -> [MemoryAppEntity] {
        let records = MemoryBrain.answer(question: string).records
        if records.isEmpty {
            return Array(MemoryBrain.loadRecords().prefix(10)).map(MemoryAppEntity.init(record:))
        }
        return Array(records.prefix(10)).map(MemoryAppEntity.init(record:))
    }

    func suggestedEntities() async throws -> [MemoryAppEntity] {
        let records = MemoryBrain.loadRecords()
            .sorted { $0.updatedAt > $1.updatedAt }
        return Array(records.prefix(10)).map(MemoryAppEntity.init(record:))
    }
}
