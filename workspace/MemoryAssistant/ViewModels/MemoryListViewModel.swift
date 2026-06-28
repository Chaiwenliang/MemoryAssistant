import Foundation

@MainActor
final class MemoryListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var displayQueryResult: MemoryQueryResult?
    @Published var isLLMLoading = false
    @Published var showUpgradeHint = false
    @Published var showNLUpdateUpgradeHint = false

    let store: MemoryStore
    private var answerTask: Task<Void, Never>?
    private var answerGeneration = 0

    init(store: MemoryStore) {
        self.store = store
    }

    var isLLMAnswer: Bool {
        displayQueryResult?.source == .llm
    }

    func clearQueryState() {
        answerTask?.cancel()
        answerTask = nil
        searchText = ""
        displayQueryResult = nil
        showUpgradeHint = false
        showNLUpdateUpgradeHint = false
        isLLMLoading = false
    }

    /// 提问：先检索；免费版在结果上点选更新，Pro 可说话更新。
    func answer(question: String, proStore: MemoryProStore) {
        answerTask?.cancel()
        answerTask = nil

        let trimmed = MemoryQueryRouter.normalize(question)
        searchText = trimmed

        guard !trimmed.isEmpty else {
            clearQueryState()
            return
        }

        if let updateAction = MemoryUpdateRouter.parseUpdate(trimmed) {
            if proStore.isPro {
                handleUpdate(updateAction)
            } else {
                handleFreeTierUpdateAttempt(updateAction)
            }
            return
        }

        showNLUpdateUpgradeHint = false
        // 1. 先检索记录
        let ruleAnswer = MemoryBrain.answer(question: trimmed, in: store.activeRecords)
        let explicitLLM = MemoryQueryRouter.needsLLM(for: trimmed)
        let useLLM = MemoryQueryRouter.shouldUseLLM(
            for: trimmed,
            ruleResult: ruleAnswer,
            isPro: proStore.isPro
        )

        if explicitLLM, !proStore.isPro {
            displayQueryResult = ruleAnswer
            showUpgradeHint = true
            isLLMLoading = false
            return
        }

        showUpgradeHint = false

        // 2. 非开放性问题，或规则已足够 → 直接展示检索结果
        guard useLLM else {
            isLLMLoading = false
            displayQueryResult = ruleAnswer
            return
        }

        // 3. 开放性问题 + Pro → AI 结合记录回答
        answerGeneration += 1
        let generation = answerGeneration
        isLLMLoading = true

        answerTask = Task { @MainActor in
            defer {
                if generation == answerGeneration {
                    isLLMLoading = false
                }
            }

            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, generation == answerGeneration else { return }

            let llm = await LLMService.answer(question: trimmed, records: store.activeRecords)
            guard !Task.isCancelled, generation == answerGeneration else { return }

            displayQueryResult = llm ?? ruleAnswer
        }
    }

    func archiveRecord(_ record: MemoryRecord, proStore: MemoryProStore) {
        store.archive(record)
        refreshCurrentQuery(proStore: proStore)
    }

    func deleteRecord(_ record: MemoryRecord, proStore: MemoryProStore) {
        store.delete(record)
        refreshCurrentQuery(proStore: proStore)
    }

    func updateLocation(_ record: MemoryRecord, to place: String, proStore: MemoryProStore) {
        if place.isEmpty {
            var updated = record
            updated.placeDescription = nil
            updated.updatedAt = Date()
            store.update(updated)
        } else {
            store.moveRecord(record, to: place)
        }
        refreshCurrentQuery(proStore: proStore)
    }

    func refreshCurrentQuery(proStore: MemoryProStore) {
        guard !searchText.isEmpty else { return }
        let ruleAnswer = MemoryBrain.answer(question: searchText, in: store.activeRecords)
        displayQueryResult = ruleAnswer
        showNLUpdateUpgradeHint = false
    }

    private func handleFreeTierUpdateAttempt(_ action: MemoryUpdateAction) {
        answerTask?.cancel()
        answerTask = nil
        isLLMLoading = false
        showUpgradeHint = false
        showNLUpdateUpgradeHint = true

        let records = relatedRecords(for: action)
        displayQueryResult = MemoryQueryResult(
            found: !records.isEmpty,
            answer: records.isEmpty
                ? "免费版请先在提问结果中点选记录更新。升级 Pro 后可直接说「西瓜吃完了」。"
                : "请点下方记录的「位置」或「用完」来更新。升级 Pro 后可直接用说话更新。",
            records: records
        )
    }

    private func relatedRecords(for action: MemoryUpdateAction) -> [MemoryRecord] {
        switch action {
        case .consume(let request):
            return MemoryUpdateRouter.findTargets(request, in: store.activeRecords)
        case .move(let request):
            return MemoryUpdateRouter.findTargets(
                ConsumeRequest(itemQuery: request.itemQuery, placeQuery: request.fromPlaceQuery),
                in: store.activeRecords
            )
        }
    }

    private func handleUpdate(_ action: MemoryUpdateAction) {
        answerTask?.cancel()
        answerTask = nil
        isLLMLoading = false
        showUpgradeHint = false
        showNLUpdateUpgradeHint = false

        let result = MemoryUpdateRouter.apply(action, in: store.activeRecords)
        switch result {
        case .consumed(let records):
            store.archiveRecords(records)
        case .moved(let record, let place):
            store.moveRecord(record, to: place)
        case .notFound, .ambiguous:
            break
        }

        displayQueryResult = MemoryQueryResult(
            found: {
                switch result {
                case .notFound, .ambiguous: return false
                default: return true
                }
            }(),
            answer: MemoryUpdateRouter.message(for: result),
            records: {
                if case .ambiguous(_, let candidates) = result {
                    return candidates
                }
                return []
            }()
        )
    }

    func onSearchTextChanged(proStore: MemoryProStore) {
        answer(question: searchText, proStore: proStore)
    }

    var filteredRecords: [MemoryRecord] {
        let trimmed = MemoryQueryRouter.normalize(searchText)
        if trimmed.isEmpty {
            return store.activeRecords.sorted { $0.updatedAt > $1.updatedAt }
        }
        let answerRecords = displayQueryResult?.records ?? []
        let keywordRecords = MemorySearchEngine.search(query: trimmed, in: store.activeRecords)
        return mergeRecords(answerRecords + keywordRecords)
    }

    private func mergeRecords(_ records: [MemoryRecord]) -> [MemoryRecord] {
        var seen = Set<UUID>()
        return records.filter { seen.insert($0.id).inserted }
    }

    var tomorrowSchedules: [MemoryRecord] {
        MemorySearchEngine.tomorrowSchedules(from: store.activeRecords)
    }

    var todaySchedules: [MemoryRecord] {
        MemorySearchEngine.todaySchedules(from: store.activeRecords)
    }

    var isSearching: Bool {
        !MemoryQueryRouter.normalize(searchText).isEmpty
    }

    var recordGroups: [MemoryRecordGroup] {
        MemoryRecordOrganizer.group(filteredRecords)
    }

    var displayCountText: String {
        let records = filteredRecords
        let groups = recordGroups
        if isSearching {
            return "\(records.count) 条"
        }
        if groups.count < records.count {
            return "\(records.count) 条 · \(groups.count) 组"
        }
        return "\(records.count) 条"
    }
}
