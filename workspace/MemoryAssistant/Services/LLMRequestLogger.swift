import Foundation

/// AI 请求详细日志（单条请求记录）
///
/// 记录每一次 AI API 调用的完整上下文
struct LLMRequestLog: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let question: String
    let model: String
    let status: RequestStatus
    let responseTimeMs: Int
    let tokenEstimate: Int
    let errorMessage: String?

    enum RequestStatus: String, Codable {
        case success
        case failed
        case rateLimited
        case quotaExceeded
    }

    var statusTitle: String {
        switch status {
        case .success: return "成功"
        case .failed: return "失败"
        case .rateLimited: return "限流"
        case .quotaExceeded: return "配额用尽"
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

/// AI 请求日志管理
///
/// 功能：
/// - 记录最近 N 条请求日志
/// - 文件持久化
/// - 支持导出
@MainActor
final class LLMRequestLogger: ObservableObject {

    // MARK: - 配置

    private let maxLogs = 100 // 最多保留 100 条

    // MARK: - 存储

    private var logsFileURL: URL {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("llm_request_logs.json")
    }

    // MARK: - 发布属性

    @Published private(set) var logs: [LLMRequestLog] = []

    // MARK: - 单例

    static let shared = LLMRequestLogger()

    private init() {
        loadLogs()
    }

    // MARK: - 记录

    func logRequest(
        question: String,
        model: String,
        status: LLMRequestLog.RequestStatus,
        responseTimeMs: Int,
        tokenEstimate: Int = 0,
        errorMessage: String? = nil
    ) {
        let log = LLMRequestLog(
            id: UUID(),
            timestamp: Date(),
            question: question,
            model: model,
            status: status,
            responseTimeMs: responseTimeMs,
            tokenEstimate: tokenEstimate,
            errorMessage: errorMessage
        )

        logs.insert(log, at: 0)

        if logs.count > maxLogs {
            logs = Array(logs.prefix(maxLogs))
        }

        saveLogs()
    }

    // MARK: - 查询

    var successCount: Int {
        logs.filter { $0.status == .success }.count
    }

    var failureCount: Int {
        logs.filter { $0.status != .success }.count
    }

    var averageResponseTimeMs: Int {
        let successLogs = logs.filter { $0.status == .success }
        guard !successLogs.isEmpty else { return 0 }
        return successLogs.reduce(0) { $0 + $1.responseTimeMs } / successLogs.count
    }

    var totalTokenEstimate: Int {
        logs.reduce(0) { $0 + $1.tokenEstimate }
    }

    /// 获取近 N 小时内的请求
    func logsSince(hours: Int) -> [LLMRequestLog] {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        return logs.filter { $0.timestamp >= cutoff }
    }

    /// 按模型分组统计
    func statsByModel() -> [(model: String, count: Int, avgResponseMs: Int)] {
        let grouped = Dictionary(grouping: logs, by: { $0.model })
        return grouped.map { model, modelLogs in
            let avgMs = modelLogs.reduce(0) { $0 + $1.responseTimeMs } / max(modelLogs.count, 1)
            return (model, modelLogs.count, avgMs)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - 管理员操作

    func clearAll() {
        logs.removeAll()
        saveLogs()
    }

    // MARK: - 导出

    func exportAsJSON() -> String {
        let exportData: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "totalLogs": logs.count,
            "summary": [
                "successCount": successCount,
                "failureCount": failureCount,
                "avgResponseTimeMs": averageResponseTimeMs,
                "totalTokenEstimate": totalTokenEstimate
            ],
            "logs": logs.map { log in
                [
                    "id": log.id.uuidString,
                    "timestamp": ISO8601DateFormatter().string(from: log.timestamp),
                    "question": log.question,
                    "model": log.model,
                    "status": log.status.rawValue,
                    "responseTimeMs": log.responseTimeMs,
                    "tokenEstimate": log.tokenEstimate,
                    "errorMessage": log.errorMessage ?? ""
                ]
            }
        ]
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            return String(data: jsonData, encoding: .utf8) ?? ""
        }
        return ""
    }

    func exportAsCSV() -> String {
        var csv = "时间,模型,问题,状态,响应时间(ms),Token 估计,错误信息\n"
        for log in logs {
            let cleanQuestion = log.question
                .replacingOccurrences(of: "\"", with: "\"\"")
                .prefix(50)
            csv += "\(log.formattedDate),\(log.model),\"\(cleanQuestion)\",\(log.statusTitle),\(log.responseTimeMs),\(log.tokenEstimate),\"\(log.errorMessage ?? "")\"\n"
        }
        return csv
    }

    // MARK: - Private

    private func loadLogs() {
        guard let data = try? Data(contentsOf: logsFileURL),
              let decoded = try? JSONDecoder().decode([LLMRequestLog].self, from: data) else {
            return
        }
        logs = decoded
    }

    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            try? encoded.write(to: logsFileURL, options: .atomic)
        }
    }
}
