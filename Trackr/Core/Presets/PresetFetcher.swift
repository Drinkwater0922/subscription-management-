import Foundation

/// Narrow seam for fetching `PresetCatalog` from a remote source. Tests inject
/// `FakePresetFetcher`; production wires `URLSessionPresetFetcher`.
protocol PresetFetcher: AnyObject {
    func fetch() async throws -> PresetCatalog
}

/// Hits an HTTPS URL via `URLSession.shared`. The URL is injected at construction
/// time so tests / config flips can point at staging.
final class URLSessionPresetFetcher: PresetFetcher {

    let catalogURL: URL
    private let session: URLSession

    init(catalogURL: URL, session: URLSession = .shared) {
        self.catalogURL = catalogURL
        self.session = session
    }

    enum FetchError: Error {
        case badResponse(Int)
    }

    func fetch() async throws -> PresetCatalog {
        let (data, response) = try await session.data(from: catalogURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(PresetCatalog.self, from: data)
    }
}
