import Foundation

struct MemoryRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var details: String
    var category: MemoryCategory
    var tags: [String]
    var placeDescription: String?
    var dueDate: Date?
    var isArchived: Bool
    var isExpanded: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        category: MemoryCategory,
        tags: [String] = [],
        placeDescription: String? = nil,
        dueDate: Date? = nil,
        isArchived: Bool = false,
        isExpanded: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.tags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.placeDescription = placeDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dueDate = dueDate
        self.isArchived = isArchived
        self.isExpanded = isExpanded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        category = try container.decode(MemoryCategory.self, forKey: .category)
        tags = try container.decode([String].self, forKey: .tags)
        placeDescription = try container.decodeIfPresent(String.self, forKey: .placeDescription)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var subtitle: String {
        displaySummary
    }

    /// 统一展示文案，不暴露内部分类。
    var displaySummary: String {
        if let placeDescription, !placeDescription.isEmpty {
            return "\(title) · \(placeDescription)"
        }
        if let dueDate {
            return "\(title) · \(Self.dateFormatter.string(from: dueDate))"
        }
        if !details.isEmpty, details != title {
            return details
        }
        return title
    }

    var searchableText: String {
        var parts = [
            title,
            details,
            placeDescription ?? "",
            tags.joined(separator: " ")
        ]

        if let dueDate {
            parts.append(Self.dateFormatter.string(from: dueDate))
            parts.append(contentsOf: Self.searchTokens(for: dueDate))
        }

        return parts
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func searchTokens(for date: Date, calendar: Calendar = .current) -> [String] {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        var tokens = ["\(hour)点", "\(hour):\(String(format: "%02d", minute))"]

        if hour >= 12 {
            tokens.append("下午")
            let hour12 = hour == 12 ? 12 : hour - 12
            tokens.append("\(hour12)点")
        } else if hour < 6 {
            tokens.append("凌晨")
        } else {
            tokens.append("上午")
        }

        return tokens
    }

    func spokenAnswer(for query: String? = nil) -> String {
        if let placeDescription, !placeDescription.isEmpty {
            return "\(title) 在 \(placeDescription)。"
        }
        if let dueDate {
            let timeText = Self.dateFormatter.string(from: dueDate)
            return "\(title) 的时间是 \(timeText)。"
        }
        if !details.isEmpty {
            return details.hasPrefix(title) ? details : "\(title)。\(details)"
        }
        return title
    }

    func isOnSameDay(as date: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        return calendar.isDate(dueDate, inSameDayAs: date)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, category, tags, placeDescription, dueDate, isArchived, isExpanded, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(placeDescription, forKey: .placeDescription)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
