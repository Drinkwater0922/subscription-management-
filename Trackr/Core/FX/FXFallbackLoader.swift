import Foundation

/// Loads the bundled fallback FX rate table from `fx-fallback.json` in the
/// app bundle. Used when no `FXRateTable` is persisted yet (first launch,
/// no network) so that a brand-new install can still convert currencies
/// for the v1.1 Home hero. The v1.1 spec describes the hero as an
/// emotional estimate — rough rates suffice.
enum FXFallbackLoader {

    /// Decoded shape of `fx-fallback.json`.
    struct Bundle: Decodable, Equatable {
        let baseCurrency: String
        let fetchedAt: Date
        let rates: [String: Decimal]
    }

    enum LoadError: Error, Equatable {
        case missingResource
        case malformed
    }

    /// Loads the bundle from the supplied resource bundle (defaults to
    /// the main app bundle). The decoder uses ISO-8601 for `fetchedAt`
    /// so the bundled file stays human-readable.
    static func load(from bundle: Foundation.Bundle = .main) throws -> Bundle {
        guard let url = bundle.url(forResource: "fx-fallback",
                                   withExtension: "json") else {
            throw LoadError.missingResource
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Bundle.self, from: data)
        } catch {
            throw LoadError.malformed
        }
    }
}
