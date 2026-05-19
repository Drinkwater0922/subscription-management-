import XCTest
@testable import Trackr

final class BrandConfigTests: XCTestCase {

    func test_appDisplayName_isNonEmpty() {
        XCTAssertFalse(BrandConfig.appDisplayName.isEmpty)
    }

    func test_bundleIdentifier_followsReverseDNSShape() {
        let id = BrandConfig.bundleIdentifier
        XCTAssertTrue(id.contains("."), "expected reverse-DNS bundle id, got \(id)")
        XCTAssertGreaterThanOrEqual(id.split(separator: ".").count, 2)
    }

    func test_appGroupIdentifier_startsWithGroupDot() {
        XCTAssertTrue(BrandConfig.appGroupIdentifier.hasPrefix("group."),
                      "app group id must start with 'group.': \(BrandConfig.appGroupIdentifier)")
    }

    func test_cloudKitContainerIdentifier_startsWithICloudDot() {
        XCTAssertTrue(BrandConfig.cloudKitContainerIdentifier.hasPrefix("iCloud."),
                      "CloudKit container id must start with 'iCloud.': \(BrandConfig.cloudKitContainerIdentifier)")
    }

    func test_privacyPolicyURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.privacyPolicyURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.privacyPolicyURL.host)
    }

    func test_termsOfServiceURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.termsOfServiceURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.termsOfServiceURL.host)
    }

    func test_manageSubscriptionURL_pointsAtAppleAccountSettings() {
        XCTAssertEqual(BrandConfig.manageSubscriptionURL.host, "apps.apple.com")
        XCTAssertTrue(BrandConfig.manageSubscriptionURL.path.contains("subscriptions"))
    }

    func test_presetCatalogURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.presetCatalogURL.scheme, "https")
    }

    // MARK: - Feedback / support (v1.0.1)

    func test_supportURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.supportURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.supportURL.host)
    }

    func test_supportIssueURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.supportIssueURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.supportIssueURL.host)
    }

    /// Refuses to ship a `TODO_`-prefixed placeholder. If this test starts
    /// failing in CI it means somebody bumped the version without filling in
    /// the real maintainer mailbox.
    func test_supportEmail_isConfigured() {
        let email = BrandConfig.supportEmail
        XCTAssertFalse(email.isEmpty, "supportEmail must not be empty")
        XCTAssertFalse(email.hasPrefix("TODO_"),
                       "supportEmail must not ship with a TODO_ placeholder: \(email)")
        XCTAssertTrue(email.contains("@"),
                      "supportEmail must look like an email address: \(email)")
    }
}
