import SwiftUI
import UIKit

enum VoiceHold {
    /// 按住超过此时长才进入录音（参考豆包约 1～1.5 秒）
    static let activationDuration: TimeInterval = 1.2
}

/// 长按语音：短按不触发；按住满时长后才回调 onActivate，松开时 onRelease。
struct VoiceHoldGestureModifier: ViewModifier {
    let minimumDuration: TimeInterval
    let onActivate: () -> Void
    let onRelease: () -> Void
    var onHoldingChanged: ((Bool) -> Void)?

    @State private var didActivate = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: minimumDuration, pressing: { pressing in
                if pressing {
                    didActivate = false
                    onHoldingChanged?(true)
                } else {
                    onHoldingChanged?(false)
                    if didActivate {
                        onRelease()
                    }
                    didActivate = false
                }
            }, perform: {
                didActivate = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onActivate()
            })
    }
}

extension View {
    func voiceHoldGesture(
        minimumDuration: TimeInterval = VoiceHold.activationDuration,
        onHoldingChanged: ((Bool) -> Void)? = nil,
        onActivate: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        modifier(
            VoiceHoldGestureModifier(
                minimumDuration: minimumDuration,
                onActivate: onActivate,
                onRelease: onRelease,
                onHoldingChanged: onHoldingChanged
            )
        )
    }
}
