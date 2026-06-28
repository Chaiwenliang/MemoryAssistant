import SwiftUI

struct SettingsView: View {
    @ObservedObject var proStore: MemoryProStore
    @ObservedObject var store: MemoryStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var theme: AppTheme.ThemePreference = .system
    @State private var showUpgrade = false
    @State private var organizeMessage: String?
    @State private var showAdminConsole = false
    @State private var versionTapCount = 0
    @StateObject private var usageTracker = LLMUsageTracker.shared
    @StateObject private var requestLogger = LLMRequestLogger.shared

    private var currentScheme: AppTheme.VisualScheme {
        switch theme {
        case .warm: return .warm
        case .classic: return .classic
        case .glass: return .glass
        case .system: return .warm
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 外观 - 主题选择
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("外观")

                        HStack(spacing: 10) {
                            ForEach(AppTheme.ThemePreference.allCases) { option in
                                themeOption(option)
                            }
                        }
                    }

                    // 版本信息
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("版本")

                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("当前版本")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                                    Text(proStore.isPro ? "Pro" : "免费版")
                                        .font(.caption)
                                        .foregroundStyle(proStore.isPro ? ThemeColor.accent(for: currentScheme) : ThemeColor.secondaryText(for: currentScheme))
                                }
                                Spacer()
                                if !proStore.isPro {
                                    Button {
                                        showUpgrade = true
                                    } label: {
                                        Text("升级 Pro")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(ThemeColor.accent(for: currentScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(16)

                            Divider()
                                .padding(.leading, 56)

                            HStack(spacing: 14) {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(ThemeColor.accent(for: currentScheme))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI 用量")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                                    Text("今日: \(usageTracker.todayRemainingCalls) 次，总计: \(usageTracker.summary.totalCalls) 次")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.5))
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showAdminConsole = true
                            }
                        }
                        .appCard()
                    }

                    // 数据管理
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("数据")

                        VStack(spacing: 0) {
                            dataRow(icon: "tray.full", title: "全部记录", subtitle: "\(store.records.count) 条") {
                                AllRecordsView(store: store)
                            }

                            Divider()
                                .padding(.leading, 56)

                            Button {
                                let count = store.organizeRecords()
                                organizeMessage = count > 0
                                    ? "已重新拆分 \(count) 条记录"
                                    : "记录已是结构化格式，无需整理"
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(ThemeColor.accent(for: currentScheme))
                                        .frame(width: 28)
                                    Text("整理记录")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.5))
                                }
                                .padding(16)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .appCard()
                    }

                    // 隐私说明
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("隐私")
                        Text("提问时发送问题与记录摘要给 AI 服务，用于生成回答。数据仅用于本 App 功能，不用于其他用途。")
                            .font(.caption)
                            .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                            .padding(16)
                            .appCard()
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(ThemeColor.pageBackground(for: currentScheme).ignoresSafeArea())
            .environment(\.currentTheme, currentScheme)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ThemeColor.accent(for: currentScheme))
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView(proStore: proStore)
            }
            .sheet(isPresented: $showAdminConsole) {
                AdminConsoleView()
            }
            .alert("整理完成", isPresented: Binding(
                get: { organizeMessage != nil },
                set: { _ in organizeMessage = nil }
            )) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(organizeMessage ?? "")
            }
        }
    }

    // MARK: - 子组件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
            .padding(.horizontal, 4)
    }

    private func themeOption(_ option: AppTheme.ThemePreference) -> some View {
        let isActive = theme == option
        return Button {
            theme = option
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themePreviewBackground(option))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isActive ? ThemeColor.accent(for: currentScheme).opacity(0.8) : ThemeColor.cardBorder(for: currentScheme), lineWidth: isActive ? 2 : 0.6)
                        )
                    Image(systemName: option.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themePreviewIcon(option))
                }
                Text(option.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isActive ? ThemeColor.primaryText(for: currentScheme) : ThemeColor.secondaryText(for: currentScheme))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func themePreviewBackground(_ option: AppTheme.ThemePreference) -> Color {
        switch option {
        case .system: return Color.secondary.opacity(0.15)
        case .warm: return ThemeColor.pageBackground(for: .warm)
        case .classic: return Color(.systemGroupedBackground)
        case .glass: return ThemeColor.pageBackground(for: .glass)
        }
    }

    private func themePreviewIcon(_ option: AppTheme.ThemePreference) -> Color {
        switch option {
        case .warm: return ThemeColor.accent(for: .warm)
        case .classic: return ThemeColor.accent(for: .classic)
        case .glass: return ThemeColor.accent(for: .glass)
        case .system: return .secondary
        }
    }

    private func dataRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ThemeColor.accent(for: currentScheme))
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ThemeColor.primaryText(for: currentScheme))
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ThemeColor.secondaryText(for: currentScheme).opacity(0.5))
            }
            .padding(16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
