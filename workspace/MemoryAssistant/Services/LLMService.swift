import Foundation

enum LLMService {
    // MARK: - Prompt Templates（集中管理，便于后续 A/B 测试）

    private static let systemPromptTemplate = """
        你是「记忆助手」的智能大脑。根据用户已记录的个人事实回答问题。
        要求：
        1. 优先依据用户记录，不要编造用户没记过的事实。
        2. 开放性问题（如做饭、建议）可结合记录给出实用建议。
        3. 用户表达身体状态或生活需求时（如「我渴了」「我饿了」），结合记录里的食物、饮品给出贴心建议，并说明在哪。
        4. 涉及食材新鲜度时，可参考记录时间，并提醒用户结合气味色泽判断。
        5. 用简洁完整的中文回答，适合语音朗读，把话说完，不超过 400 字。
        6. 若记录不足，诚实说明并告诉用户可以先记下相关信息。
        7. 直接给出最终回答，不要输出思考过程。
        """

    private static let userPromptTemplateWithRecords = """
        用户记录：
        %@

        用户问题：%@
        """

    private static let userPromptTemplateEmpty = """
        （用户暂无记录。）

        用户问题：%@
        """

    // MARK: - 记录字段
    private static let recordLabelTitle = "物品/事项"
    private static let recordLabelPlace = "位置"
    private static let recordLabelDue = "时间"
    private static let recordLabelCreated = "记录于"
    private static let recordLabelNote = "备注"

    static func answer(question: String, records: [MemoryRecord]) async -> MemoryQueryResult? {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let context = buildContext(from: records)
        let related = relatedRecords(for: trimmed, from: records)
        let fallback = MemoryBrain.answer(question: trimmed, in: records)
        let contextRecords = related.isEmpty ? fallback.records : related

        guard LLMSettings.isAvailable else {
            if LLMSettings.isProUnlocked, let smart = MemoryInventoryAnswer.answer(question: trimmed, in: records) {
                return MemoryQueryResult(
                    found: smart.found,
                    answer: smart.answer,
                    records: smart.records,
                    source: .llm
                )
            }
            if LLMSettings.isProUnlocked {
                return MemoryQueryResult(
                    found: fallback.found,
                    answer: fallback.found
                        ? fallback.answer + "\n\n（Pro 智能汇总：已结合你的记录回答。）"
                        : fallback.answer + "\n\n（Pro 已启用；完整 AI 回答需配置模型服务。）",
                    records: fallback.records,
                    source: fallback.found ? .llm : .rules
                )
            }
            return MemoryQueryResult(
                found: fallback.found,
                answer: fallback.answer + "\n\n（开通 Pro 后可使用 AI 智能回答。）",
                records: fallback.records,
                source: .rules
            )
        }

        let startTime = Date()
        let usedModel = LLMConfig.modelCandidates.first ?? "unknown"

        do {
            let reply = try await requestCompletion(question: trimmed, context: context)
            let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

            Task { @MainActor in
                LLMUsageTracker.shared.recordCall(success: true)
                LLMRequestLogger.shared.logRequest(
                    question: trimmed,
                    model: usedModel,
                    status: .success,
                    responseTimeMs: responseTimeMs
                )
            }

            return MemoryQueryResult(
                found: true,
                answer: reply,
                records: contextRecords,
                source: .llm
            )
        } catch let error as LLMServiceError {
            let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let hint = error.userMessage

            Task { @MainActor in
                LLMUsageTracker.shared.recordCall(success: false)
                LLMRequestLogger.shared.logRequest(
                    question: trimmed,
                    model: usedModel,
                    status: .failed,
                    responseTimeMs: responseTimeMs,
                    errorMessage: hint
                )
            }

            return MemoryQueryResult(
                found: fallback.found,
                answer: fallback.answer + "\n\n（\(hint)）",
                records: fallback.records,
                source: .rules
            )
        } catch {
            let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

            Task { @MainActor in
                LLMUsageTracker.shared.recordCall(success: false)
                LLMRequestLogger.shared.logRequest(
                    question: trimmed,
                    model: usedModel,
                    status: .failed,
                    responseTimeMs: responseTimeMs,
                    errorMessage: "未知错误"
                )
            }

            return MemoryQueryResult(
                found: fallback.found,
                answer: fallback.answer + "\n\n（智能回答暂时不可用，已为你展示基础结果。）",
                records: fallback.records,
                source: .rules
            )
        }
    }

