//
//  UIDesignPreview.swift
//  MemoryAssistant
//
//  三套 UI 设计方案预览 —— 直接在 Xcode Canvas 中对比效果。
//
//  方案 A · Minimal · 极简白灰（MUJI 风）
//  方案 B · Warm · 温暖暖橙（生活日记风）
//  方案 C · Glass · 玻璃磨砂（现代科技风）
//

import SwiftUI

// MARK: - 颜色系统

enum DesignScheme: String, CaseIterable, Identifiable {
    case minimal = "极简白灰"
    case warm = "温暖生活"
    case glass = "玻璃科技"
    var id: String { rawValue }

    var background: Color {
        switch self {
        case .minimal: return Color(red: 0.97, green: 0.97, blue: 0.96)
        case .warm:    return Color(red: 1.00, green: 0.96, blue: 0.91)
        case .glass:   return Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    var surface: Color {
        switch self {
        case .minimal: return Color.white
        case .warm:    return Color(red: 1.00, green: 0.98, blue: 0.94)
        case .glass:   return Color.white.opacity(0.08)
        }
    }

    var primary: Color {
        switch self {
        case .minimal: return Color(red: 0.20, green: 0.20, blue: 0.22)
        case .warm:    return Color(red: 0.80, green: 0.45, blue: 0.22)
        case .glass:   return Color(red: 0.40, green: 0.80, blue: 1.00)
        }
    }

    var accent: Color {
        switch self {
        case .minimal: return Color(red: 0.35, green: 0.35, blue: 0.38)
        case .warm:    return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .glass:   return Color(red: 1.00, green: 0.60, blue: 0.70)
        }
    }

    var text: Color {
        switch self {
        case .minimal: return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .warm:    return Color(red: 0.35, green: 0.22, blue: 0.15)
        case .glass:   return Color.white
        }
    }

    var secondaryText: Color {
        switch self {
        case .minimal: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .warm:    return Color(red: 0.60, green: 0.45, blue: 0.35)
        case .glass:   return Color.white.opacity(0.60)
        }
    }

    var divider: Color {
        switch self {
        case .minimal: return Color(red: 0.90, green: 0.90, blue: 0.88)
        case .warm:    return Color(red: 0.90, green: 0.75, blue: 0.58).opacity(0.5)
        case .glass:   return Color.white.opacity(0.10)
        }
    }

    /// 方案描述（对比时使用）
    var description: String {
        switch self {
        case .minimal: return "克制的留白、无阴影的线条描边、强调信息本身"
        case .warm:    return "奶油米白底、暖橙点缀、柔和阴影、生活手写感"
        case .glass:   return "深色底、毛玻璃叠层、霓虹高光、现代科技感"
        }
    }
}

// MARK: - 主题环境变量

private struct SchemeKey: EnvironmentKey {
    static let defaultValue: DesignScheme = .warm
}
extension EnvironmentValues {
    var designScheme: DesignScheme {
        get { self[SchemeKey.self] }
        set { self[SchemeKey.self] = newValue }
    }
}

// MARK: - 示例数据

private struct SampleRecord: Identifiable {
    let id = UUID()
    let title: String
    let place: String
    let time: String
    let kind: Kind
    enum Kind { case place, schedule, note }
}

private let sampleRecords: [SampleRecord] = [
    .init(title: "西瓜", place: "冰箱冷藏", time: "2 小时前", kind: .place),
    .init(title: "家门钥匙", place: "玄关柜抽屉", time: "昨天", kind: .place),
    .init(title: "周五交季度报告", place: "会议室 B", time: "6 月 20 日", kind: .schedule),
    .init(title: "朋友生日送的书", place: "书架第二层", time: "3 天前", kind: .note),
    .init(title: "洗衣凝珠", place: "阳台柜子", time: "上周", kind: .place)
]

private let sampleStats = (placeCount: 3, scheduleCount: 1, noteCount: 1)

// MARK: - 主对比页（3 套方案并排）

/// 三个方案的首页对比（最核心的视觉参考）。
struct UIDesignComparisonView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(DesignScheme.allCases) { scheme in
                        SchemePreviewCard(scheme: scheme)
                            .frame(width: max(320, geometry.size.width * 0.92))
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGray6))
        }
    }
}

