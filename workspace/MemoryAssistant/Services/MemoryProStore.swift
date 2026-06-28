import Foundation
import StoreKit

/// Pro 订阅：Debug 可模拟购买；Release 仅走 App Store 内购校验。
@MainActor
final class MemoryProStore: ObservableObject {
    enum ProductID {
        static let monthly = "com.example.MemoryAssistant.pro.monthly"
        static let yearly = "com.example.MemoryAssistant.pro.yearly"
        static let all = [monthly, yearly]
    }

    @Published private(set) var isPro: Bool
    @Published private(set) var isPurchasing = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published var lastError: String?

    private let proKey = "memory.assistant.pro.unlocked"
    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: proKey)
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var monthlyPriceText: String {
        guard let price = monthlyProduct?.displayPrice as String? else {
            return "¥12 / 月"
        }
        return "\(price) / 月"
    }

    var yearlyPriceText: String {
        guard let price = yearlyProduct?.displayPrice as String? else {
            return "¥98 / 年"
        }
        return "\(price) / 年"
    }

    var usesMockPurchaseInDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    func purchaseMonthly() async {
        await purchase(plan: .monthly)
    }

    func purchaseYearly() async {
        await purchase(plan: .yearly)
    }

    func restorePurchases() async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                lastError = "未找到可恢复的购买记录。"
            }
        } catch {
            lastError = "恢复购买失败，请稍后重试。"
        }
    }

    // MARK: - Private

    private enum Plan { case monthly, yearly }

    private func purchase(plan: Plan) async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        let product: Product? = plan == .monthly ? monthlyProduct : yearlyProduct

        #if DEBUG
        if product == nil, usesMockPurchaseInDebug {
            try? await Task.sleep(nanoseconds: 600_000_000)
            setProUnlocked(true)
            return
        }
        #endif

        guard let product else {
            lastError = "商品尚未加载，请检查网络后重试。"
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handle(transaction: transaction)
            case .userCancelled:
                break
            case .pending:
                lastError = "购买待处理，请稍后在订阅中查看。"
            @unknown default:
                break
            }
        } catch {
            lastError = "购买失败，请稍后重试。"
        }
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: ProductID.all)
            monthlyProduct = products.first { $0.id == ProductID.monthly }
            yearlyProduct = products.first { $0.id == ProductID.yearly }
        } catch {
            // 商品未在 App Store Connect 配置时，Debug 仍可用模拟购买。
        }
    }

    private func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if ProductID.all.contains(transaction.productID) {
                entitled = true
            }
        }

        setProUnlocked(entitled)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? await self.checkVerified(result) {
                    await self.handle(transaction: transaction)
                }
            }
        }
    }

    private func handle(transaction: Transaction) async {
        if ProductID.all.contains(transaction.productID) {
            setProUnlocked(true)
        }
        await transaction.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw ProStoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func setProUnlocked(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: proKey)
    }
}

private enum ProStoreError: Error {
    case failedVerification
}
