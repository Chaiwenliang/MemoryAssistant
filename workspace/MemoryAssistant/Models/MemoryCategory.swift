import Foundation

enum MemoryCategory: String, CaseIterable, Codable, Identifiable {
    case location
    case schedule
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return "位置记忆"
        case .schedule:
            return "日程安排"
        case .note:
            return "通用备忘"
        }
    }

    var systemImage: String {
        switch self {
        case .location:
            return "mappin.and.ellipse"
        case .schedule:
            return "calendar.badge.clock"
        case .note:
            return "note.text"
        }
    }
}
