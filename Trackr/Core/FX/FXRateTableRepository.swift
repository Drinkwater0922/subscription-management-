import Foundation
import SwiftData

/// Single-row gateway for the persisted `FXRateTable`. There is at most
/// one row in the store at any time; `replace(...)` enforces that by
/// deleting any existing rows before inserting.
///
/// Conversion is read-time: `convert(amount:from:to:)` cross-rates through
/// the table's base currency. If either currency is missing from the
/// table (rare), it returns `nil` so the caller can skip that subscription
/// rather than report a wrong total.
@MainActor
struct FXRateTableRepository {
    let context: ModelContext

    // MARK: - Read

    /// The currently persisted table, or `nil` if none has been loaded yet
    /// (first launch with no network and no fallback bootstrap).
    func current() throws -> FXRateTable? {
        let descriptor = FetchDescriptor<FXRateTable>(
            sortBy: [SortDescriptor(\FXRateTable.fetchedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - Write

    /// Replace the stored rate table. Deletes any existing rows so the
    /// store stays at single-row.
    @discardableResult
    func replace(baseCurrency: String,
                 rates: [String: Decimal],
                 fetchedAt: Date = .now) throws -> FXRateTable {
        let existing = try context.fetch(FetchDescriptor<FXRateTable>())
        for old in existing { context.delete(old) }

        let json = try JSONEncoder().encode(rates)
        let row = FXRateTable(baseCurrency: baseCurrency.uppercased(),
                              ratesJSON: json,
                              fetchedAt: fetchedAt)
        context.insert(row)
        try context.save()
        return row
    }

    // MARK: - Conversion

    /// Convert `amount` from `source` to `target` using the persisted
    /// table's base as the pivot. Returns `nil` when:
    ///   * no table is persisted yet, or
    ///   * the table is missing a rate for either `source` or `target`
    ///     (and that currency isn't the base itself).
    /// The caller treats `nil` as "skip this row" rather than "zero".
    func convert(amount: Decimal,
                 from source: String,
                 to target: String) throws -> Decimal? {
        let from = source.uppercased()
        let to = target.uppercased()
        if from == to { return amount }

        guard let table = try current() else { return nil }
        return Self.convert(amount: amount, from: from, to: to, using: table)
    }

    /// Pure-function variant — handy for tests + callers that already
    /// have the table in hand and want to avoid a per-row fetch.
    static func convert(amount: Decimal,
                        from source: String,
                        to target: String,
                        using table: FXRateTable) -> Decimal? {
        let from = source.uppercased()
        let to = target.uppercased()
        if from == to { return amount }

        let base = table.baseCurrency.uppercased()
        let rates = table.decodedRates

        // Rate of `code` against the table's base. The base itself is `1`.
        func rate(of code: String) -> Decimal? {
            if code == base { return 1 }
            return rates[code]
        }

        guard let rFrom = rate(of: from), let rTo = rate(of: to),
              rFrom != 0 else { return nil }
        // amount in base = amount / rFrom
        // amount in target = (amount / rFrom) * rTo
        return amount * rTo / rFrom
    }
}
