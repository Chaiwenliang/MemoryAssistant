import SwiftUI

/// 提问结果下的可点选记录：点「改位置 / 改状态」更新。
struct QueryResultRecordActions: View {
    let records: [MemoryRecord]
    let onChangeLocation: (MemoryRecord) -> Void
    let onChangeStatus: (MemoryRecord) -> Void

    private var uniqueRecords: [MemoryRecord] {
        var seen = Set<UUID>()
        return records.filter { seen.insert($0.id).inserted }
    }

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        VStack(alignment: .leading, spacing: 8) {
            AppTheme.sectionTitle("相关记录")

            ForEach(uniqueRecords.prefix(10)) { record in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconName(for: record))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accentColor(for: record))
                            .frame(width: 36, height: 36)
                            .background(
                                accentColor(for: record).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(colors.primaryText)
                            if let place = record.placeDescription, !place.isEmpty {
                                Text(place)
                                    .font(.caption)
                                    .foregroundStyle(colors.secondaryText)
                            } else if let due = record.dueDate {
                                Text(due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(colors.secondaryText)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        actionButton("改位置", icon: "mappin.and.ellipse", tint: colors.accent) {
                            onChangeLocation(record)
                        }
                        actionButton("改状态", icon: "arrow.triangle.2.circlepath", tint: .orange) {
                            onChangeStatus(record)
                        }
                    }
                }
                .padding(14)
                .elevatedCardSurface(radius: 12)
            }
        }
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(tint)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func accentColor(for record: MemoryRecord) -> Color {
        if record.placeDescription != nil { return .blue }
        if record.dueDate != nil { return .orange }
        return .green
    }

    private func iconName(for record: MemoryRecord) -> String {
        if record.placeDescription != nil { return "mappin.and.ellipse" }
        if record.dueDate != nil { return "calendar" }
        return "text.quote"
    }
}

struct RecordLocationUpdateSheet: View {
    let record: MemoryRecord
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var place: String
    @FocusState private var isFocused: Bool

    init(record: MemoryRecord, onSave: @escaping (String) -> Void) {
        self.record = record
        self.onSave = onSave
        _place = State(initialValue: record.placeDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(record.title)
                        .font(.title3.weight(.semibold))
                } header: {
                    Text("物品")
                }

                Section {
                    TextField("新位置，如：客厅桌子", text: $place)
                        .font(.body)
                        .focused($isFocused)
                } header: {
                    Text("位置")
                } footer: {
                    Text("保存后将覆盖原来的位置信息。")
                        .font(.caption)
                }
            }
            .compactListSurface()
            .navigationTitle("改位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(place.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
        }
        .appLargeSheet()
    }
}

struct RecordStatusUpdateSheet: View {
    let record: MemoryRecord
    let onMarkUsed: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.primaryText)
                    if let place = record.placeDescription, !place.isEmpty {
                        Text("当前位置：\(place)")
                            .font(.subheadline)
                            .foregroundStyle(colors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .elevatedCardSurface(radius: 12)

                Button {
                    onMarkUsed()
                    dismiss()
                } label: {
                    Text("已用完 / 不再持有")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(ScaleButtonStyle())

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text("删除这条记录")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 8)
            .navigationTitle("改状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
