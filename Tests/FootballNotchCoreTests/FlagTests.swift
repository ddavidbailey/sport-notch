import XCTest
@testable import FootballNotchCore

final class FlagTests: XCTestCase {
    func testIsoNationFlag() {
        // ECU -> EC -> regional indicators E (U+1F1EA) + C (U+1F1E8)
        let scalars = Flag.emoji(forCountryCode: "ECU").unicodeScalars.map { $0.value }
        XCTAssertEqual(scalars, [0x1F1EA, 0x1F1E8])
    }

    func testHomeNationFlagUsesTagSequence() {
        // ENG -> "gbeng" tag sequence: black flag base + g,b,e,n,g + cancel tag
        let eng = Flag.emoji(forCountryCode: "ENG").unicodeScalars.map { $0.value }
        XCTAssertEqual(eng, [0x1F3F4, 0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE0067, 0xE007F])
    }

    func testUnknownCodeReturnsEmpty() {
        XCTAssertEqual(Flag.emoji(forCountryCode: "ZZZ"), "")
    }

    func testLowercaseInputIsNormalized() {
        let scalars = Flag.emoji(forCountryCode: "ger").unicodeScalars.map { $0.value }
        XCTAssertEqual(scalars, [0x1F1E9, 0x1F1EA])
    }
}
