import Foundation

enum MemoryPersistence {
    private static let folderName = "MemoryAssistant"
    private static let fileName = "records.json"

    static func load() throws -> [MemoryRecord] {
        let url = try recordsURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MemoryRecord].self, from: data)
    }

    static func save(_ records: [MemoryRecord]) throws {
        let url = try recordsURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: url, options: .atomic)
    }

    static func safeLoad() -> [MemoryRecord] {
        (try? load()) ?? []
    }

    private static func recordsURL() throws -> URL {
        let fileManager = FileManager.default
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folderURL = baseURL.appendingPathComponent(folderName, isDirectory: true)

        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        return folderURL.appendingPathComponent(fileName)
    }
}

/// Siri 与 App 共用的读写入口：加载时统一 normalize，写入时走同一条路径。
enum MemoryRecordIO {
    static func loadNormalized() throws -> [MemoryRecord] {
        var loaded = try MemoryPersistence.load()
        let result = MemoryRecordOrganizer.normalizeAll(loaded)
        loaded = result.records
        if result.changedCount > 0 {
            try MemoryPersistence.save(loaded)
        }
        return loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func loadNormalizedSafe() -> [MemoryRecord] {
        (try? loadNormalized()) ?? []
    }

    @discardableResult
    static func appendFromText(_ text: String) throws -> [MemoryRecord] {
        let parsed = try MemoryBrain.parseRecords(from: text)
        let withDetails = parsed.map { record -> MemoryRecord in
            var copy = record
            if copy.details.isEmpty {
                copy.details = text
            }
            return copy
        }
        return try appendRecords(withDetails)
    }

    static func prepareForPersistence(_ records: [MemoryRecord]) -> [MemoryRecord] {
        records.map { record in
            var normalized = MemoryRecordOrganizer.normalize(record)
            if !record.details.isEmpty {
                normalized.details = record.details
            } else if normalized.details.isEmpty {
                normalized.details = record.title
            }
            return normalized
        }
    }

    @discardableResult
    static func appendRecords(_ newRecords: [MemoryRecord]) throws -> [MemoryRecord] {
        guard !newRecords.isEmpty else { return [] }
        let prepared = prepareForPersistence(newRecords)
        var all = try loadNormalized()
        for record in prepared {
            all.insert(record, at: 0)
        }
        all.sort { $0.updatedAt > $1.updatedAt }
        try MemoryPersistence.save(all)
        return prepared
    }

    static func saveAll(_ records: [MemoryRecord]) throws {
        try MemoryPersistence.save(records)
    }

    static func updateRecord(_ record: MemoryRecord) throws {
        var all = try loadNormalized()
        if let index = all.firstIndex(where: { $0.id == record.id }) {
            all[index] = record
        } else {
            all.insert(record, at: 0)
        }
        all.sort { $0.updatedAt > $1.updatedAt }
        try MemoryPersistence.save(all)
    }

    static func deleteRecord(id: UUID) throws {
        var all = try loadNormalized()
        all.removeAll { $0.id == id }
        try MemoryPersistence.save(all)
    }
}
