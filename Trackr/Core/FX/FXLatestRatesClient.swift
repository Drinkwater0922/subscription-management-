import Foundation

/// Fetches a whole-table snapshot of FX rates against a base currency in a
/// single network call. Distinct from the legacy `FXRateClient`, which is
/// single-rate / single-date and was built for the old "pin at creation"
/// flow (now demoted in v1.1).
///
/// Used by the Phase 2 foreground-refresh path: at app foreground / Home
/// appear, if the cached `FXRateTable` is older than ~24h and the network
/// is up, fetch a fresh snapshot and overwrite the cache. Never blocks UI.
protocol FXLatestRatesClient {
    /// Returns "1 unit of base = N units of quote" for every quote
    /// currency the provider knows about. The base itself is implicit
    /// (value `1`) and is not included in the returned dictionary.
    func latestRates(base: String) async throws -> [String: Decimal]
}

/// Frankfurter implementation. `https://api.frankfurter.app/latest?from=USD`
/// returns `{"amount":1.0,"base":"USD","date":"...","rates":{...}}`.
struct FrankfurterLatestRatesClient: FXLatestRatesClient {

    var session: URLSession = .shared
    var baseURL: URL = URL(string: "https://api.frankfurter.app")!

    func latestRates(base: String) async throws -> [String: Decimal] {
        let baseCode = base.uppercased()
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.path = "/latest"
        components.queryItems = [URLQueryItem(name: "from", value: baseCode)]
        guard let url = components.url else { throw FXError.invalidResponse }

        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw FXError.network(error.localizedDescription)
        }

        guard let decoded = try? JSONDecoder().decode(FrankfurterResponse.self, from: data) else {
            throw FXError.invalidResponse
        }
        return decoded.rates
    }

    private struct FrankfurterResponse: Decodable {
        let rates: [String: Decimal]
    }
}
