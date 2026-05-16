import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Protocol seam between "raw photo data" and "recognized text lines". The real
/// implementation hits the Vision framework; tests inject `FakePhotoImportPipeline`
/// to skip the heavy machinery.
protocol PhotoImportPipeline {
    /// Recognize text in the supplied image. Returns one entry per visually
    /// distinct line in the source. May throw if the OS-level OCR call fails.
    func recognizeText(in imageData: Data) async throws -> [String]
}

enum PhotoImportError: Error, Equatable {
    case decodeFailed
    case visionFailed(String)
}
