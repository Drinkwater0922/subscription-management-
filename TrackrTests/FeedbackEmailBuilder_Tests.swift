import XCTest
@testable import Trackr

final class FeedbackEmailBuilderTests: XCTestCase {

    // Stable, hand-picked inputs so the assertions below pin down exactly
    // what ships in a real mailto: URL.
    private let sample = FeedbackEmailBuilder(
        appVersion: "1.0.1",
        buildNumber: "14",
        iOSVersion: "18.1",
        language: "zh-Hans",
        proStatus: .proLifetime
    )

    // MARK: - Subject + body shape

    func test_subject_includesVersionAndBuild() {
        XCTAssertEqual(sample.subject, "PennyLoop Feedback - 1.0.1 (14)")
    }

    func test_body_includesAllowedDiagnosticFields() {
        let body = sample.body
        XCTAssertTrue(body.contains("Version: 1.0.1"), body)
        XCTAssertTrue(body.contains("Build: 14"), body)
        XCTAssertTrue(body.contains("iOS: 18.1"), body)
        XCTAssertTrue(body.contains("Language: zh-Hans"), body)
        XCTAssertTrue(body.contains("Pro Status: proLifetime"), body)
    }

    /// The PRD forbids these fields from ever leaking into outbound feedback.
    /// Brute-force assert that none of them appears in the rendered body for
    /// realistic-looking sample inputs.
    func test_body_omitsForbiddenFields() {
        let body = sample.body.lowercased()
        let forbidden = [
            "netflix", "spotify", "icloud",         // subscription names
            "$", "¥", "usd", "cny",                  // amounts / currencies
            "2026", "renewal date", "billing date",  // renewal dates
            "category", "notes",                     // free-text fields
            "ocr",                                   // OCR extracts
            "device", "iphone", "ipad", "model",     // device model
            "storefront",                            // App Store region
            "timezone", "tz=",                       // timezone
        ]
        for needle in forbidden {
            XCTAssertFalse(body.contains(needle),
                           "feedback body must not contain '\(needle)': \(body)")
        }
    }

    // MARK: - URL assembly

    func test_mailtoURL_hasMailtoSchemeAndAddress() {
        let url = sample.mailtoURL(to: "test@example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "mailto")
        XCTAssertTrue(url?.absoluteString.contains("test@example.com") ?? false,
                      "expected recipient in URL: \(url?.absoluteString ?? "nil")")
    }

    func test_mailtoURL_percentEncodesSubjectAndBody() {
        let url = sample.mailtoURL(to: "test@example.com")
        let absolute = url?.absoluteString ?? ""
        // Spaces and newlines must be percent-encoded, not raw.
        XCTAssertFalse(absolute.contains(" "),
                       "URL must percent-encode spaces: \(absolute)")
        XCTAssertFalse(absolute.contains("\n"),
                       "URL must percent-encode newlines: \(absolute)")
        // `subject=` and `body=` query keys round-trip.
        XCTAssertTrue(absolute.contains("subject="), absolute)
        XCTAssertTrue(absolute.contains("body="), absolute)
    }

    func test_mailtoURL_decodedQueryRoundTripsBodyExactly() {
        let url = sample.mailtoURL(to: "test@example.com")
        let components = URLComponents(string: url?.absoluteString ?? "")
        let body = components?.queryItems?.first(where: { $0.name == "body" })?.value
        XCTAssertEqual(body, sample.body)
    }

    // MARK: - Sensitivity to inputs

    func test_freeUser_rendersFreeProStatus() {
        var builder = sample
        builder = FeedbackEmailBuilder(
            appVersion: builder.appVersion,
            buildNumber: builder.buildNumber,
            iOSVersion: builder.iOSVersion,
            language: builder.language,
            proStatus: .free
        )
        XCTAssertTrue(builder.body.contains("Pro Status: free"), builder.body)
    }
}
