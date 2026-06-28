import SwiftUI

// MARK: - 首页顶栏

struct HomeTopBar: View {
    let stats: MemoryDashboardStats
    var showsProBadge: Bool
    let onSettings: () -> Void
    let onShowAllRecords: () -> Void

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        VStack(alignment: .leading, spacing: 16) {
            // 标题 + 齿轮按钮
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("记忆助手")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(colors.primaryText)
                        .tracking(-0.5)
                    Text("问问你的生活记录")
                        .font(.subheadline)
                        .foregroundStyle(colors.secondaryText)
                }
                Spacer(minLength: 12)
                GlassIconButton(
                    systemName: "gearshape",
                    showsProBadge: showsProBadge,
                    action: onSettings
                )
            }

            // 记忆图谱卡片
            Button(action: onShowAllRecords) {
                HStack(spacing: 16) {
                    MemoryDonutChart(stats: stats, size: 64)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("记忆图谱")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colors.primaryText)
                        MemoryStatsLegend(stats: stats)
                        Text("查看全部 \(stats.total) 条记录")
                            .font(.caption)
                            .foregroundStyle(colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colors.secondaryText.opacity(0.6))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .appCard()
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("查看全部记录")
        }
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

// MARK: - 首页空状态

struct HomeEmptyPrompt: View {
    let inputMode: BottomInputMode
    var recentRecords: [MemoryRecord] = []
    var onExampleTap: ((String) -> Void)?
    var onShowAllRecords: (() -> Void)?

    @Environment(\.currentTheme) private var currentTheme

    private var examples: [String] {
        switch inputMode {
        case .ask:
            return ["家里有葱吗？", "钥匙放哪了？", "明天有什么事？", "冰箱有什么？"]
        case .capture:
            return ["西瓜放冰箱", "钥匙在玄关", "周五交报告", "洗衣液阳台柜子"]
        }
    }

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // 示例问句区
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(inputMode == .ask ? "有什么想问的？" : "想记点什么？")
                            .font(.headline)
                            .foregroundStyle(colors.primaryText)
                        Text(inputMode == .ask ? "点示例直接提问，或长按输入框语音" : "点示例填入，确认后入库")
                            .font(.subheadline)
                            .foregroundStyle(colors.secondaryText)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(examples, id: \.self) { example in
                            ExampleChip(text: example) {
                                onExampleTap?(example)
                            }
                        }
                    }
                }

                // 最近记录区
                if !recentRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("最近更新")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(colors.secondaryText)
                            Spacer()
                            if onShowAllRecords != nil {
                                Button {
                                    onShowAllRecords?()
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("全部")
                                            .font(.caption.weight(.semibold))
                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(colors.accent)
                                }
                            }
                        }

                        VStack(spacing: 8) {
                            ForEach(recentRecords) { record in
                                HomeRecentRecordRow(record: record)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .homeScrollContentInsets()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 子组件

private struct ExampleChip: View {
    let text: String
    let action: () -> Void

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        Button(action: action) {
            HStack(alignment: .center) {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(colors.accent.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .appCard(radius: AppTheme.chipRadius)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct HomeRecentRecordRow: View {
    let record: MemoryRecord

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 40, height: 40)
                .background(
                    accentColor.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(1)
                if let secondary = secondaryText {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colors.secondaryText.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .appCard(radius: 14)
    }

    private var secondaryText: String? {
        if let place = record.placeDescription, !place.isEmpty { return place }
        if let due = record.dueDate {
            return due.formatted(date: .abbreviated, time: .shortened)
        }
        return nil
    }

    private var accentColor: Color {
        if record.placeDescription != nil { return ThemeColor.place(for: currentTheme) }
        if record.dueDate != nil { return ThemeColor.schedule(for: currentTheme) }
        return ThemeColor.note(for: currentTheme)
    }

    private var iconName: String {
        if record.placeDescription != nil { return "mappin.and.ellipse" }
        if record.dueDate != nil { return "calendar" }
        return "text.quote"
    }
}