// MARK: - 单个方案卡片（包含：Header + 内容 + 空状态 + 输入条）

private struct SchemePreviewCard: View {
    let scheme: DesignScheme

    var body: some View {
        VStack(spacing: 0) {
            schemeHeader
            Divider().foregroundStyle(scheme.divider)
            schemeContent
            Divider().foregroundStyle(scheme.divider)
            schemeInputBar
        }
        .frame(maxWidth: .infinity)
        .background(scheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: scheme == .glass ? 0.8 : 0.5)
        )
        .shadow(color: scheme == .minimal ? .black.opacity(0.04) : .black.opacity(0.12),
                radius: scheme == .minimal ? 6 : 18,
                y: scheme == .minimal ? 2 : 6)
        .padding(.horizontal, 4)
    }

    // ── Header ─────────────────────────────────────────
    private var schemeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(scheme.primary)
                    .frame(width: 8, height: 8)
                Text(scheme.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(scheme.text)
                Spacer()
                Text(scheme == .minimal ? "A" : scheme == .warm ? "B" : "C")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(scheme.secondaryText)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        Capsule().fill(scheme.divider)
                    )
            }
            Text(scheme.description)
                .font(.system(size: 11))
                .foregroundStyle(scheme.secondaryText)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // ── 内容区：统计条 + 记录列表 ─────────────────
    private var schemeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statsRow

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("最近更新")
                ForEach(sampleRecords.prefix(4)) { record in
                    recordRow(record)
                    if record.id != sampleRecords[sampleRecords.count - 1].id {
                        Rectangle()
                            .fill(scheme.divider)
                            .frame(height: 0.6)
                            .padding(.leading, 44)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("试试这样记")
                HStack(spacing: 8) {
                    ForEach(["西瓜放冰箱", "钥匙在玄关", "周五交报告"], id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12))
                            .foregroundStyle(scheme.text)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(scheme.primary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(scheme.divider, lineWidth: 0.6)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(title: "位置", count: sampleStats.placeCount)
            statPill(title: "日程", count: sampleStats.scheduleCount)
            statPill(title: "备忘", count: sampleStats.noteCount)
        }
    }

    private func statPill(title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(scheme.primary.opacity(0.35))
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(scheme.secondaryText)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(scheme.text)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .glass ? scheme.surface : scheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(scheme.secondaryText)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func recordRow(_ record: SampleRecord) -> some View {
        HStack(spacing: 12) {
            recordIcon(for: record.kind)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(scheme.text)
                HStack(spacing: 6) {
                    Text(record.place)
                        .font(.system(size: 11))
                        .foregroundStyle(scheme.secondaryText)
                    Text("·")
                        .foregroundStyle(scheme.secondaryText.opacity(0.5))
                    Text(record.time)
                        .font(.system(size: 11))
                        .foregroundStyle(scheme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(scheme.secondaryText.opacity(0.6))
        }
        .padding(.vertical, 4)
    }

    private func recordIcon(for kind: SampleRecord.Kind) -> some View {
        let color: Color = {
            switch scheme {
            case .minimal: return scheme.primary
            case .warm:    return kind == .schedule ? scheme.primary : scheme.accent
            case .glass:   return kind == .schedule ? scheme.accent : scheme.primary
            }
        }()
        let iconName: String = {
            switch kind {
            case .place: return "location.fill"
            case .schedule: return "calendar"
            case .note: return "note.text"
            }
        }()
        return Image(systemName: iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(scheme == .glass ? color.opacity(0.22) : color.opacity(0.12))
            )
            .overlay(
                Circle().strokeBorder(
                    scheme == .minimal ? scheme.divider : Color.clear,
                    lineWidth: scheme == .minimal ? 0.6 : 0
                )
            )
    }

    // ── 输入条 ────────────────────────────────────────
    private var schemeInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(scheme.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(scheme.primary.opacity(scheme == .glass ? 0.25 : 0.10))
                )

            Text("记下内容，长按语音输入")
                .font(.system(size: 13))
                .foregroundStyle(scheme.secondaryText)

            Spacer()

            Circle()
                .fill(scheme.primary)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(scheme == .glass ? Color.black : Color.white)
                )
                .shadow(color: scheme.primary.opacity(0.35), radius: 6, y: 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.8 : 0.5)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .padding(.top, 14)
    }
}

// MARK: - 单方案预览（展示更完整信息：首页 + 空状态 + 全部记录）

/// 单个方案的完整预览 —— 用于单独评估。
struct UIDesignFullPreview: View {
    let scheme: DesignScheme
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().foregroundStyle(scheme.divider)

            if selectedTab == 0 {
                homeView
            } else if selectedTab == 1 {
                emptyView
            } else {
                allRecordsView
            }

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(scheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scheme.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(scheme.text)
                Text(scheme.description)
                    .font(.system(size: 11))
                    .foregroundStyle(scheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Circle()
                .fill(scheme.primary.opacity(scheme == .glass ? 0.25 : 0.10))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(scheme.primary)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabItem("首页", systemName: "house.fill", index: 0)
            tabItem("空状态", systemName: "square.split.2x1", index: 1)
            tabItem("全部记录", systemName: "tray.full", index: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabItem(_ title: String, systemName: String, index: Int) -> some View {
        let isActive = selectedTab == index
        return Button { selectedTab = index } label: {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isActive ? scheme.primary : scheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? scheme.primary.opacity(scheme == .glass ? 0.25 : 0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // ── 首页 ────────────────────────────────────────
    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 记忆图谱卡
                memoryDashboardCard

                // 最近更新
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionTitle("最近更新")
                        Spacer()
                        Text("查看全部")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(scheme.primary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(sampleRecords.enumerated()), id: \.element.id) { idx, record in
                            recordRowExpanded(record)
                            if idx < sampleRecords.count - 1 {
                                Rectangle()
                                    .fill(scheme.divider)
                                    .frame(height: 0.5)
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(scheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
                    )
                }

                // 快速示例
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("快捷记录")
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(["西瓜放冰箱", "钥匙在玄关", "周五交报告", "洗衣液在阳台"], id: \.self) { text in
                            quickChip(text)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }

    private var memoryDashboardCard: some View {
        HStack(spacing: 14) {
            // 环形图（简化版）
            ZStack {
                Circle()
                    .stroke(scheme.primary.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(scheme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.6, to: 0.8)
                    .stroke(scheme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("记忆图谱")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(scheme.secondaryText)
                HStack(spacing: 10) {
                    legendDot(title: "位置 3", color: scheme.primary)
                    legendDot(title: "日程 1", color: scheme.accent)
                    legendDot(title: "备忘 1", color: scheme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(scheme.secondaryText.opacity(0.6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
        )
    }

    private func legendDot(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(scheme.secondaryText)
        }
    }

    private func recordRowExpanded(_ record: SampleRecord) -> some View {
        HStack(spacing: 12) {
            let color: Color = {
                switch scheme {
                case .minimal: return scheme.primary
                case .warm:    return record.kind == .schedule ? scheme.primary : scheme.accent
                case .glass:   return record.kind == .schedule ? scheme.accent : scheme.primary
                }
            }()
            let iconName: String = {
                switch record.kind {
                case .place: return "location.fill"
                case .schedule: return "calendar"
                case .note: return "note.text"
                }
            }()

            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(scheme == .glass ? color.opacity(0.22) : color.opacity(0.12))
                )
                .overlay(
                    Circle().strokeBorder(
                        scheme == .minimal ? scheme.divider : Color.clear,
                        lineWidth: scheme == .minimal ? 0.6 : 0
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(scheme.text)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(scheme.secondaryText.opacity(0.7))
                    Text(record.place)
                        .font(.system(size: 11))
                        .foregroundStyle(scheme.secondaryText)
                    Text("·")
                        .foregroundStyle(scheme.secondaryText.opacity(0.4))
                    Text(record.time)
                        .font(.system(size: 11))
                        .foregroundStyle(scheme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(scheme.secondaryText.opacity(0.5))
        }
        .padding(.vertical, 8)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(scheme.secondaryText)
            .tracking(0.5)
    }

    private func quickChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(scheme.primary.opacity(0.7))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(scheme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
        )
    }

    // ── 空状态 ───────────────────────────────────────
    private var emptyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 空状态主卡片
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(scheme.primary.opacity(scheme == .glass ? 0.15 : 0.06))
                            .frame(width: 80, height: 80)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(scheme.primary)
                    }

                    VStack(spacing: 6) {
                        Text("还没有任何记录")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(scheme.text)
                        Text("点击下方示例快速开始，或长按输入框语音记录")
                            .font(.system(size: 12))
                            .foregroundStyle(scheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

                // 示例芯片
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("试试这样记")
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(["西瓜放冰箱", "钥匙在玄关", "周五交报告", "洗衣液在阳台",
                                  "雨伞放门口", "生日备忘 6 月 25"], id: \.self) { text in
                            quickChip(text)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }

    // ── 全部记录 ───────────────────────────────────
    private var allRecordsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(scheme.secondaryText.opacity(0.7))
                    Text("搜索记录")
                        .font(.system(size: 13))
                        .foregroundStyle(scheme.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(scheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
                )

                // 分类筛选
                HStack(spacing: 8) {
                    filterChip("全部", active: true)
                    filterChip("位置", active: false)
                    filterChip("日程", active: false)
                    filterChip("备忘", active: false)
                }

                // 记录列表
                VStack(spacing: 0) {
                    ForEach(Array(sampleRecords.enumerated()), id: \.element.id) { idx, record in
                        recordRowExpanded(record)
                        if idx < sampleRecords.count - 1 {
                            Rectangle()
                                .fill(scheme.divider)
                                .frame(height: 0.5)
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(scheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }

    private func filterChip(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? (scheme == .glass ? Color.black : Color.white) : scheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? scheme.primary : scheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(scheme.divider, lineWidth: active ? 0 : 0.6)
            )
    }

    // ── 底部输入条（三个方案通用样式，但配色不同） ──
    private var bottomBar: some View {
        HStack(spacing: 10) {
            // 模式切换
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("记下")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(scheme.primary)
            .frame(width: 52, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme.primary.opacity(scheme == .glass ? 0.25 : 0.10))
            )

            // 输入框
            HStack(spacing: 6) {
                Text("记录内容…")
                    .font(.system(size: 13))
                    .foregroundStyle(scheme.secondaryText)
                Spacer()
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(scheme.primary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(scheme.divider, lineWidth: scheme == .minimal ? 0.6 : 0.4)
            )

            // 提问按钮
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(scheme == .glass ? Color.black : Color.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(scheme.primary)
                )
                .shadow(color: scheme.primary.opacity(0.4), radius: 8, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if scheme == .glass {
                LinearGradient(colors: [scheme.background, Color.black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                scheme.surface
            }
        }
    }
}

// MARK: - Canvas 预览入口
// 注：预览宏仅在 Xcode 的 Preview Canvas 中生效，命令行构建因插件沙箱限制跳过。
#if canImport(DeveloperToolsSupport) && !targetEnvironment(simulator) && !os(iOS)

#Preview("三方案对比 · 首页") {
    UIDesignComparisonView()
        .frame(minWidth: 1000, minHeight: 700)
}

#Preview("方案 A · 极简白灰") {
    UIDesignFullPreview(scheme: .minimal)
        .frame(width: 360, height: 680)
        .padding()
        .background(Color(.systemGray6))
}

#Preview("方案 B · 温暖生活") {
    UIDesignFullPreview(scheme: .warm)
        .frame(width: 360, height: 680)
        .padding()
        .background(Color(.systemGray6))
}

#Preview("方案 C · 玻璃科技") {
    UIDesignFullPreview(scheme: .glass)
        .frame(width: 360, height: 680)
        .padding()
        .background(Color(.systemGray6))
}
#endif
