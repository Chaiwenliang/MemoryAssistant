import SwiftUI

// MARK: - 设计系统

enum AppTheme {

    // MARK: - 间距与圆角

    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let chipRadius: CGFloat = 14
    static let inputRadius: CGFloat = 22
    static let itemRadius: CGFloat = 14
    static let controlHeight: CGFloat = 48

    // MARK: - 主题偏好

    enum VisualScheme: String, CaseIterable, Identifiable {
        case warm       // 温暖生活：奶油白底 + 暖橙点缀
        case classic    // 极简经典：白灰 iOS 默认风
        case glass      // 玻璃科技：深色 + 毛玻璃叠层

        var id: String { rawValue }

        var title: String {
            switch self {
            case .warm: return "温暖"
            case .classic: return "经典"
            case .glass: return "玻璃"
            }
        }

        var symbol: String {
            switch self {
            case .warm: return "sun.max.fill"
            case .classic: return "display"
            case .glass: return "moon.stars.fill"
            }
        }
    }

    enum ThemePreference: String, CaseIterable, Identifiable {
        case system
        case warm
        case classic
        case glass

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "跟随系统"
            case .warm: return "温暖"
            case .classic: return "经典"
            case .glass: return "玻璃"
            }
        }

        var symbol: String {
            switch self {
            case .system: return "circle.righthalf.filled"
            case .warm: return "sun.max.fill"
            case .classic: return "square.split.2x1"
            case .glass: return "moon.stars.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .warm, .classic: return .light
            case .glass: return .dark
            }
        }

        var scheme: VisualScheme {
            switch self {
            case .system: return .warm
            case .warm: return .warm
            case .classic: return .classic
            case .glass: return .glass
            }
        }
    }

    // MARK: - 模式色 (ask / capture)

    static func modeTint(for mode: BottomInputMode) -> Color {
        mode == .ask ? Color(red: 0.80, green: 0.45, blue: 0.22) : Color(red: 0.28, green: 0.24, blue: 0.20)
    }

    // MARK: - 段落标题

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.none)
    }
}

// MARK: - 配色方案

/// 根据当前主题提供背景色、表面色、强调色等。
struct ThemeColors {
    let scheme: AppTheme.VisualScheme

    var pageBackground: Color {
        switch scheme {
        case .warm:    return Color(red: 0.98, green: 0.95, blue: 0.90)
        case .classic: return Color(.systemGroupedBackground)
        case .glass:   return Color(red: 0.06, green: 0.07, blue: 0.09)
        }
    }

    var cardSurface: Color {
        switch scheme {
        case .warm:    return Color(red: 1.00, green: 0.98, blue: 0.94)
        case .classic: return Color(.secondarySystemGroupedBackground)
        case .glass:   return Color.white.opacity(0.08)
        }
    }

    var cardBorder: Color {
        switch scheme {
        case .warm:    return Color(red: 0.85, green: 0.75, blue: 0.60).opacity(0.55)
        case .classic: return Color.primary.opacity(0.07)
        case .glass:   return Color.white.opacity(0.12)
        }
    }

    var primaryText: Color {
        switch scheme {
        case .warm, .classic: return Color(red: 0.20, green: 0.18, blue: 0.15)
        case .glass:          return Color.white
        }
    }

    var secondaryText: Color {
        switch scheme {
        case .warm:    return Color(red: 0.55, green: 0.45, blue: 0.35)
        case .classic: return .secondary
        case .glass:   return Color.white.opacity(0.55)
        }
    }

    var accent: Color {
        switch scheme {
        case .warm:    return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .classic: return Color.accentColor
        case .glass:   return Color(red: 0.40, green: 0.80, blue: 1.00)
        }
    }

    var placeTint: Color {
        switch scheme {
        case .warm:    return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .classic: return .blue
        case .glass:   return Color(red: 1.00, green: 0.60, blue: 0.70)
        }
    }

    var scheduleTint: Color {
        switch scheme {
        case .warm:    return Color(red: 0.80, green: 0.45, blue: 0.22)
        case .classic: return .orange
        case .glass:   return Color(red: 1.00, green: 0.85, blue: 0.50)
        }
    }

    var noteTint: Color {
        switch scheme {
        case .warm:    return Color(red: 0.55, green: 0.45, blue: 0.35)
        case .classic: return .green
        case .glass:   return Color(red: 0.60, green: 0.95, blue: 0.70)
        }
    }

    var shadow: Color {
        switch scheme {
        case .warm:    return Color(red: 0.55, green: 0.40, blue: 0.20).opacity(0.10)
        case .classic: return Color.black.opacity(0.08)
        case .glass:   return Color.black.opacity(0.50)
        }
    }

    var shadowY: CGFloat {
        switch scheme {
        case .warm, .classic: return 4
        case .glass: return 6
        }
    }

