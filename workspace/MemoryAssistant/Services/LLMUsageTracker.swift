import Foundation

/// AI API 用量追踪与配额管理
///
/// 功能：
/// - 记录每日调用次数
/// - 区分 Pro / 免费版配额
/// - 记录 token 使用量
/// - 持久化到本地（无服务器方案）
@MainActor
final class LLMUsageTracker: ObservableObject {

    // MARK: - 数据结构

    struct DailyUsage: Codable, Equatable {
        let date: String // yyyy-MM-dd
        var callCount: Int
        var totalTokens: Int
        var successCount: Int
        var failureCount: Int

        static func empty(for dateString: String) -> DailyUsage {
            DailyUsage(
                date: dateString,
                callCount: 0,
                totalTokens: 0,
                successCount: 0,
                failureCount: 0
            )
        }
    }

    struct UsageSummary: Codable, Equatable {
        let totalCalls: Int
        let totalTokens: Int
        let daysTracked: Int
        let last7DaysCalls: Int
        let last7DaysTokens: Int
    }

    // MARK: - 配额配置

    enum Quota {
        case free
        case pro

        var dailyCallLimit: Int {
            switch self {
            case .free: return 5
            case .pro: return 200
            }
        }

        var hourlyCallLimit: Int {
            switch self {
            case .free: return 3
            case .pro: return 30
            }
        }

        var displayName: String {
            switch self {
            case .free: return "免费版"
            case .pro: return "Pro 会员"
            }
        }
    }

    // MARK: - 存储键

    private let usageKey = "llm.usage.tracker.history.v1"
    private let customQuotaKey = "llm.usage.tracker.customquota.v1"
    private let usageResetKey = "llm.usage.tracker.lastreset.v1"

    // MARK: - 发布属性

    @Published private(set) var todayUsage: DailyUsage
    @Published private(set) var isQuotaEnabled: Bool = true
    @Published var customDailyLimit: Int? = nil // 管理员可覆盖（调试用）
    @Published private(set) var history: [DailyUsage] = []

    // MARK: - 单例

    static let shared = LLMUsageTracker()

    private init() {
        let today = Self.todayKey()
        self.todayUsage = DailyUsage.empty(for: today)
        loadHistory()
        ensureTodayEntry()
    }

    // MARK: - 配额判断

    var currentQuota: Quota {
        LLMSettings.isProUnlocked ? .pro : .free
    }

    var effectiveDailyLimit: Int {
        customDailyLimit ?? currentQuota.dailyCallLimit
    }

    var todayRemainingCalls: Int {
        todayUsage.callCount
    }

    var todayRemainingQuota: Int {
        max(0, effectiveDailyLimit - todayUsage.callCount)
    }

    var todayUsedPercent: Double {
        guard effectiveDailyLimit > 0 else { return 0 }
        return Double(todayUsage.callCount) / Double(effectiveDailyLimit)
    }

    var hasQuotaRemaining: Bool {
        if !isQuotaEnabled { return true }
        return todayUsage.callCount < effectiveDailyLimit
    }

    // MARK: - 记录调用

    func recordCall(success: Bool, tokens: Int = 0) {
        ensureTodayEntry()
        todayUsage.callCount += 1
        todayUsage.totalTokens += tokens
        if success {
            todayUsage.successCount += 1
        } else {
            todayUsage.failureCount += 1
        }
        saveHistory()
    }

    // MARK: - 统计汇总

    var summary: UsageSummary {
        let sorted = history.sorted { $0.date > $1.date }
        let last7 = Array(sorted.prefix(7))
        return UsageSummary(
            totalCalls: history.reduce(0) { $0 + $1.callCount },
            totalTokens: history.reduce(0) { $0 + $1.totalTokens },
            daysTracked: history.count,
            last7DaysCalls: last7.reduce(0) { $0 + $1.callCount },
            last7DaysTokens: last7.reduce(0) { $0 + $1.totalTokens }
        )
    }

    /// 最近 N 天的每日调用量（用于图表展示）
    func lastDays(_ days: Int) -> [(date: String, calls: Int, tokens: Int)] {
        let calendar = Calendar.current
        var result: [(date: String, calls: Int, tokens: Int)] = []
        for offset in 0..<days {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = Self.dateKey(from: d)
            if let usage = history.first(where: { $0.date == key }) {
                result.append((key, usage.callCount, usage.totalTokens))
            } else {
                result.append((key, 0, 0))
            }
        }
        return result.reversed()
    }

    // MARK: - 管理员操作

    func resetToday() {
        todayUsage = DailyUsage.empty(for: Self.todayKey())
        saveHistory()
    }

    func resetAll() {
        history.removeAll()
        todayUsage = DailyUsage.empty(for: Self.todayKey())
        saveHistory()
    }

    func setCustomDailyLimit(_ limit: Int?) {
        customDailyLimit = limit
        if let limit = limit {
            UserDefaults.standard.set(limit, forKey: customQuotaKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customQuotaKey)
        }
    }

    func setQuotaEnabled(_ enabled: Bool) {
        isQuotaEnabled = enabled
    }

    // MARK: - 导出数据

    func exportAsJSON() -> String {
        let exportData: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "currentQuota": currentQuota.displayName,
            "dailyLimit": effectiveDailyLimit,
            "summary": [
                "totalCalls": summary.totalCalls,
                "totalTokens": summary.totalTokens,
                "daysTracked": summary.daysTracked,
                "last7DaysCalls": summary.last7DaysCalls,
                "last7DaysTokens": summary.last7DaysTokens
            ],
            "history": history.map { usage in
                [
                    "date": usage.date,
                    "callCount": usage.callCount,
                    "totalTokens": usage.totalTokens,
                    "successCount": usage.successCount,
                    "failureCount": usage.failureCount
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
        var csv = "日期,调用次数,Token 数,成功,失败\n"
        for usage in history.sorted(by: { $0.date < $1.date }) {
            csv += "\(usage.date),\(usage.callCount),\(usage.totalTokens),\(usage.successCount),\(usage.failureCount)\n"
        }
        csv += "\n汇总:\n"
        csv += "总调用次数,\(summary.totalCalls)\n"
        csv += "总 Token,\(summary.totalTokens)\n"
        csv += "追踪天数,\(summary.daysTracked)\n"
        return csv
    }

    // MARK: - Private

    private static func todayKey() -> String {
        dateKey(from: Date())
    }

    private static func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: usageKey),
              let decoded = try? JSONDecoder().decode([DailyUsage].self, from: data) else {
            history = []
            return
        }
        history = decoded

        // 加载自定义配额
        if let custom = UserDefaults.standard.object(forKey: customQuotaKey) as? Int {
            customDailyLimit = custom
        }
    }

    private func ensureTodayEntry() {
        let todayKey = Self.todayKey()

        // 如果今天还没记录，则创建
        if let existing = history.first(where: { $0.date == todayKey }) {
            todayUsage = existing
        } else {
            todayUsage = DailyUsage.empty(for: todayKey)
            if todayUsage.callCount == 0 {
                // 不重复添加空条目
            }
            history.append(todayUsage)
            saveHistory()
        }
    }

    private func saveHistory() {
        // 更新 history 中的 today 数据
        if let index = history.firstIndex(where: { $0.date == todayUsage.date }) {
            history[index] = todayUsage
        } else {
            history.append(todayUsage)
        }

        // 只保留最近 60 天
        if history.count > 60 {
            history = Array(history.sorted { $0.date > $1.date }.prefix(60))
        }

        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: usageKey)
        }
    }
}
