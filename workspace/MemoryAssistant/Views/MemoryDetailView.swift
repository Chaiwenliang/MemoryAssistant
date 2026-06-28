import SwiftUI

struct MemoryDetailView: View {
    @ObservedObject var store: MemoryStore
    let recordID: UUID

    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    private var record: MemoryRecord? {
        store.record(id: recordID)
    }

    var body: some View {
        Group {
            if let record {
                List {
                    Section {
                        Text(record.displaySummary)
                            .font(.title3.weight(.medium))
                    }

                    Section("原始内容") {
                        Text(record.details.isEmpty ? record.title : record.details)
                    }

                    if let placeDescription = record.placeDescription, !placeDescription.isEmpty {
                        Section("位置") {
                            Text(placeDescription)
                        }
                    }

                    if let dueDate = record.dueDate, record.category == .schedule {
                        Section("时间") {
                            Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                .compactListSurface()
                .navigationTitle("详情")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("纠正") {
                            isEditing = true
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("删除", role: .destructive) {
                            store.delete(record)
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $isEditing) {
                    MemoryFormView(existingRecord: record) { updatedRecord in
                        store.update(updatedRecord)
                    }
                }
            } else {
                ContentUnavailableView("记录不存在", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
