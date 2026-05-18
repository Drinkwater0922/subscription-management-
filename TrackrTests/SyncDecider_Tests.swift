import XCTest
@testable import Trackr

final class SyncDeciderTests: XCTestCase {

    func test_pro_andAvailable_returnsCloudKit() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .available),
            .cloudKit
        )
    }

    func test_free_evenWithICloud_isLocalOnly() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .free, iCloud: .available),
            .localOnly
        )
    }

    func test_pro_butNoICloud_isLocalOnly() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .noAccount),
            .localOnly
        )
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .restricted),
            .localOnly
        )
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .couldNotDetermine),
            .localOnly
        )
    }
}
