import Foundation

/// Real `FXRateClient` backed by https://frankfurter.app — a free, no-key,
/// historical FX API maintained by the European Central Bank.
///
/// Endpoint shape (GET):
///   https://api.frankfurter.app/2026-01-15?from=USD&to=CNY
/// Response shape:
///   `{"amount":1.0,"base":"USD","date":"2026-01-15","rates":{"CNY":7.1234}}`
struct FrankfurterFXClient: FXRateClient {

    var session: URLSession = .shared
    var baseURL: URL = URL(string: "https://api.frankfurter.app")!

    func rate(from base: String, to quote: String, on date: Date) async throws -> Decimal {
        let baseCode = base.uppercased()
        let quoteCode = quote.uppercased()
        guard baseCode != quoteCode else { throw FXError.sameCurrency }

        let datePath = Self.isoDateString(from: date)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.path = "/\(datePath)"
        components.queryItems = [
            URLQueryItem(name: "from", value: baseCode),
            URLQueryItem(name: "to", value: quoteCode),
        ]
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
        guard let rate = decoded.rates[quoteCode] else {
            throw FXError.missingRate(quote: quoteCode)
        }
        return rate
    }

    private struct FrankfurterResponse: Decodable {
        let rates: [String: Decimal]
    }

    private static func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
