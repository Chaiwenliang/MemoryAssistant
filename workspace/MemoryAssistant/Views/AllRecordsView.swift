import SwiftUI

struct AllRecordsView: View {
    @ObservedObject var store: MemoryStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var theme: AppTheme.ThemePreference = .system

    @State private var expandedGroupIDs: Set<String> = []
    @State private var searchText: String = ""
    @State private var selectedCategory: FilterCategory = .all

    enum FilterCategory: String, CaseIterable, Identifiable {
        case all = "全部"
        case place = "位置"
        case schedule = "日程"
        case note = "备忘"
        var id: String { rawValue }
    }

    private var sourceRecords: [MemoryRecord] {
        store.activeRecords
    }

    private var filteredRecords: [MemoryRecord] {
        let records = sourceRecords
        let categoryFiltered: [MemoryRecord]
        switch selectedCategory {
        case .place: categoryFiltered = records.filter { $0.placeDescription != nil }
        case .schedule: categoryFiltered = records.filter { $0.dueDate != nil }
        case .note: categoryFiltered = records.filter { $0.placeDescription == nil && $0.dueDate == nil }
        case .all: categoryFiltered = records
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return categoryFiltered
        }
        let keyword = searchText.lowercased()
        return categoryFiltered.filter { record in
            record.title.lowercased().contains(keyword)
                || (record.placeDescription?.lowercased().contains(keyword) ?? false)
                || (!record.details.isEmpty && record.details.lowercased().contains(keyword))
        }
    }

    private var stats: MemoryDashboardStats {
        MemoryDashboardStats.from(sourceRecords)
    }

    private var currentScheme: AppTheme.VisualScheme {
        switch theme {
        case .warm: return .warm
        case .classic: return .classic
        case .glass: return .glass
        case .system: return .warm
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statsRow

                searchAndFilterBar

                if !filteredRecords.isEmpty {
                    recordsSection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(ThemeColor.pageBackground(for: currentScheme).ignoresSafeArea())
        .environment(\.currentTheme, currentScheme)
        .navigationTitle("全部记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ThemeColor.accent(for: currentScheme))
            }
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                TextField("搜索标题、位置或备忘", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.6))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .appCard(radius: 16)

            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterCategory.allCases) { cat in
                        let isActive = selectedCategory == cat
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.subheadline.weight(isActive ? .semibold : .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .foregroundStyle(isActive ? .white : ThemeColor.secondaryText(for: currentScheme))
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isActive ? ThemeColor.accent(for: currentScheme) : ThemeColor.cardSurface(for: currentScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isActive ? ThemeColor.accent(for: currentScheme).opacity(0.6) : ThemeColor.cardBorder(for: currentScheme), lineWidth: 0.6)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statChip("\(stats.total)", label: "全部")
            statChip("\(stats.locationCount)", label: "位置", color: ThemeColor.place(for: currentScheme))
            statChip("\(stats.scheduleCount)", label: "日程", color: ThemeColor.schedule(for: currentScheme))
            statChip("\(stats.noteCount)", label: "备忘", color: ThemeColor.note(for: currentScheme))
        }
    }

    private func statChip(_ value: String, label: String, color: Color = ThemeColor.accent()) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appCard(radius: 14)
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全部 \(filteredRecords.count) 条")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                Spacer()
            }

            LazyVStack(spacing: 8) {
                ForEach(MemoryRecordOrganizer.group(filteredRecords)) { group in
                    if group.itemCount == 1, let record = group.records.first {
                        recordRow(record)
                    } else {
                        groupCard(group)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.5))
                .padding(.top, 40)
            Text(searchText.isEmpty ? "还没有记录" : "没有匹配的记录")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private func recordRow(_ record: MemoryRecord) -> some View {
        NavigationLink {
            MemoryDetailView(store: store, recordID: record.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconName(for: record))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accentColor(for: record))
                    .frame(width: 40, height: 40)
                    .background(
                        accentColor(for: record).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                        .lineLimit(2)
                    if let secondary = secondaryText(for: record) {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .appCard(radius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func groupCard(_ group: MemoryRecordGroup) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        VStack(spacing: 0) {
            Button(action: { toggleGroup(group.id) }) {
                HStack(spacing: 14) {
                    Image(systemName: groupIcon(for: group))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ThemeColor.accent(for: currentScheme))
                        .frame(width: 40, height: 40)
                        .background(
                            ThemeColor.accent(for: currentScheme).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(group.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                            Text("\(group.itemCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ThemeColor.accent(for: currentScheme), in: Capsule())
                        }
                        Text(group.subtitle)
                            .font(.caption)
                            .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(ScaleButtonStyle())

            if isExpanded {
                Rectangle()
                    .fill(ThemeColor.cardBorder(for: currentScheme))
                    .frame(height: 0.5)
                    .padding(.leading, 70)

                ForEach(group.records) { record in
                    NavigationLink {
                        MemoryDetailView(store: store, recordID: record.id)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(ThemeColor.accent(for: currentScheme).opacity(0.3))
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.title)
                                    .font(.subheadline)
                                    .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                                if let place = record.placeDescription, !place.isEmpty {
                                    Text(place)
                                        .font(.caption)
                                        .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .padding(.leading, 54)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .appCard(radius: 14)
    }

    private func toggleGroup(_ id: String) {
        if expandedGroupIDs.contains(id) {
            expandedGroupIDs.remove(id)
        } else {
            expandedGroupIDs.insert(id)
        }
    }

    private func iconName(for record: MemoryRecord) -> String {
        if record.placeDescription != nil { return "mappin.and.ellipse" }
        if record.dueDate != nil { return "calendar" }
        return "text.quote"
    }

    private func groupIcon(for group: MemoryRecordGroup) -> String {
        if group.title.contains("位置") { return "mappin.and.ellipse" }
        if group.title.contains("日程") || group.title.contains("时间") { return "calendar" }
        return "text.quote"
    }

    private func accentColor(for record: MemoryRecord) -> Color {
        if record.placeDescription != nil { return ThemeColor.place(for: currentScheme) }
        if record.dueDate != nil { return ThemeColor.schedule(for: currentScheme) }
        return ThemeColor.note(for: currentScheme)
    }

    private func secondaryText(for record: MemoryRecord) -> String? {
        if let place = record.placeDescription, !place.isEmpty { return place }
        if let due = record.dueDate { return due.formatted(date: .abbreviated, time: .shortened) }
        return nil
    }
}
