import SwiftUI

/// 在 SwiftUI 主线程上统一创建依赖，避免 App.init 里触发 MainActor 隔离问题。
@MainActor
final class AppDependencies: ObservableObject {
    let store: MemoryStore
    let viewModel: MemoryListViewModel
    let proStore: MemoryProStore

    init() {
        let store = MemoryStore()
        self.store = store
        self.viewModel = MemoryListViewModel(store: store)
        self.proStore = MemoryProStore()
    }
}

@main
struct MemoryAssistantApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MemoryListView(
                viewModel: dependencies.viewModel,
                proStore: dependencies.proStore
            )
            .background(Color(.systemGroupedBackground))
        }
    }
}
