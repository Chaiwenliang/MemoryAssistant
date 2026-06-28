import Foundation

struct MemoryDashboardStats {
    let total: Int
    let locationCount: Int
    let scheduleCount: Int
    let noteCount: Int
    let groupCount: Int

    static func from(_ records: [MemoryRecord]) -> MemoryDashboardStats {
        let location = records.filter { $0.placeDescription != nil }.count
        let schedule = records.filter { $0.dueDate != nil && $0.placeDescription == nil }.count
        let note = records.filter { $0.placeDescription == nil && $0.dueDate == nil }.count
        let groups = MemoryRecordOrganizer.group(records)
        return MemoryDashboardStats(
            total: records.count,
            locationCount: location,
            scheduleCount: schedule,
            noteCount: note,
            groupCount: groups.count
        )
    }
}
