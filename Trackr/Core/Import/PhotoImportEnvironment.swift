import SwiftUI

/// SwiftUI environment key for the OCR-backed import pipeline. Production code
/// installs a real `VisionOCRClient`; tests swap in `FakePhotoImportPipeline`.
private struct PhotoImportPipelineKey: EnvironmentKey {
    static let defaultValue: PhotoImportPipeline? = nil
}

extension EnvironmentValues {
    var photoImportPipeline: PhotoImportPipeline? {
        get { self[PhotoImportPipelineKey.self] }
        set { self[PhotoImportPipelineKey.self] = newValue }
    }
}

/// Used when the environment value is `nil` — currently the same as
/// `VisionOCRClient` on iOS. Keeps `AddSubscriptionSheet` from having to
/// import Vision directly.
struct FallbackPhotoImport: PhotoImportPipeline {
    func recognizeText(in imageData: Data) async throws -> [RecognizedTextLine] {
        #if canImport(Vision) && canImport(UIKit)
        return try await VisionOCRClient().recognizeText(in: imageData)
        #else
        throw PhotoImportError.visionFailed("Vision unavailable on this platform")
        #endif
    }
}
