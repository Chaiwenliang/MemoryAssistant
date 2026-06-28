import SwiftUI

/// 输入框上的声波动效，长按或录音时覆盖显示。
struct VoiceWaveformOverlay: View {
    var tint: Color
    var isRecording: Bool

    private let barCount = 7

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(isRecording ? 0.14 : 0.1))

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                HStack(alignment: .center, spacing: 5) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.95), tint.opacity(0.55)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3.5, height: barHeight(index: index, phase: phase))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func barHeight(index: Int, phase: TimeInterval) -> CGFloat {
        let base: CGFloat = isRecording ? 22 : 14
        let spread: CGFloat = isRecording ? 14 : 8
        let speed = isRecording ? 5.5 : 3.2
        let offset = Double(index) * 0.55
        let wave = abs(sin(phase * speed + offset))
        return base * 0.35 + spread * wave
    }
}
