import SwiftUI
import UIKit

struct MemoryListView: View {
    @ObservedObject var viewModel: MemoryListViewModel
    @ObservedObject var proStore: MemoryProStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var speechRecognizer = SpeechRecognizerService()

    @AppStorage("hasUsedModeToggle") private var hasUsedModeToggle = false
    @AppStorage("appTheme") private var theme: AppTheme.ThemePreference = .system
    @State private var isPresentingSettings = false
    @State private var isPresentingUpgrade = false
    @State private var showAllRecords = false
    @State private var bottomInputText = ""
    @State private var inputMode: BottomInputMode = .ask
    @State private var captureEdit: CaptureEditState?
    @State private var isPresentingCaptureSheet = false
    @State private var voiceErrorMessage: String?
    @State private var voiceNeedsSettings = false
    @State private var recordForLocationUpdate: MemoryRecord?
    @State private var recordForStatusUpdate: MemoryRecord?
    @FocusState private var isBottomInputFocused: Bool

    private var stats: MemoryDashboardStats {
        MemoryDashboardStats.from(viewModel.store.activeRecords)
    }

    private var recentPreviewRecords: [MemoryRecord] {
        Array(
            viewModel.store.activeRecords
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(4)
        )
    }

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
            ZStack {
                // 页面背景
                ThemeColor.pageBackground(for: currentScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeTopBar(
                        stats: stats,
                        showsProBadge: proStore.isPro,
                        onSettings: { isPresentingSettings = true },
                        onShowAllRecords: { showAllRecords = true }
                    )
                    .padding(.bottom, 8)

                    outputPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    BottomInputBar(
                        text: $bottomInputText,
                        inputMode: $inputMode,
                        isFocused: $isBottomInputFocused,
                        showsModeToggle: true,
                        inlineModeToggle: true,
                        showModeCoachMark: !hasUsedModeToggle,
                        isRecording: speechRecognizer.isRecording,
                        onSubmit: { processInput(bottomInputText) },
                        onVoiceActivate: {
                            Task { await handleVoiceActivated() }
                        },
                        onVoiceRelease: {
                            handleVoiceReleased()
                        },
                        onVoiceHoldingChanged: { holding in
                            if holding {
                                isBottomInputFocused = false
                            }
                        }
                    )
                    .onChange(of: inputMode) { _, newMode in
                        hasUsedModeToggle = true
                        handleInputModeChange(newMode)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environment(\.currentTheme, currentScheme)
            .preferredColorScheme(theme.colorScheme)
            .navigationDestination(isPresented: $showAllRecords) {
                AllRecordsView(store: viewModel.store)
                    .environment(\.currentTheme, currentScheme)
            }
            .fullScreenCover(isPresented: $isPresentingSettings) {
                SettingsView(proStore: proStore, store: viewModel.store)
                    .environment(\.currentTheme, currentScheme)
            }
            .fullScreenCover(isPresented: $isPresentingUpgrade) {
                UpgradeView(proStore: proStore)
            }
            .sheet(isPresented: $isPresentingCaptureSheet, onDismiss: {
                if captureEdit != nil, inputMode == .capture {
                    captureEdit = nil
                }
            }) {
                capturePreviewSheet
            }
            .sheet(item: $recordForLocationUpdate) { record in
                RecordLocationUpdateSheet(record: record) { newPlace in
                    viewModel.updateLocation(record, to: newPlace, proStore: proStore)
                }
            }
            .sheet(item: $recordForStatusUpdate) { record in
                RecordStatusUpdateSheet(
                    record: record,
                    onMarkUsed: {
                        viewModel.archiveRecord(record, proStore: proStore)
                    },
                    onDelete: {
                        viewModel.deleteRecord(record, proStore: proStore)
                    }
                )
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.store.reload() }
            }
            .onChange(of: proStore.isPro) { _, isPro in
                guard isPro, inputMode == .ask, !viewModel.searchText.isEmpty else { return }
                viewModel.answer(question: viewModel.searchText, proStore: proStore)
            }
            .alert("提示", isPresented: Binding(
                get: { viewModel.store.errorMessage != nil },
                set: { _ in viewModel.store.errorMessage = nil }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(viewModel.store.errorMessage ?? "")
            }
            .alert("语音", isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { _ in
                    voiceErrorMessage = nil
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
                Text(voiceErrorMessage ?? "")
            }
        }
    }

    // MARK: - Output

    private var outputPanel: some View {
        Group {
            switch inputMode {
            case .ask:
                askOutputContent
            case .capture:
                captureOutputContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var askOutputContent: some View {
        if viewModel.isLLMLoading, viewModel.displayQueryResult == nil {
            ScrollView(showsIndicators: false) {
                QueryLoadingCard()
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 10)
            }
            .homeScrollContentInsets()
        } else if let result = viewModel.displayQueryResult {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    AnswerStrip(
                        answer: result.answer,
                        found: result.found,
                        isLLMAnswer: viewModel.isLLMAnswer,
                        isLoading: viewModel.isLLMLoading
                    )
                    if !result.records.isEmpty {
                        QueryResultRecordActions(
                            records: result.records,
                            onChangeLocation: { record in
                                recordForLocationUpdate = record
                            },
                            onChangeStatus: { record in
                                recordForStatusUpdate = record
                            }
                        )
                    }

                    if viewModel.showNLUpdateUpgradeHint {
                        NLUpdateUpgradeStrip { isPresentingUpgrade = true }
                    }

                    if viewModel.showUpgradeHint {
                        UpgradeHintStrip { isPresentingUpgrade = true }
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .homeScrollContentInsets()
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.basedOnSize)
        } else {
            HomeEmptyPrompt(
                inputMode: inputMode,
                recentRecords: recentPreviewRecords,
                onExampleTap: { example in
                    bottomInputText = example
                    processInput(example)
                },
                onShowAllRecords: { showAllRecords = true }
            )
        }
    }

    @ViewBuilder
    private var captureOutputContent: some View {
        if isPresentingCaptureSheet, let edit = captureEdit {
            ScrollView(showsIndicators: false) {
                CapturePendingCard(state: edit)
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 10)
            }
            .homeScrollContentInsets()
        } else {
            HomeEmptyPrompt(
                inputMode: .capture,
                recentRecords: recentPreviewRecords,
                onExampleTap: { example in
                    bottomInputText = example
                    beginCapturePreview(for: example)
                },
                onShowAllRecords: { showAllRecords = true }
            )
        }
    }

    private var capturePreviewSheet: some View {
        NavigationStack {
            CapturePreviewEditor(
                state: Binding(
                    get: { self.captureEdit ?? CaptureEditState.from(rawText: "") },
                    set: { self.captureEdit = $0 }
                ),
                isExpanded: true,
                onCancel: {
                    cancelPendingCapture()
                    isPresentingCaptureSheet = false
                },
                onConfirm: {
                    confirmPendingCapture()
                    isPresentingCaptureSheet = false
                }
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 4)
            .navigationTitle("记下预览")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    // MARK: - Actions

    private func beginCapturePreview(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            captureEdit = nil
            isPresentingCaptureSheet = false
            return
        }
        let edit = CaptureEditState.from(
            rawText: trimmed,
            existingRecords: proStore.isPro ? viewModel.store.activeRecords : []
        )
        captureEdit = edit
        isPresentingCaptureSheet = true
    }

    private func handleInputModeChange(_ newMode: BottomInputMode) {
        switch newMode {
        case .ask:
            captureEdit = nil
            isPresentingCaptureSheet = false
        case .capture:
            viewModel.clearQueryState()
            let text = MemoryQueryRouter.normalize(bottomInputText)
            if !text.isEmpty {
                beginCapturePreview(for: text)
            } else {
                captureEdit = nil
                isPresentingCaptureSheet = false
            }
        }
    }

    private func cancelPendingCapture() {
        captureEdit = nil
        isPresentingCaptureSheet = false
        bottomInputText = ""
    }

    private func processInput(_ raw: String) {
        let text = MemoryQueryRouter.normalize(raw)
        guard !text.isEmpty else { return }

        bottomInputText = text

        if MemoryUpdateRouter.isUpdateStatement(text) {
            captureEdit = nil
            isPresentingCaptureSheet = false
            inputMode = .ask
            viewModel.answer(question: text, proStore: proStore)
            isBottomInputFocused = false
            return
        }

        switch inputMode {
        case .ask:
            captureEdit = nil
            isPresentingCaptureSheet = false
            viewModel.answer(question: text, proStore: proStore)
        case .capture:
            viewModel.clearQueryState()
            beginCapturePreview(for: text)
        }
        isBottomInputFocused = false
    }

    private func confirmPendingCapture() {
        guard let state = captureEdit else { return }

        do {
            let saved = try viewModel.store.saveFromCapture(state)
            captureEdit = nil
            isPresentingCaptureSheet = false
            bottomInputText = ""
            inputMode = .ask
            if let record = saved.first, state.isUpdatingExisting {
                let place = record.placeDescription ?? ""
                viewModel.displayQueryResult = MemoryQueryResult(
                    found: true,
                    answer: place.isEmpty
                        ? "好的，已更新\(record.title)。"
                        : "好的，已将\(record.title)更新为在\(place)。",
                    records: []
                )
            } else {
                viewModel.clearQueryState()
            }
        } catch {
            voiceErrorMessage = error.localizedDescription
        }
    }

    private func handleVoiceActivated() async {
        if inputMode == .capture {
            captureEdit = nil
            isPresentingCaptureSheet = false
        }
        await speechRecognizer.startRecording()
        if let error = speechRecognizer.errorMessage {
            voiceErrorMessage = error
            voiceNeedsSettings = speechRecognizer.needsSettingsRedirect
        }
    }

    private func handleVoiceReleased() {
        guard speechRecognizer.isRecording else { return }
        speechRecognizer.stopRecording()
        let text = speechRecognizer.cleanedTranscript()
        guard !text.isEmpty else {
            voiceErrorMessage = "没听清，请再说一次"
            voiceNeedsSettings = false
            return
        }
        bottomInputText = text
        processInput(text)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 子视图

private struct AnswerStrip: View {
    let answer: String
    let found: Bool
    var isLLMAnswer: Bool = false
    var isLoading: Bool = false

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(colors.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: isLLMAnswer ? "sparkles" : (found ? "text.bubble.fill" : "info.circle"))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(colors.accent)
                }

                Text(isLLMAnswer ? "AI 回答" : "回答")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.secondaryText)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer(minLength: 0)
            }

            Text(answer)
                .font(.body.weight(.medium))
                .foregroundStyle(colors.primaryText)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(18)
        .appCard()
    }
}

private struct QueryLoadingCard: View {
    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        HStack(spacing: 14) {
            ProgressView()
            VStack(alignment: .leading, spacing: 5) {
                Text("正在整理回答")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.primaryText)
                Text("稍等片刻…")
                    .font(.caption)
                    .foregroundStyle(colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .appCard()
    }
}

private struct CapturePendingCard: View {
    let state: CaptureEditState

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "square.and.pencil")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("正在确认记下")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.primaryText)
                    Text("在弹窗中编辑并确认")
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                pendingRow(label: "内容", value: state.title.isEmpty ? "待填写" : state.title)
                if !state.placeDescription.isEmpty {
                    pendingRow(label: "位置", value: state.placeDescription)
                }
                if state.hasDueDate {
                    pendingRow(
                        label: "时间",
                        value: state.dueDate.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .padding(14)
            .appSoftCard(radius: 14, tint: colors.accent)
        }
        .padding(18)
        .appCard()
    }

    private func pendingRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ThemeColors(scheme: currentTheme).secondaryText)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ThemeColors(scheme: currentTheme).primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NLUpdateUpgradeStrip: View {
    let onUpgrade: () -> Void

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        Button(action: onUpgrade) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.purple)
                Text("说话即可更新，升级 Pro 解锁")
                    .font(.caption)
                    .foregroundStyle(colors.secondaryText)
                Spacer()
                Text("了解")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple, in: Capsule())
            }
            .padding(16)
            .appCard(radius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct UpgradeHintStrip: View {
    let onUpgrade: () -> Void

    @Environment(\.currentTheme) private var currentTheme

    var body: some View {
        let colors = ThemeColors(scheme: currentTheme)
        Button(action: onUpgrade) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.purple)
                Text("升级 Pro 获取 AI 建议")
                    .font(.caption)
                    .foregroundStyle(colors.secondaryText)
                Spacer()
                Text("升级")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(colors.accent, in: Capsule())
            }
            .padding(16)
            .appCard(radius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
