import SwiftUI

/// 记忆分类环形图：纯图形概览，中心不显示数字。
struct MemoryDonutChart: View {
    let stats: MemoryDashboardStats
    var size: CGFloat = 52
    var ringWidth: CGFloat = 6.5

    private struct Segment: Identifiable {
        let id = UUID()
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private struct CategoryItem {
        let count: Int
        let label: String
        let color: Color
    }

    private var segments: [Segment] {
        guard stats.total > 0 else { return [] }
        let total = CGFloat(stats.total)
        var cursor: CGFloat = 0
        var result: [Segment] = []
        let items: [(Int, Color)] = [
            (stats.locationCount, .blue),
            (stats.scheduleCount, .orange),
            (stats.noteCount, .green)
        ]
        for (count, color) in items where count > 0 {
            let fraction = CGFloat(count) / total
            result.append(Segment(start: cursor, end: cursor + fraction, color: color))
            cursor += fraction
        }
        return result
    }

    private var categories: [CategoryItem] {
        [
            CategoryItem(count: stats.locationCount, label: "位置", color: .blue),
            CategoryItem(count: stats.scheduleCount, label: "日程", color: .orange),
            CategoryItem(count: stats.noteCount, label: "备忘", color: .green)
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: ringWidth)

            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.color.opacity(0.92),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Image(systemName: stats.total > 0 ? "chart.pie.fill" : "tray")
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(stats.total > 0 ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.5))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statsOverviewAccessibilityLabel)
    }

    private var statsOverviewAccessibilityLabel: String {
        guard stats.total > 0 else { return "暂无记录" }
        return categories
            .filter { $0.count > 0 }
            .map { "\($0.label) \($0.count) 条" }
            .joined(separator: "，")
    }
}

/// 分类图例：标签与色点；支持分类点击。
struct MemoryStatsLegend: View {
    let stats: MemoryDashboardStats
    var compact: Bool = true
    var onTapCategory: ((_ label: String) -> Void)?

    private struct CategoryItem: Identifiable {
        let id: String
        let count: Int
        let label: String
        let color: Color
    }

    private var categories: [CategoryItem] {
        [
            CategoryItem(id: "place", count: stats.locationCount, label: "位置", color: .blue),
            CategoryItem(id: "schedule", count: stats.scheduleCount, label: "日程", color: .orange),
            CategoryItem(id: "note", count: stats.noteCount, label: "备忘", color: .green)
        ]
    }

    var body: some View {
        HStack(spacing: compact ? 0 : 8) {
            ForEach(Array(categories.enumerated()), id: \.offset) { index, item in
                legendItem(item)
                if compact, index < categories.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func legendItem(_ item: CategoryItem) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(item.count > 0 ? item.color : Color(.tertiarySystemFill))
                .frame(width: 5, height: 5)
            Text(item.label)
                .font(.caption2)
                .foregroundStyle(item.count > 0 ? .secondary : .tertiary)
        }
        .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.count > 0 ? "\(item.label)有记录" : "\(item.label)暂无")
        .contentShape(Rectangle())
        .onTapGesture {
            onTapCategory?(item.label)
        }
    }
}
