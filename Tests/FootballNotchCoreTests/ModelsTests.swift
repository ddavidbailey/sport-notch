import XCTest
@testable import FootballNotchCore

final class ModelsTests: XCTestCase {
    func testTeamFlagDerivedFromCountryCode() {
        let team = Team(name: "Ecuador", abbreviation: "ECU", countryCode: "ECU")
        XCTAssertEqual(team.flag.unicodeScalars.map { $0.value }, [0x1F1EA, 0x1F1E8])
    }

    func testMatchIsLive() {
        let team = Team(name: "A", abbreviation: "AAA", countryCode: "ZZZ")
        let live = Match(id: "1", competitionId: "17", home: team, away: team,
                         homeScore: 0, awayScore: 0, status: .live, clock: "2'",
                         kickoff: Date(timeIntervalSince1970: 0))
        let halftime = Match(id: "2", competitionId: "17", home: team, away: team,
                             homeScore: 0, awayScore: 0, status: .halftime, clock: "HT",
                             kickoff: Date(timeIntervalSince1970: 0))
        let sched = Match(id: "3", competitionId: "17", home: team, away: team,
                          homeScore: 0, awayScore: 0, status: .scheduled, clock: "",
                          kickoff: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(live.isLive)
        XCTAssertTrue(halftime.isLive)
        XCTAssertFalse(sched.isLive)
    }
}
