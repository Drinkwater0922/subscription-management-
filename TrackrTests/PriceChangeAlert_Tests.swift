import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PriceChangeAlertTests: XCTestCase {

    func test_canBeInsertedWithBothLocalizations() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let alert = PriceChangeAlert(
            presetId: "vendor.product",
            planKey: "pro",
            oldAmount: 18,
            newAmount: 20,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "Pro tier up $2/mo",
            messageZh: "Pro 档涨 $2/月"
        )
        context.insert(alert)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PriceChangeAlert>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.messageEn, "Pro tier up $2/mo")
        XCTAssertEqual(fetched.first?.messageZh, "Pro 档涨 $2/月")
        XCTAssertNil(fetched.first?.seenAt)
    }

    func test_seenAtCanBeMarked() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let alert = PriceChangeAlert(
            presetId: "vendor.product", planKey: "pro",
            oldAmount: 18, newAmount: 20,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "", messageZh: ""
        )
        context.insert(alert)
        let when = Date(timeIntervalSince1970: 1_750_000_000)
        alert.seenAt = when
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PriceChangeAlert>())
        XCTAssertEqual(fetched.first?.seenAt, when)
    }
}
