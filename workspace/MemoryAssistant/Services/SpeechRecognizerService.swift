import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognizerService: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var hasMicrophonePermission = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var needsSettingsRedirect: Bool {
        switch authorizationStatus {
        case .denied, .restricted:
            return true
        case .authorized:
            return !hasMicrophonePermission
        default:
            return false
        }
    }

    func cleanedTranscript() -> String {
        Self.stripFillerWords(transcript)
    }

    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        authorizationStatus = speechStatus

        guard speechStatus == .authorized else {
            errorMessage = speechPermissionMessage(for: speechStatus)
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        hasMicrophonePermission = micGranted
        if !micGranted {
            errorMessage = "麦克风权限被拒绝。请前往 设置 → 记忆助手 → 麦克风 开启权限。"
        }
    }

    func startRecording() async {
        await ensurePermissions()

        guard authorizationStatus == .authorized else {
            if errorMessage == nil {
                errorMessage = speechPermissionMessage(for: authorizationStatus)
            }
            return
        }

        guard hasMicrophonePermission else {
            if errorMessage == nil {
                errorMessage = "麦克风权限被拒绝。请前往 设置 → 记忆助手 → 麦克风 开启权限。"
            }
            return
        }

        guard let speechRecognizer else {
            errorMessage = "无法创建中文语音识别器，请使用真机测试。"
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = "语音识别当前不可用。模拟器支持有限，建议在真机上测试，并确认已登录 iCloud 且网络正常。"
            return
        }

        stopRecording()
        transcript = ""
        errorMessage = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "音频会话初始化失败：\(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "无法获取有效的麦克风输入。模拟器上经常失败，请改用真机测试。"
            deactivateAudioSession()
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            errorMessage = "启动录音失败：\(error.localizedDescription)"
            cleanup()
            deactivateAudioSession()
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                }
            }

            if let error, !Self.shouldIgnoreRecognitionError(error) {
                Task { @MainActor in
                    self.errorMessage = "语音识别失败：\(error.localizedDescription)"
                    self.stopRecording()
                }
                return
            }

            if result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        isRecording = true
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        cleanup()
        deactivateAudioSession()
        isRecording = false
    }

    private func ensurePermissions() async {
        if authorizationStatus == .notDetermined || !hasMicrophonePermission {
            await requestPermissions()
        }
    }

    private func cleanup() {
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speechPermissionMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "语音识别权限被拒绝。请前往 设置 → 记忆助手 → 语音识别 开启权限。"
        case .restricted:
            return "当前设备限制了语音识别功能。"
        case .notDetermined:
            return "语音识别权限尚未授权。"
        default:
            return "请在系统设置中允许语音识别权限。"
        }
    }

    private static func shouldIgnoreRecognitionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // 用户主动停止、无语音输入等属于正常结束，不必弹错。
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 216 {
            return true
        }
        if nsError.code == 1110 {
            return true
        }
        return false
    }

    private static func stripFillerWords(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fillers = [
            "嗯嗯", "嗯", "啊", "呃", "那个", "就是", "然后", "这个",
            "哎", "哦", "喔", "那个啥", "那个那个", "那个...", "呃...",
            "你帮我", "帮我", "麻烦你", "请你", "我想", "我要", "我需要",
            "那个那个", "这个这个", "就是说", "就是吧", "那个吧",
            "嗯对", "嗯好", "对了", "好了", "好了好了"
        ]
        // 按长度从长到短替换，确保先替换组合词
        for filler in fillers.sorted(by: { $0.count > $1.count }) {
            result = result.replacingOccurrences(of: filler, with: "")
        }

        // 去掉重复空格和开头/结尾的标点
        result = result
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。；，,！!？? "))

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
