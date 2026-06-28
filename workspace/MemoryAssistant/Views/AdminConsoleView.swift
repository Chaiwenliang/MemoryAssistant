import SwiftUI

/// AI 管理控制台 - 隐藏入口（仅开发者可见）
///
/// 入口方式：
/// 1. 设置页面连续点击版本号 5 次
/// 2. 通过 deep link: memoryassistant://admin
struct AdminConsoleView: View {

    @StateObject private var usageTracker = LLMUsageTracker.shared
    @StateObject private var requestLogger = LLMRequestLogger.shared
    @State private var showShareSheet = false
    @State private var shareContent: String = ""
    @State private var shareIsCSV = false
    @State private var customQuotaInput: String = ""
    @State private var testQuestion: String = ""
    @State private var testResponse: String = ""
    @State private var isTesting = false
    @State private var selectedModel: String = LLMConfig.modelCandidates.first ?? ""

    var body: some View {
        NavigationStack {
            List {
                sectionSummary
                sectionChart
                sectionQuota
                sectionLogs
                sectionExport
                sectionTest
                sectionDanger
            }
            .navigationTitle("AI 管理控制台")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: [shareContent.data(using: .utf8) ?? Data()])
            }
        }
    }

    // MARK: - 汇总卡片

    private var sectionSummary: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    statCard(title: "今日调用", value: "\(usageTracker.todayRemainingCalls)", color: .blue)
                    statCard(title: "今日配额", value: "\(usageTracker.effectiveDailyLimit)", color: .orange)
                }

                HStack(spacing: 12) {
                    statCard(title: "总调用", value: "\(usageTracker.summary.totalCalls)", color: .purple)
                    statCard(title: "追踪天数", value: "\(usageTracker.summary.daysTracked)", color: .green)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("今日使用进度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(1.0, usageTracker.todayUsedPercent))
                        .tint(usageTracker.todayUsedPercent > 0.8 ? .orange : .blue)
                    Text(String(format: "%.0f%% (%d / %d)",
                                usageTracker.todayUsedPercent * 100,
                                usageTracker.todayRemainingCalls,
                                usageTracker.effectiveDailyLimit))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                HStack {
                    Text("当前套餐")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(usageTracker.currentQuota.displayName)
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Text("API 状态")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(LLMSettings.isAvailable ? "可用" : "未配置")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LLMSettings.isAvailable ? Color.green : Color.red)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("用量汇总")
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 趋势图

    private var sectionChart: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("近 7 天调用趋势")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                UsageChartView(data: usageTracker.lastDays(7))
                    .frame(height: 140)
                    .padding(.vertical, 8)
            }
            .padding(.vertical, 6)
        } header: {
            Text("使用趋势")
        }
    }

    // MARK: - 配额设置

    private var sectionQuota: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用配额限制", isOn: Binding(
                    get: { usageTracker.isQuotaEnabled },
                    set: { usageTracker.setQuotaEnabled($0) }
                ))
                .tint(.blue)

                HStack {
                    Text("每日调用上限")
                        .font(.subheadline)
                    Spacer()
                    TextField("默认：\(usageTracker.currentQuota.dailyCallLimit)",
                             text: Binding(
                                get: { customQuotaInput.isEmpty ? "" : customQuotaInput },
                                set: { newValue in
                                    customQuotaInput = newValue
                                    if newValue.isEmpty {
                                        usageTracker.setCustomDailyLimit(nil)
                                    } else if let limit = Int(newValue), limit > 0 {
                                        usageTracker.setCustomDailyLimit(limit)
                                    }
                                }
                             ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }

                if let custom = usageTracker.customDailyLimit {
                    Text("当前自定义配额：\(custom) 次/日")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("使用默认配额：\(usageTracker.currentQuota.dailyCallLimit) 次/日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("配额设置")
        } footer: {
            Text("用于测试不同配额场景，不影响真实用户体验。")
        }
    }

    // MARK: - 调用日志

    private var sectionLogs: some View {
        Section {
            if requestLogger.logs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("暂无调用记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("成功: \(requestLogger.successCount)")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("失败: \(requestLogger.failureCount)")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                        Text("平均响应: \(requestLogger.averageResponseTimeMs)ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(requestLogger.logs.prefix(20)) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(log.status == .success ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(log.formattedDate)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(log.model)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Text("\(log.responseTimeMs)ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(log.question)
                                .font(.subheadline)
                                .lineLimit(2)
                            if let error = log.errorMessage {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)

                        if log.id != requestLogger.logs.prefix(20).last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("最近调用")
        }
    }

    // MARK: - 导出

    private var sectionExport: some View {
        Section {
            VStack(spacing: 10) {
                Button {
                    shareContent = usageTracker.exportAsJSON()
                    shareIsCSV = false
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出用量数据 (JSON)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Button {
                    shareContent = usageTracker.exportAsCSV()
                    shareIsCSV = true
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "tablecells")
                        Text("导出用量数据 (CSV)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Button {
                    shareContent = requestLogger.exportAsJSON()
                    shareIsCSV = false
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("导出请求日志 (JSON)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Button {
                    shareContent = requestLogger.exportAsCSV()
                    shareIsCSV = true
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("导出请求日志 (CSV)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("数据导出")
        } footer: {
            Text("可通过分享面板保存到文件、发送邮件等，便于后续在电脑上分析。")
        }
    }

    // MARK: - 模型测试

    private var sectionTest: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Picker("测试模型", selection: $selectedModel) {
                    ForEach(LLMConfig.modelCandidates, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    TextField("测试问题...", text: $testQuestion)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await runTest() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.blue)
                    }
                    .disabled(testQuestion.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)
                }

                if isTesting {
                    HStack {
                        ProgressView()
                        Text("正在测试...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else if !testResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("测试结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(testResponse)
                            .font(.subheadline)
                            .lineLimit(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("模型测试")
        }
    }

    // MARK: - 危险操作

    private var sectionDanger: some View {
        Section {
            Button(role: .destructive) {
                usageTracker.resetToday()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重置今日用量")
                }
            }

            Button(role: .destructive) {
                usageTracker.resetAll()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空全部用量统计")
                }
            }

            Button(role: .destructive) {
                requestLogger.clearAll()
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("清空全部请求日志")
                }
            }
        } header: {
            Text("危险操作")
        } footer: {
            Text("此操作仅清除本地数据，不影响 API Key 或账号。")
        }
    }

    // MARK: - 测试方法

    private func runTest() async {
        isTesting = true
        testResponse = ""

        let startTime = Date()
        let question = testQuestion.trimmingCharacters(in: .whitespaces)

        do {
            let result = await LLMService.answer(question: question, records: [])
            let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)

            if let result, !result.answer.isEmpty {
                testResponse = "✓ 成功：\(result.answer)"
                requestLogger.logRequest(
                    question: question,
                    model: selectedModel,
                    status: .success,
                    responseTimeMs: responseTime
                )
            } else {
                testResponse = "⚠ 返回为空（可能走规则逻辑或模型不可用）"
                requestLogger.logRequest(
                    question: question,
                    model: selectedModel,
                    status: .failed,
                    responseTimeMs: responseTime,
                    errorMessage: "空返回"
                )
            }
        }

        isTesting = false
    }
}

// MARK: - 简易柱状图

private struct UsageChartView: View {
    let data: [(date: String, calls: Int, tokens: Int)]

    var maxCalls: Int {
        let max = data.map { $0.calls }.max() ?? 0
        return max > 0 ? max : 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Text("\(item.calls)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(item.calls > 0 ? Color.blue : Color.gray.opacity(0.2))
                        .frame(height: barHeight(for: item.calls))
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text(String(item.date.suffix(5)))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for calls: Int) -> CGFloat {
        let ratio = CGFloat(calls) / CGFloat(maxCalls)
        return max(4, ratio * 100)
    }
}

// MARK: - 分享面板封装

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
