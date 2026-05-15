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
}
