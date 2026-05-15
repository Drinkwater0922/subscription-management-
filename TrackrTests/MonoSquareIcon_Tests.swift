import XCTest
@testable import Trackr

final class MonoSquareIconTests: XCTestCase {

    func test_monogram_singleWord_takesFirstTwoLetters() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "Copilot"), "CO")
    }

    func test_monogram_twoWords_takesInitialOfEach() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "Code Editor"), "CE")
    }

    func test_monogram_threeOrMoreWords_takesFirstTwoInitials() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "AI Chat Pro"), "AC")
    }

    func test_monogram_punctuationAndSymbolsIgnored() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "Code Editor +"), "CE")
    }

    func test_monogram_emptyOrWhitespaceFallsBackToQuestionMark() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: ""), "?")
        XCTAssertEqual(MonoSquareIcon.monogram(for: "   "), "?")
    }

    func test_monogram_singleLetterPadsWithSpace() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "X"), "X")
    }

    func test_monogram_isAlwaysUppercase() {
        XCTAssertEqual(MonoSquareIcon.monogram(for: "lowercase only"), "LO")
    }
}
