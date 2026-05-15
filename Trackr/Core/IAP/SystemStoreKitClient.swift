import Foundation
import StoreKit

/// Production `StoreKitClient` implementation. Thin wrapper over StoreKit 2 —
/// no business logic; tests cover the consumers (`ProEntitlement`, the paywall).
final class SystemStoreKitClient: StoreKitClient {

    func currentEntitlement() async -> ProStatus {
        var resolved: ProStatus = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            switch txn.productID {
            case ProProductID.lifetime:
                return .proLifetime // strictly the highest tier — short-circuit
            case ProProductID.monthly:
                resolved = .proMonthly
            default:
                continue
            }
        }
        return resolved
    }

    func purchase(productID: String) async throws -> ProStatus {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let txn) = verification {
                await txn.finish()
            }
            return await currentEntitlement()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func transactionUpdates() -> AsyncStream<ProStatus> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard case .verified(let txn) = result else { continue }
                    await txn.finish()
                    let resolved = await self.currentEntitlement()
                    continuation.yield(resolved)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func availableProducts() async -> [ProProductDisplay] {
        let ids = [ProProductID.monthly, ProProductID.lifetime]
        guard let products = try? await Product.products(for: ids) else { return [] }
        return products.map { product in
            ProProductDisplay(productID: product.id,
                              priceDisplay: product.displayPrice)
        }
    }

    enum PurchaseError: Error, Equatable {
        case productNotFound
        case userCancelled
        case pending
        case unknown
    }
}
