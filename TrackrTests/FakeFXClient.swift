import Foundation
@testable import Trackr

/// Canned `FXRateClient`. Inject via SwiftUI environment or pass directly to
/// pure-logic helpers. Records every call so tests can verify "we asked for
/// USD → CNY on this date".
final class FakeFXClient: FXRateClient {

    struct Call: Equatable {
        let base: String
        let quote: String
        let date: Date
    }

    /// Rates keyed by "BASE→QUOTE". Lookups are case-insensitive.
    var stubbedRates: [String: Decimal] = [:]
    var stubbedError: Error?
    private(set) var calls: [Call] = []

    func rate(from base: String, to quote: String, on date: Date) async throws -> Decimal {
        calls.append(Call(base: base.uppercased(), quote: quote.uppercased(), date: date))
        if let err = stubbedError { throw err }
        let key = "\(base.uppercased())→\(quote.uppercased())"
        guard let rate = stubbedRates[key] else {
            throw FXError.missingRate(quote: quote.uppercased())
        }
        return rate
    }
}
