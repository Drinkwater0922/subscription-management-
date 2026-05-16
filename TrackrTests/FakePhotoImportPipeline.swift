import Foundation
@testable import Trackr

/// Canned `PhotoImportPipeline` for tests. Either return preset lines or throw
/// the configured error.
final class FakePhotoImportPipeline: PhotoImportPipeline {

    var stubbedLines: [String] = []
    var stubbedError: Error?
    private(set) var receivedDataCount = 0

    func recognizeText(in imageData: Data) async throws -> [String] {
        receivedDataCount += 1
        if let err = stubbedError { throw err }
        return stubbedLines
    }
}
