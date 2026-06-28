import Foundation

/// 非敏感 LLM 配置：改模型、接口地址时维护这个文件即可。
enum LLMConfig {
    static let baseURL = "https://code-api.x-aio.ai/v1"

    /// 按优先级尝试；前面的模型不可用会自动换下一个。
    static let modelCandidates = [
        "DeepSeek-V4-Flash",
        "Qwen3.5-35B-A3B",
        "Qwen3.5-Flash"
    ]
}
