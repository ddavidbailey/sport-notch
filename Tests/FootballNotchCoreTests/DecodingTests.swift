import XCTest
@testable import FootballNotchCore

final class DecodingTests: XCTestCase {
    func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testDecodeFiltersToWorldCup() throws {
        let data = try loadFixture("live_now")
        let matches = try decodeLiveMatches(from: data)

        XCTAssertEqual(matches.count, 1) // only IdCompetition == "17"
        let m = try XCTUnwrap(matches.first)
        XCTAssertEqual(m.id, "400021465")
        XCTAssertEqual(m.home.name, "Ecuador")
        XCTAssertEqual(m.away.name, "Curaçao")
        XCTAssertEqual(m.home.abbreviation, "ECU")
        XCTAssertEqual(m.homeScore, 0)
        XCTAssertEqual(m.awayScore, 0)
        XCTAssertEqual(m.clock, "2'")
        XCTAssertEqual(m.status, .live)
    }

    func testDecodeCalendarHomeAwayKeys() throws {
        // The calendar endpoint names teams `Home`/`Away` (vs the live feed's
        // `HomeTeam`/`AwayTeam`). Both shapes must decode.
        let json = """
        {
          "Results": [
            {
              "IdMatch": "400021500",
              "IdCompetition": "17",
              "MatchStatus": 0,
              "Date": "2026-06-22T01:00:00Z",
              "Home": { "Score": 0, "IdCountry": "NZL", "Abbreviation": "NZL", "TeamName": [{ "Description": "New Zealand" }] },
              "Away": { "Score": 0, "IdCountry": "EGY", "Abbreviation": "EGY", "TeamName": [{ "Description": "Egypt" }] }
            }
          ]
        }
        """
        let matches = try decodeLiveMatches(from: Data(json.utf8))
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.home.abbreviation, "NZL")
        XCTAssertEqual(matches.first?.away.name, "Egypt")
        XCTAssertEqual(matches.first?.status, .scheduled)
    }

    func testDecodeDropsUndecodableMatchButKeepsOthers() throws {
        // Spec §7: a single malformed element must be dropped, not abort the batch.
        let json = """
        {
          "Results": [
            { "IdCompetition": "17", "MatchStatus": 3 },
            {
              "IdMatch": "400021465",
              "IdCompetition": "17",
              "MatchStatus": 3,
              "MatchTime": "2'",
              "HomeTeam": { "Score": 1, "IdCountry": "ECU", "Abbreviation": "ECU", "TeamName": [{ "Description": "Ecuador" }] },
              "AwayTeam": { "Score": 0, "IdCountry": "CUW", "Abbreviation": "CUW", "TeamName": [{ "Description": "Curacao" }] }
            }
          ]
        }
        """
        let matches = try decodeLiveMatches(from: Data(json.utf8))
        XCTAssertEqual(matches.count, 1)            // malformed element dropped, valid one kept
        XCTAssertEqual(matches.first?.id, "400021465")
        XCTAssertEqual(matches.first?.homeScore, 1)
    }
}
