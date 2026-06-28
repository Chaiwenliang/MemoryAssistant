import Foundation

/// Pro 会员内置的 LLM 配置，用户无需自行填写 Key。
enum LLMSettings {
    private static let proKey = "memory.assistant.pro.unlocked"

    static let modelCandidates = LLMConfig.modelCandidates

    static var isProUnlocked: Bool {
        UserDefaults.standard.bool(forKey: proKey)
    }

    static var isAvailable: Bool {
        isProUnlocked && !LLMSecrets.apiKey.isEmpty
    }

    static var chatCompletionsURL: URL? {
        URL(string: "\(LLMConfig.baseURL)/chat/completions")
    }

    static var authorizationHeader: String {
        "Bearer \(LLMSecrets.apiKey)"
    }
}
