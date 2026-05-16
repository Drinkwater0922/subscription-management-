import Foundation
#if canImport(Vision) && canImport(UIKit)
import Vision
import UIKit

/// Real `PhotoImportPipeline` backed by Apple's Vision framework. Lives only in
/// the iOS app target (Vision is unavailable in some test environments, but
/// since this file builds in app + test bundle, the `#if canImport` guards
/// keep it safe).
struct VisionOCRClient: PhotoImportPipeline {

    /// Recognition languages. Defaults cover the two locales the app ships.
    var recognitionLanguages: [String] = ["en-US", "zh-Hans"]
    var usesLanguageCorrection: Bool = true

    func recognizeText(in imageData: Data) async throws -> [String] {
        guard let cgImage = Self.decodeCGImage(from: imageData) else {
            throw PhotoImportError.decodeFailed
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: PhotoImportError.visionFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = usesLanguageCorrection

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: PhotoImportError.visionFailed(error.localizedDescription))
            }
        }
    }

    private static func decodeCGImage(from data: Data) -> CGImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.cgImage
    }
}
#endif
