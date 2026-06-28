import AppIntents
import Foundation

// MARK: - 自然语言提问

struct AskMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "提问"
    static var description = IntentDescription("用自然语言查询你已经记录的内容。")
    static var openAppWhenRun = false

    @Parameter(title: "问题")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("问 \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let normalized = MemoryQueryRouter.normalize(question)
        let isPro = UserDefaults.standard.bool(forKey: "memory.assistant.pro.unlocked")
        let ruleAnswer = MemoryBrain.answer(question: normalized)
        let result: MemoryQueryResult
        if MemoryQueryRouter.shouldUseLLM(for: normalized, ruleResult: ruleAnswer, isPro: isPro) {
            result = await LLMService.answer(question: normalized, records: MemoryBrain.loadRecords())
                ?? ruleAnswer
        } else {
            result = ruleAnswer
        }
        return .result(dialog: IntentDialog(stringLiteral: result.answer))
    }
}

// MARK: - 按标题查找（快捷指令补全）

struct FindMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "查找记录"
    static var description = IntentDescription("根据关键词找到最相关的记忆。")
    static var openAppWhenRun = false

    @Parameter(title: "查询记录")
    var query: MemoryAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("查找 \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = MemoryBrain.answer(question: query.title)
        return .result(dialog: IntentDialog(stringLiteral: result.answer))
    }
}

// MARK: - 一句话记录

struct CaptureMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "记录"
    static var description = IntentDescription("把一句话保存到记忆助手。")
    static var openAppWhenRun = false

    @Parameter(title: "记录内容")
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$content)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let records = try MemoryBrain.capture(from: content)
            return .result(dialog: IntentDialog(stringLiteral: MemoryBrain.captureConfirmation(for: records)))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
        }
    }
}

// MARK: - 明天安排

struct TomorrowScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "查看明天安排"
    static var description = IntentDescription("汇总明天的日程安排。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = MemoryBrain.tomorrowSummary()
        return .result(dialog: IntentDialog(stringLiteral: answer))
    }
}

// MARK: - 快捷指令

struct MemoryShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: CaptureMemoryIntent(),
            phrases: [
                "用 \(.applicationName) 快速记录",
                "在 \(.applicationName) 里记一下",
                "记到 \(.applicationName)",
                "\(.applicationName) 帮我记一下"
            ],
            shortTitle: "记录",
            systemImageName: "mic.badge.plus"
        ),
        AppShortcut(
            intent: AskMemoryIntent(),
            phrases: [
                "问 \(.applicationName)",
                "用 \(.applicationName) 查一下",
                "问问 \(.applicationName)"
            ],
            shortTitle: "提问",
            systemImageName: "text.bubble"
        ),
        AppShortcut(
            intent: FindMemoryIntent(),
            phrases: [
                "在 \(.applicationName) 中查询 \(\.$query)",
                "用 \(.applicationName) 找 \(\.$query)"
            ],
            shortTitle: "查找",
            systemImageName: "magnifyingglass"
        ),
        AppShortcut(
            intent: TomorrowScheduleIntent(),
            phrases: [
                "查看 \(.applicationName) 的明天安排",
                "问 \(.applicationName) 明天有什么安排"
            ],
            shortTitle: "明天安排",
            systemImageName: "calendar"
        )
    ]
}
