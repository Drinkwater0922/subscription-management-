import Foundation
import SwiftData

/// Thrown by repository methods when a free-tier user attempts to exceed the
/// 5-subscription limit. Enforcement of the gate lives in M6 — this error type
/// exists now so the feature/paywall layers can route to it when it lands.
struct SubscriptionLimitExceeded: Error {}

/// The single gateway between features and SwiftData for `Subscription` rows.
@MainActor
struct SubscriptionRepository {
    let context: ModelContext

    func insert(_ sub: Subscription) throws {
        context.insert(sub)
        try context.save()
    }

    func delete(_ sub: Subscription) throws {
        context.delete(sub)
        try context.save()
    }

    func fetchAll() throws -> [Subscription] {
        let descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.nextBillingDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(byID id: UUID) throws -> Subscription? {
        // `#Predicate { $0.id == id }` crashes at runtime because the model's stored
        // `id: UUID` shadows `PersistentModel.id`, confusing the predicate macro on
        // current SwiftData. Filter in Swift until we revisit the schema.
        let all = try context.fetch(FetchDescriptor<Subscription>())
        return all.first { $0.id == id }
    }

    func count() throws -> Int {
        try context.fetch(FetchDescriptor<Subscription>()).count
    }
}
