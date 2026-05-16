import XCTest
@testable import Trackr

final class PresetCatalogTests: XCTestCase {

    private let json = #"""
    {
      "version": "1.0.0",
      "items": [
        {
          "id": "netflix.standard",
          "name": "Netflix",
          "defaultPlanName": "Standard",
          "defaultAmount": "15.49",
          "defaultCurrency": "USD",
          "defaultCycle": "monthly",
          "category": "streaming",
          "iconRef": "preset:netflix.standard"
        }
      ]
    }
    """#

    func test_decode_versionAndItems() throws {
        let catalog = try JSONDecoder().decode(PresetCatalog.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(catalog.version, "1.0.0")
        XCTAssertEqual(catalog.items.count, 1)
        XCTAssertEqual(catalog.items.first?.id, "netflix.standard")
    }

    func test_lookupById_returnsItem() throws {
        let catalog = try JSONDecoder().decode(PresetCatalog.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(catalog.item(withID: "netflix.standard")?.name, "Netflix")
        XCTAssertNil(catalog.item(withID: "nope"))
    }
}
