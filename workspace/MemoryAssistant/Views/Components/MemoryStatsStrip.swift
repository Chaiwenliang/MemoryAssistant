import SwiftUI

/// 首页概览：环形图 + 分类图例；支持分类点击。
struct MemoryStatsStrip: View {
    let stats: MemoryDashboardStats
    var compact: Bool = false
    var embedded: Bool = false
    var onTap: (() -> Void)?
    /// 分类点击回调（传入"位置"/"日程"/"备忘"）
    var onTapCategory: ((String) -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            if embedded {
                embeddedBody
            } else if compact {
                compactBody
            } else {
                regularBody
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("查看记忆图谱")
    }

    private var embeddedBody: some View {
        HStack(spacing: 8) {
            MemoryDonutChart(stats: stats, size: 36, ringWidth: 5)

            MemoryStatsLegend(stats: stats, onTapCategory: onTapCategory)
                .frame(maxWidth: .infinity, alignment: .leading)
                .highPriorityGesture(TapGesture().onEnded { /* 由 MemoryStatsLegend 内部处理 */ })

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 4)
    }

    private var compactBody: some View {
        HStack(spacing: 12) {
            MemoryDonutChart(stats: stats, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("记忆图谱")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                MemoryStatsLegend(stats: stats, onTapCategory: onTapCategory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .elevatedCardSurface(radius: 12)
    }

    private var regularBody: some View {
        HStack(spacing: 14) {
            MemoryDonutChart(stats: stats, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("记忆图谱")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                MemoryStatsLegend(stats: stats, compact: false, onTapCategory: onTapCategory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .elevatedCardSurface(radius: 16)
    }
}
