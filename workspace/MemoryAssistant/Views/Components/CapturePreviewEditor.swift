import SwiftUI
import UIKit

/// 记下预览：可编辑内容 / 位置 / 时间，通过闸门后才可确认。
struct CapturePreviewEditor: View {
    @Binding var state: CaptureEditState
    var isExpanded: Bool = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    // 复合食材展开后的记录预览（仅用于显示）
    private var expandedTitles: [String] {
        guard !state.title.isEmpty else { return [] }
        let names = CompoundIngredientExpander.expandNames(state.title)
        if names.count > 1 {
            return names
        }
        return []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerRow

                    if state.isUpdatingExisting {
                        updateBanner
                    }

                    VStack(spacing: isExpanded ? 16 : 12) {
                        captureField(label: "内容", placeholder: "物品或事项，如：西瓜", text: $state.title)

                        captureField(label: "位置", placeholder: state.isUpdatingExisting ? "新位置，如：客厅桌子" : "选填，如：冰箱", text: $state.placeDescription)

                        if !state.isUpdatingExisting {
                            Toggle(isOn: $state.hasDueDate) {
                                Text("包含时间")
                                    .font(.subheadline)
                            }
                            .tint(.purple)

                            if state.hasDueDate {
                                ChineseSchedulePicker(date: $state.dueDate)
                            }
                        }

                        if !expandedTitles.isEmpty {
                            compoundIngredientsPreview
                        }

                        if let message = state.gateMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(isExpanded ? 18 : 14)
                    .softCardSurface(radius: AppTheme.cardRadius, tint: .purple)

                    if !state.rawText.isEmpty {
                        Text("原话：\(state.rawText)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("取消")
                        .font(isExpanded ? .body.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isExpanded ? 14 : 12)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onConfirm) {
                    Text(state.isUpdatingExisting ? "确认更新" : "确认记下")
                        .font(isExpanded ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isExpanded ? 14 : 12)
                        .background(
                            state.canSave ? (state.isUpdatingExisting ? Color.orange : Color.accentColor) : Color.gray,
                            in: Capsule()
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!state.canSave)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if state.canSave {
                            let generator = UIImpactFeedbackGenerator(style: state.isUpdatingExisting ? .medium : .light)
                            generator.impactOccurred()
                        }
                    }
                )
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack {
            Text(state.isUpdatingExisting ? "更新已有记录" : "确认拆分结果")
                .font(isExpanded ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(state.isUpdatingExisting ? .orange : .purple)
            Spacer()
            Text(state.categoryLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (state.isUpdatingExisting ? Color.orange : Color.purple).opacity(0.08),
                    in: Capsule()
                )
        }
    }

    private var updateBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("将更新已有「\(state.title)」")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            if let previous = state.previousPlaceDescription, !previous.isEmpty {
                Text("原位置：\(previous)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compoundIngredientsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("检测到复合物品，将保存为以下 \(expandedTitles.count) 条独立记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(expandedTitles, id: \.self) { title in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green.opacity(0.8))
                            .font(.caption)
                        Text(title)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if !state.placeDescription.isEmpty {
                            Text("· \(state.placeDescription)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func captureField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(isExpanded ? .subheadline : .caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(isExpanded ? .title3 : .body)
                .textFieldStyle(.plain)
                .padding(.horizontal, isExpanded ? 14 : 10)
                .padding(.vertical, isExpanded ? 12 : 8)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
