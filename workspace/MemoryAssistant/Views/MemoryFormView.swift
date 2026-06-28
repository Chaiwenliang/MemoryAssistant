import SwiftUI
import UIKit

/// 纠正记录：底部输入与首页一致，改文字或语音后实时重新理解。
struct MemoryFormView: View {
    let existingRecord: MemoryRecord?
    let onSave: (MemoryRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String
    @State private var previewDraft: MemoryDraft
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    @State private var voiceNeedsSettings = false
    @FocusState private var isInputFocused: Bool

    init(existingRecord: MemoryRecord? = nil, onSave: @escaping (MemoryRecord) -> Void) {
        self.existingRecord = existingRecord
        self.onSave = onSave
        let initial = Self.initialText(for: existingRecord)
        _inputText = State(initialValue: initial)
        _previewDraft = State(initialValue: MemoryDraftParser.draft(from: initial))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let existingRecord {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("当前记录")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(existingRecord.displaySummary)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("纠正后将理解为")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if previewDraft.isValid {
                                Text(previewDraft.makeRecord(from: existingRecord).displaySummary)
                                    .font(.body.weight(.medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.accentColor.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Text("在底部输入或说话")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 4)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(existingRecord == nil ? "记一下" : "纠正记录")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomInputBar(
                    text: $inputText,
                    inputMode: .constant(.capture),
                    isFocused: $isInputFocused,
                    showsModeToggle: false,
                    placeholder: "重新描述这条记录",
                    showsMicButton: true,
                    isRecording: speechRecognizer.isRecording,
                    onSubmit: { isInputFocused = false },
                    onMicTap: { Task { await toggleVoiceInput() } }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(previewDraft.makeRecord(from: existingRecord))
                        dismiss()
                    }
                    .disabled(!previewDraft.isValid)
                }
            }
            .onChange(of: inputText) { _, newValue in
                previewDraft = MemoryDraftParser.draft(from: newValue)
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                guard speechRecognizer.isRecording, !newValue.isEmpty else { return }
                inputText = newValue
                previewDraft = MemoryDraftParser.draft(from: newValue)
            }
            .alert("语音", isPresented: Binding(
                get: { speechRecognizer.errorMessage != nil },
                set: { _ in
                    speechRecognizer.errorMessage = nil
                    voiceNeedsSettings = false
                }
            )) {
                if voiceNeedsSettings {
                    Button("去设置") {
                        openAppSettings()
                    }
                }
                Button("知道了", role: .cancel) {}
            } message: {
                Text(speechRecognizer.errorMessage ?? "")
            }
        }
    }

    // MARK: - Private

    private func toggleVoiceInput() async {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            let text = speechRecognizer.cleanedTranscript()
            guard !text.isEmpty else {
                speechRecognizer.errorMessage = "没听清，请再说一次"
                voiceNeedsSettings = false
                return
            }
            inputText = text
            previewDraft = MemoryDraftParser.draft(from: text)
        } else {
            isInputFocused = false
            await speechRecognizer.startRecording()
            if speechRecognizer.errorMessage != nil {
                voiceNeedsSettings = speechRecognizer.needsSettingsRedirect
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func initialText(for record: MemoryRecord?) -> String {
        guard let record else { return "" }
        if !record.details.isEmpty { return record.details }
        if let place = record.placeDescription, !place.isEmpty {
            return "\(record.title)放在\(place)"
        }
        return record.title
    }
}