    var shadowRadius: CGFloat {
        switch scheme {
        case .warm, .classic: return 14
        case .glass: return 20
        }
    }

    /// 输入模式按钮的颜色
    func modeButtonActiveColor(_ mode: BottomInputMode) -> Color {
        switch scheme {
        case .warm:    return mode == .ask ? accent : Color(red: 0.35, green: 0.28, blue: 0.22)
        case .classic: return mode == .ask ? Color.accentColor : Color(red: 0.35, green: 0.35, blue: 0.40)
        case .glass:   return mode == .ask ? accent : Color(red: 0.85, green: 0.65, blue: 0.40)
        }
    }
}

// MARK: - 主题环境变量

struct CurrentThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme.VisualScheme = .warm
}

extension EnvironmentValues {
    var currentTheme: AppTheme.VisualScheme {
        get { self[CurrentThemeKey.self] }
        set { self[CurrentThemeKey.self] = newValue }
    }
}

// MARK: - View 扩展：统一的卡片与表面样式
// 卡片样式通过包装视图来读取 environment 的 currentTheme，确保主题切换后卡片也跟随变化。

extension View {

    /// 标准卡片：背景 + 圆角 + 边框 + 阴影，随主题变化
    func appCard(radius: CGFloat = AppTheme.cardRadius) -> some View {
        ThemeCardWrapper(radius: radius) { self }
    }

    /// 轻量化嵌入式卡片：用于卡片内的子容器
    func appSoftCard(radius: CGFloat = AppTheme.chipRadius, tint: Color? = nil) -> some View {
        ThemeSoftCardWrapper(radius: radius, tint: tint) { self }
    }

    /// 页面背景
    func appPageBackground() -> some View {
        ThemePageBackgroundWrapper { self }
    }

    /// 兼容旧代码
    func elevatedCardSurface(radius: CGFloat = AppTheme.cardRadius) -> some View {
        self.appCard(radius: radius)
    }

    func softCardSurface(radius: CGFloat = AppTheme.chipRadius, tint: Color = .clear) -> some View {
        self.appSoftCard(radius: radius, tint: tint)
    }

    func compactNavigationChrome() -> some View { self }
    func compactListSurface() -> some View { self }

    func homeScrollContentInsets() -> some View {
        contentMargins(.top, 10, for: .scrollContent)
    }
}

// MARK: - 包装视图（从 environment 读取 currentTheme）

private struct ThemeCardWrapper<Content: View>: View {
    let radius: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.currentTheme) private var theme

    var body: some View {
        let colors = ThemeColors(scheme: theme)
        content()
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(colors.cardBorder, lineWidth: 0.6)
            )
            .shadow(color: colors.shadow, radius: colors.shadowRadius, y: colors.shadowY)
    }
}

private struct ThemeSoftCardWrapper<Content: View>: View {
    let radius: CGFloat
    let tint: Color?
    @ViewBuilder let content: () -> Content
    @Environment(\.currentTheme) private var theme

    var body: some View {
        let colors = ThemeColors(scheme: theme)
        let fill: Color = {
            if let tint = tint { return tint.opacity(0.12) }
            return colors.cardSurface.opacity(0.85)
        }()
        content()
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(colors.cardBorder.opacity(0.6), lineWidth: 0.5)
            )
    }
}

private struct ThemePageBackgroundWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.currentTheme) private var theme

    var body: some View {
        let colors = ThemeColors(scheme: theme)
        content().background(colors.pageBackground.ignoresSafeArea())
    }
}

// MARK: - 圆形图标按钮（齿轮等）——从 environment 读取主题

struct GlassIconButton: View {
    let systemName: String
    var showsProBadge: Bool = false
    let action: () -> Void

    @Environment(\.currentTheme) private var theme

    var body: some View {
        let colors = ThemeColors(scheme: theme)
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(colors.cardSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(colors.cardBorder, lineWidth: 0.6)
                    )
                    .shadow(color: colors.shadow, radius: 8, y: 2)

                if showsProBadge {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                        .padding(3)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 主题色便捷访问

struct ThemeColor {
    static func place(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).placeTint
    }
    static func schedule(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).scheduleTint
    }
    static func note(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).noteTint
    }
    static func accent(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).accent
    }
    static func modeButton(_ mode: BottomInputMode, for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).modeButtonActiveColor(mode)
    }
    static func pageBackground(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).pageBackground
    }
    static func cardSurface(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).cardSurface
    }
    static func primaryText(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).primaryText
    }
    static func secondaryText(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).secondaryText
    }
    static func cardBorder(for scheme: AppTheme.VisualScheme = .warm) -> Color {
        ThemeColors(scheme: scheme).cardBorder
    }
}

// MARK: - 通用按钮风格

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
