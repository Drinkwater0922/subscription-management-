import Foundation
import SwiftData

/// The single gateway between features and SwiftData for `PriceChangeAlert` rows.
@MainActor
struct AlertRepository {
    let context: ModelContext

    func insert(_ alert: PriceChangeAlert) throws {
        context.insert(alert)
        try context.save()
    }

    func markSeen(_ alert: PriceChangeAlert, at date: Date = .now) throws {
        alert.seenAt = date
        try context.save()
    }

    func fetchAll() throws -> [PriceChangeAlert] {
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchUnseen() throws -> [PriceChangeAlert] {
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            predicate: #Predicate { $0.seenAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(forPresetId presetId: String) throws -> [PriceChangeAlert] {
        let target = presetId
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            predicate: #Predicate { $0.presetId == target },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
