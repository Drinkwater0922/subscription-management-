import Foundation

/// Reads `presets.bundled.json` out of the main bundle and decodes it into a
/// `PresetCatalog`. Crashes the app at launch if the file is missing or invalid
/// — that's a programmer error caught long before App Store review.
enum PresetBundleLoader {

    enum LoaderError: Error {
        case missingFile
    }

    static func loadBundled(bundle: Bundle = .main) throws -> PresetCatalog {
        guard let url = bundle.url(forResource: "presets.bundled",
                                   withExtension: "json") else {
            throw LoaderError.missingFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PresetCatalog.self, from: data)
    }
}
