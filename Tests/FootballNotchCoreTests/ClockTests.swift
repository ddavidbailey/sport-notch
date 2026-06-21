import XCTest
@testable import FootballNotchCore

final class ClockTests: XCTestCase {
    func testIncrementClockBumpsMinute() {
        XCTAssertEqual(incrementClock("2'"), "3'")
        XCTAssertEqual(incrementClock("67'"), "68'")
    }

    func testIncrementClockLeavesStoppageUnchanged() {
        XCTAssertEqual(incrementClock("45+1'"), "45+1'")
        XCTAssertEqual(incrementClock("HT"), "HT")
    }

    func testCountdownFormatsHoursMinutesSeconds() {
        let now = Date(timeIntervalSince1970: 0)
        let kickoff = Date(timeIntervalSince1970: 3661) // 1h 01m 01s
        XCTAssertEqual(countdownString(to: kickoff, now: now), "1:01:01")
    }

    func testCountdownClampsToZeroInPast() {
        let now = Date(timeIntervalSince1970: 100)
        let kickoff = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(countdownString(to: kickoff, now: now), "0:00:00")
    }

    func testScheduledStatusMapping() {
        XCTAssertEqual(MatchStatus(matchStatus: 0, period: 0), .scheduled)
    }

    // Next-match selection is by earliest kickoff strictly after `now`, independent of
    // the (unreliable) calendar status code.
    func testNextMatchPicksEarliestFutureRegardlessOfStatus() {
        let now = Date(timeIntervalSince1970: 1000)
        func m(_ id: String, _ t: TimeInterval, _ s: MatchStatus) -> Match {
            let tm = Team(name: id, abbreviation: id, countryCode: "ZZZ")
            return Match(id: id, competitionId: "17", home: tm, away: tm,
                         homeScore: 0, awayScore: 0, status: s, clock: "",
                         kickoff: Date(timeIntervalSince1970: t))
        }
        let past = m("past", 500, .scheduled)     // before now -> excluded
        let soon = m("soon", 1500, .unknown)      // earliest future, status unreliable
        let later = m("later", 3000, .scheduled)
        XCTAssertEqual(nextMatch(from: [later, soon, past], now: now)?.id, "soon")
    }

    func testNextMatchNilWhenNoFutureMatches() {
        let now = Date(timeIntervalSince1970: 1000)
        let tm = Team(name: "A", abbreviation: "A", countryCode: "ZZZ")
        let past = Match(id: "p", competitionId: "17", home: tm, away: tm,
                         homeScore: 0, awayScore: 0, status: .scheduled, clock: "",
                         kickoff: Date(timeIntervalSince1970: 500))
        XCTAssertNil(nextMatch(from: [past], now: now))
    }
}
