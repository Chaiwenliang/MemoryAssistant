import SwiftUI
import UIKit

// MARK: - 输入模式

enum BottomInputMode: String, CaseIterable {
    case ask
    case capture

    var title: String {
        switch self {
        case .ask: return "提问"
        case .capture: return "记下"
        }
    }

    var icon: String {
        switch self {
        case .ask: return "sparkles"
        case .capture: return "plus"
        }
    }

    var activeIcon: String { icon }

    var tint: Color { ThemeColor.modeButton(self) }

    var placeholder: String {
        switch self {
        case .ask: return "提问，长按语音"
        case .capture: return "记下内容，长按语音"
        }
    }

    var recordingHint: String {
        switch self {
        case .ask: return "松开后提问"
        case .capture: return "松开后记下"
        }
    }
}

// MARK: - 底部输入条

struct BottomInputBar: View {
    @Binding var text: String
    @Binding var inputMode: BottomInputMode
    @FocusState.Binding var isFocused: Bool

    var showsModeToggle: Bool = true
    var inlineModeToggle: Bool = true
    var showModeCoachMark: Bool = false
    var placeholder: String?
    var showsMicButton: Bool = false
    var isRecording: Bool = false

    let onSubmit: () -> Void
    var onMicTap: (() -> Void)?
    var onVoiceActivate: (() -> Void)?
    var onVoiceRelease: (() -> Void)?
    var onVoiceHoldingChanged: ((Bool) -> Void)?

    @State private var isHoldingForVoice = false
    @Environment(\.currentTheme) private var currentTheme

    private var colors: ThemeColors { ThemeColors(scheme: currentTheme) }

    private var voiceHoldEnabled: Bool {
        !showsMicButton && onVoiceActivate != nil && onVoiceRelease != nil
    }

    private var resolvedPlaceholder: String {
        placeholder ?? inputMode.placeholder
    }

    private var showsVoiceOverlay: Bool {
        isHoldingForVoice || isRecording
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部分隔细线
            Rectangle()
                .fill(colors.cardBorder.opacity(0.7))
                .frame(height: 0.6)

            HStack(alignment: .center, spacing: 10) {
                // 模式切换按钮组
                if showsModeToggle, inlineModeToggle {
                    modeSwitchButtons
                }

                // 输入框条
                textFieldBar

                // 独立麦克风按钮（可选）
                if showsMicButton {
                    Button {
                        onMicTap?()
                    } label: {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(isRecording ? Color.red : colors.accent)
                            )
                            .shadow(color: colors.accent.opacity(0.35), radius: 10, y: 3)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(colors.pageBackground)
    }

    // MARK: 模式切换按钮

    private var modeSwitchButtons: some View {
        HStack(spacing: 6) {
            ForEach(BottomInputMode.allCases, id: \.self) { mode in
                let isActive = inputMode == mode
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        inputMode = mode
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? .white : colors.accent.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(isActive ? colors.accent : colors.cardSurface)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isActive ? colors.accent.opacity(0.85) : colors.cardBorder,
                                    lineWidth: isActive ? 1.5 : 0.6
                                )
                        )
                        .shadow(color: colors.shadow, radius: 8, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }

    // MARK: 输入框条

    private var textFieldBar: some View {
        HStack(alignment: .center, spacing: 6) {
            TextField(resolvedPlaceholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .submitLabel(inputMode == .ask ? .search : .done)
                .onSubmit {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSubmit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)
                .padding(.vertical, 14)
                .opacity(showsVoiceOverlay ? 0 : 1)

            // 发送按钮（有文字时）
            if hasText {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSubmit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(colors.accent, colors.accent.opacity(0.15))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.trailing, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85)).animation(.easeOut(duration: 0.18)),
                    removal: .opacity.animation(.easeIn(duration: 0.12))
                ))
            }
        }
        .frame(minHeight: AppTheme.controlHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.inputRadius, style: .continuous)
                .fill(colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.inputRadius, style: .continuous)
                .stroke(
                    colors.accent.opacity(showsVoiceOverlay ? 0.35 : 0.1),
                    lineWidth: showsVoiceOverlay ? 1.2 : 0.6
                )
        )
        .shadow(color: colors.shadow, radius: 10, y: 2)
        .overlay {
            if showsVoiceOverlay {
                VoiceWaveformOverlay(tint: colors.accent, isRecording: isRecording)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.inputRadius, style: .continuous))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showsVoiceOverlay)
        .animation(.easeInOut(duration: 0.18), value: isRecording)
        .animation(.easeInOut(duration: 0.18), value: hasText)
        .applyVoiceHoldGesture(
            enabled: voiceHoldEnabled,
            isHoldingForVoice: $isHoldingForVoice,
            onHoldingChanged: onVoiceHoldingChanged,
            onActivate: { onVoiceActivate?() },
            onRelease: { onVoiceRelease?() }
        )
    }
}

// MARK: - View 扩展：长按语音手势

private extension View {
    @ViewBuilder
    func applyVoiceHoldGesture(
        enabled: Bool,
        isHoldingForVoice: Binding<Bool>,
        onHoldingChanged: ((Bool) -> Void)?,
        onActivate: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        if enabled {
            self
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.inputRadius, style: .continuous))
                .voiceHoldGesture(
                    onHoldingChanged: { holding in
                        isHoldingForVoice.wrappedValue = holding
                        onHoldingChanged?(holding)
                    },
                    onActivate: onActivate,
                    onRelease: onRelease
                )
        } else {
            self
        }
    }
}

// MARK: - ThemeColor shadow helper

private func cardShadowColor() -> Color {
    ThemeColor.cardBorder().opacity(0.08)
}
