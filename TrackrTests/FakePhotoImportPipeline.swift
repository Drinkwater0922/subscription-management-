import Foundation
import CoreGraphics
@testable import Trackr

/// Canned `PhotoImportPipeline` for tests.
final class FakePhotoImportPipeline: PhotoImportPipeline {

    var stubbedLines: [RecognizedTextLine] = []
    var stubbedError: Error?
    private(set) var receivedDataCount = 0

    func recognizeText(in imageData: Data) async throws -> [RecognizedTextLine] {
        receivedDataCount += 1
        if let err = stubbedError { throw err }
        return stubbedLines
    }

    /// Convenience for callers that want to stub from plain strings —
    /// synthesises fake bounding boxes stacked top-to-bottom.
    func stubFromStrings(_ texts: [String]) {
        let step: CGFloat = 1.0 / CGFloat(max(texts.count, 1))
        stubbedLines = texts.enumerated().map { idx, text in
            RecognizedTextLine(
                text: text,
                bounds: CGRect(x: 0, y: CGFloat(idx) * step,
                               width: 1, height: step)
            )
        }
    }
}
