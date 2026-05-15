import XCTest
@testable import Trackr

final class LocaleResolverTests: XCTestCase {

    private let systemEN = Locale(identifier: "en_US")
    private let systemZH = Locale(identifier: "zh-Hans_CN")

    func test_auto_defersToSystem() {
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "auto", systemLocale: systemEN),
            systemEN
        )
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "auto", systemLocale: systemZH),
            systemZH
        )
    }

    func test_en_alwaysReturnsEnglish() {
        let resolved = LocaleResolver.resolve(languagePreference: "en", systemLocale: systemZH)
        XCTAssertEqual(resolved.language.languageCode?.identifier, "en")
    }

    func test_zhHans_alwaysReturnsSimplifiedChinese() {
        let resolved = LocaleResolver.resolve(languagePreference: "zh-Hans", systemLocale: systemEN)
        XCTAssertEqual(resolved.language.languageCode?.identifier, "zh")
        XCTAssertEqual(resolved.language.script?.identifier, "Hans")
    }

    func test_unknownPreference_defersToSystem() {
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "fr", systemLocale: systemEN),
            systemEN
        )
    }
}
