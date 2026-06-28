import SwiftUI

struct UpgradeView: View {
    @ObservedObject var proStore: MemoryProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 28) {
                    heroSection
                    benefitsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    pricingSection
                    footerNotes
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            Divider()
                        }
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("升级 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("提示", isPresented: Binding(
                get: { proStore.lastError != nil },
                set: { _ in proStore.lastError = nil }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(proStore.lastError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.22),
                                Color.accentColor.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.purple.opacity(0.15), radius: 16, y: 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("记忆助手 Pro")
                    .font(.title2.weight(.bold))

                Text("不只帮你记住，也帮你想想。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var benefitsSection: some View {
        VStack(spacing: 0) {
            benefitRow(icon: "brain.head.profile", text: "理解你的开放提问")
            divider
            benefitRow(icon: "refrigerator", text: "结合记录给实用建议")
            divider
            benefitRow(icon: "bubble.left.and.text.bubble.right", text: "回答更自然，不像搜关键词")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 52)
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if proStore.isPro {
                Label("已开通", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Button {
                    Task { await proStore.purchaseYearly() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("年度会员")
                                .font(.body.weight(.semibold))
                            Text(proStore.yearlyPriceText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        Spacer()
                        Text("推荐")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .disabled(proStore.isPurchasing)

                Button {
                    Task { await proStore.purchaseMonthly() }
                } label: {
                    Text("月度会员 \(proStore.monthlyPriceText)")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
                .disabled(proStore.isPurchasing)

                Button("恢复购买") {
                    Task { await proStore.restorePurchases() }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .disabled(proStore.isPurchasing)
            }

            if proStore.isPurchasing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
    }

    private var footerNotes: some View {
        VStack(spacing: 4) {
            Text("免费版含记录、查找与基础建议")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if proStore.usesMockPurchaseInDebug {
                Text("开发预览可模拟开通")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("订阅由 App Store 管理")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.purple)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