    // MARK: - Private

    private static func buildContext(from records: [MemoryRecord]) -> String {
        let lines = records.prefix(50).map { record in
            var parts = ["\(recordLabelTitle)：\(record.title)"]
            if let place = record.placeDescription, !place.isEmpty {
                parts.append("\(recordLabelPlace)：\(place)")
            }
            if let due = record.dueDate {
                parts.append("\(recordLabelDue)：\(due.formatted(date: .abbreviated, time: .shortened))")
            }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: record.createdAt),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
            parts.append("\(recordLabelCreated)：\(days == 0 ? "今天" : "\(days)天前")")
            if !record.details.isEmpty, record.details != record.title {
                parts.append("\(recordLabelNote)：\(record.details)")
            }
            return parts.joined(separator: "，")
        }
        return lines.joined(separator: "\n")
    }

    private static func relatedRecords(for question: String, from records: [MemoryRecord]) -> [MemoryRecord] {
        if MemoryQueryRouter.needsLLM(for: question) {
            let ingredients = IngredientInventory.fromRecords(records).map(\.record)
            if !ingredients.isEmpty {
                return ingredients
            }
        }
        return []
    }

    private static func requestCompletion(question: String, context: String) async throws -> String {
        var lastError: LLMServiceError = .allModelsFailed

        for model in LLMSettings.modelCandidates {
            do {
                return try await requestCompletion(question: question, context: context, model: model)
            } catch let error as LLMServiceError {
                lastError = error
                if case .modelUnavailable = error { continue }
                throw error
            }
        }

        throw lastError
    }

    private static func requestCompletion(question: String, context: String, model: String) async throws -> String {
        guard let url = LLMSettings.chatCompletionsURL else {
            throw LLMServiceError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(LLMSettings.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let systemPrompt = systemPromptTemplate

        let userPrompt: String
        if context.isEmpty {
            userPrompt = String(format: userPromptTemplateEmpty, question)
        } else {
            userPrompt = String(format: userPromptTemplateWithRecords, context, question)
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.4,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMServiceError.badResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if http.statusCode == 403 || http.statusCode == 404 {
                    throw LLMServiceError.modelUnavailable(apiError.message ?? "模型不可用")
                }
                throw LLMServiceError.apiMessage(apiError.message ?? "请求失败（\(http.statusCode)）")
            }
            throw LLMServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.replyText,
              !content.isEmpty else {
            throw LLMServiceError.emptyReply
        }
        return content
    }
}

private enum LLMServiceError: Error {
    case badResponse
    case emptyReply
    case modelUnavailable(String)
    case apiMessage(String)
    case allModelsFailed

    var userMessage: String {
        switch self {
        case .badResponse:
            return "智能回答暂时不可用，已为你展示基础结果"
        case .emptyReply:
            return "AI 未返回有效内容，已为你展示基础结果"
        case .modelUnavailable:
            return "AI 模型暂时不可用，已为你展示基础结果"
        case .apiMessage(let message):
            return "AI 服务异常：\(message)"
        case .allModelsFailed:
            return "AI 模型均不可用，已为你展示基础结果"
        }
    }
}

private struct APIErrorResponse: Decodable {
    let code: Int?
    let message: String?
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
            let reasoning_content: String?

            var replyText: String? {
                let text = content?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let text, !text.isEmpty { return text }
                return nil
            }
        }
        let message: Message
    }
    let choices: [Choice]
}
