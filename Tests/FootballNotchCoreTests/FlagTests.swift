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

    func testNewlyMappedNationFlag() {
        // TUN -> TN -> regional indicators T (U+1F1F9) + N (U+1F1F3)
        let scalars = Flag.emoji(forCountryCode: "TUN").unicodeScalars.map { $0.value }
        XCTAssertEqual(scalars, [0x1F1F9, 0x1F1F3])
    }

    func testAllWorldCup2026NationsHaveFlags() {
        // Every nation in the 2026 World Cup calendar feed (verified against
        // api.fifa.com on 2026-06-21) must resolve to a flag — spec §9 required
        // completing the starter subset for all participating nations.
        let codes = ["ALG", "ARG", "AUS", "AUT", "BEL", "BIH", "BRA", "CAN", "CIV",
                     "COD", "COL", "CPV", "CRO", "CUW", "CZE", "ECU", "EGY", "ENG",
                     "ESP", "FRA", "GER", "GHA", "HAI", "IRN", "IRQ", "JOR", "JPN",
                     "KOR", "KSA", "MAR", "MEX", "NED", "NOR", "NZL", "PAN", "PAR",
                     "POR", "QAT", "RSA", "SCO", "SEN", "SUI", "SWE", "TUN", "TUR",
                     "URU", "USA", "UZB"]
        let missing = codes.filter { Flag.emoji(forCountryCode: $0).isEmpty }
        XCTAssertEqual(missing, [], "Unmapped World Cup nations: \(missing)")
    }
}
