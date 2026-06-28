import SwiftUI
import UIKit

struct QuickCaptureView: View {
    let onSave: (MemoryRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var inputText = ""
    @State private var previewDraft = MemoryDraft()
    @StateObject private var speechRecognizer = SpeechRecognizerService()
    @State private var voiceNeedsSettings = false

    private var canSave: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && previewDraft.isValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("直接说或打字，系统会自动理解并记下。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("例如：苹果放厨房冰箱里 / 明天下午3点开会", text: $inputText)
                        .focused($isInputFocused)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .onChange(of: inputText) { _, newValue in
                            previewDraft = MemoryDraftParser.draft(from: newValue)
                        }

                    Button {
                        Task {
                            if speechRecognizer.isRecording {
                                speechRecognizer.stopRecording()
                                let text = speechRecognizer.cleanedTranscript()
                                guard !text.isEmpty else {
                                    speechRecognizer.errorMessage = "没听清，请再说一次"
                                    voiceNeedsSettings = false
                                    return
                                }
                                inputText = text
                                previewDraft = MemoryDraftParser.draft(from: inputText)
                                isInputFocused = true
                            } else {
                                isInputFocused = false
                                await speechRecognizer.startRecording()
                                if speechRecognizer.errorMessage != nil {
                                    voiceNeedsSettings = speechRecognizer.needsSettingsRedirect
                                }
                            }
                        }
                    } label: {
                        Label(
                            speechRecognizer.isRecording ? "停止录音" : "语音输入",
                            systemImage: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(speechRecognizer.isRecording ? .red : .accentColor)

                    if canSave {
                        AutoParsePreview(draft: previewDraft)
                    }
                }
                .padding(AppTheme.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("记一下")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("记下") {
                        onSave(previewDraft.makeRecord())
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isInputFocused = false }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isInputFocused = true
                }
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                guard speechRecognizer.isRecording, !newValue.isEmpty else { return }
                inputText = newValue
                previewDraft = MemoryDraftParser.draft(from: newValue)
            }
            .alert("语音提示", isPresented: Binding(
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

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct AutoParsePreview: View {
    let draft: MemoryDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将记下")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(previewText)
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var previewText: String {
        let records = CompoundIngredientExpander.expandRecords([draft.makeRecord()])
        if records.count == 1 {
            return records[0].displaySummary
        }
        let names = records.map(\.title).joined(separator: "、")
        if let place = records.first?.placeDescription, !place.isEmpty {
            return "\(names) · \(place)"
        }
        return names
    }
}
