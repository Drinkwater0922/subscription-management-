import Foundation
@testable import Trackr

/// In-memory `StoreKitClient` for tests. Tests configure `currentResult`,
/// `purchaseResults`, and optionally feed values into `updatesContinuation`.
final class FakeStoreKitClient: StoreKitClient {

    var currentResult: ProStatus = .free
    var purchaseResults: [String: Result<ProStatus, Error>] = [:]
    var products: [ProProductDisplay] = []
    private(set) var purchaseCallCount = 0

    // Test handle for pumping live updates into the stream.
    var updatesContinuation: AsyncStream<ProStatus>.Continuation?

    func currentEntitlement() async -> ProStatus {
        currentResult
    }

    func purchase(productID: String) async throws -> ProStatus {
        purchaseCallCount += 1
        guard let result = purchaseResults[productID] else {
            struct Unconfigured: Error {}
            throw Unconfigured()
        }
        switch result {
        case .success(let status):
            currentResult = status
            return status
        case .failure(let error):
            throw error
        }
    }

    func transactionUpdates() -> AsyncStream<ProStatus> {
        AsyncStream { continuation in
            self.updatesContinuation = continuation
        }
    }

    func availableProducts() async -> [ProProductDisplay] {
        products
    }
}
