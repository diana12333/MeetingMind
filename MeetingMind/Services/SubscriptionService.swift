import StoreKit
import Foundation

@Observable
final class SubscriptionService: @unchecked Sendable {
    static let productId = "com.meetingmind.app.subscription.monthly"

    @MainActor var isSubscribed = false
    @MainActor var expiryDate: Date?
    @MainActor var product: Product?
    @MainActor var isPurchasing = false
    @MainActor var errorMessage: String?

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {}

    deinit {
        transactionListener?.cancel()
    }

    func startObservingTransactions() {
        guard transactionListener == nil else { return }
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.checkSubscriptionStatus()
                }
            }
        }
    }

    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.productId])
            product = products.first
        } catch {
            errorMessage = "Failed to load subscription: \(error.localizedDescription)"
        }
    }

    @MainActor
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = "Subscription product not available."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()
                return true

            case .userCancelled:
                return false

            case .pending:
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }

    @MainActor
    func checkSubscriptionStatus() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.productId {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        isSubscribed = true
                        expiryDate = expirationDate
                        foundActive = true
                    }
                }
            }
        }

        if !foundActive {
            isSubscribed = false
            expiryDate = nil
        }
    }

    func getOriginalTransactionId() async -> String? {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.productId {
                    return String(transaction.originalID)
                }
            }
        }
        return nil
    }

    nonisolated func getReceiptData() -> String? {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }
        return receiptData.base64EncodedString()
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
