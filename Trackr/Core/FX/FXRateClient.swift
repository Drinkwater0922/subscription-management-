import Foundation

/// Protocol seam for foreign-exchange rate lookups. The real implementation
/// hits the free Frankfurter API; tests inject a `FakeFXClient`.
///
/// We pin the rate at subscription-creation time so that future aggregation
/// is deterministic and offline-safe — once the user has saved a sub, we
/// never refetch its rate. Re-running aggregation gives the same answer
/// even if the network is down or the rate has moved.
protocol FXRateClient {
    /// Rate that converts 1 unit of `base` into `quote` on the supplied
    /// historical date. `date` is rounded to the calendar day (FX APIs are
    /// daily-resolution).
    func rate(from base: String, to quote: String, on date: Date) async throws -> Decimal
}

enum FXError: Error, Equatable {
    case sameCurrency
    case invalidResponse
    case missingRate(quote: String)
    case network(String)
}
