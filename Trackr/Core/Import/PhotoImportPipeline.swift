import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// One line of recognised text plus its position on the source image.
/// `bounds` is normalised to 0...1 in image space, **top-left origin**
/// (we invert Vision's bottom-left origin at the source so callers don't
/// have to think about it).
struct RecognizedTextLine: Equatable {
    let text: String
    let bounds: CGRect
}

/// Protocol seam between "raw photo data" and "recognised text lines with
/// positions". The real implementation hits the Vision framework; tests
/// inject `FakePhotoImportPipeline` to skip the heavy machinery.
protocol PhotoImportPipeline {
    func recognizeText(in imageData: Data) async throws -> [RecognizedTextLine]
}

enum PhotoImportError: Error, Equatable {
    case decodeFailed
    case visionFailed(String)
}
