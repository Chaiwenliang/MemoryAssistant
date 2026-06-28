import SwiftUI

extension View {
    /// 内容较多的弹层：占满可用高度，避免「半屏」裁切。
    func appLargeSheet() -> some View {
        self
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }

    /// 购买 / 设置类全屏展示，确保底部按钮不被截断。
    func appFullScreenModal() -> some View {
        self
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
    }
}
