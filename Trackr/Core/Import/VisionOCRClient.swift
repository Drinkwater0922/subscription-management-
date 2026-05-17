import Foundation
import CoreGraphics
#if canImport(Vision) && canImport(UIKit)
import Vision
import UIKit

/// Real `PhotoImportPipeline` backed by Apple's Vision framework. Lives only
/// in the iOS app target (Vision is unavailable in some test environments,
/// but since this file builds in app + test bundle, the `#if canImport`
/// guards keep it safe).
struct VisionOCRClient: PhotoImportPipeline {

    var recognitionLanguages: [String] = ["zh-Hans", "en-US"]
    var usesLanguageCorrection: Bool = true

    func recognizeText(in imageData: Data) async throws -> [RecognizedTextLine] {
        guard let cgImage = Self.decodeCGImage(from: imageData) else {
            throw PhotoImportError.decodeFailed
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[RecognizedTextLine], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: PhotoImportError.visionFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [RecognizedTextLine] = observations.compactMap { obs in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    // Vision uses a bottom-left origin in normalised image
                    // coordinates. Flip Y so callers see a top-left origin
                    // (matches every other Apple framework + makes "row
                    // above" math intuitive).
                    let b = obs.boundingBox
                    let bounds = CGRect(
                        x: b.minX,
                        y: 1.0 - b.maxY,
                        width: b.width,
                        height: b.height
                    )
                    return RecognizedTextLine(text: text, bounds: bounds)
                }
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
