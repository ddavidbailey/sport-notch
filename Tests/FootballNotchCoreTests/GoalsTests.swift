import XCTest
@testable import FootballNotchCore

private func m(_ id: String, _ home: Int, _ away: Int) -> Match {
    Match(id: id, competitionId: "17",
          home: Team(name: "H", abbreviation: "H", countryCode: "BRA"),
          away: Team(name: "A", abbreviation: "A", countryCode: "ARG"),
          homeScore: home, awayScore: away, status: .live, clock: "1'",
          kickoff: Date(timeIntervalSince1970: 0))
}

final class GoalsTests: XCTestCase {
    func testHomeGoalDetected() {
        let goals = detectGoals(previous: [m("x", 0, 0)], current: [m("x", 1, 0)])
        XCTAssertEqual(goals, [Goal(matchId: "x", side: .home, delta: 1)])
    }

    func testAwayGoalDetected() {
        let goals = detectGoals(previous: [m("x", 1, 0)], current: [m("x", 1, 1)])
        XCTAssertEqual(goals, [Goal(matchId: "x", side: .away, delta: 1)])
    }

    func testMultipleGoalsAcrossWindowUseDelta() {
        let goals = detectGoals(previous: [m("x", 0, 0)], current: [m("x", 2, 0)])
        XCTAssertEqual(goals, [Goal(matchId: "x", side: .home, delta: 2)])
    }

    func testNewMatchEstablishesBaselineNoGoal() {
        // "x" only appears in current — its score must not be reported as a goal.
        let goals = detectGoals(previous: [], current: [m("x", 1, 0)])
        XCTAssertEqual(goals, [])
    }

    func testUnchangedScoreNoGoal() {
        let goals = detectGoals(previous: [m("x", 1, 1)], current: [m("x", 1, 1)])
        XCTAssertEqual(goals, [])
    }

    func testMatchLeavingFeedNoGoal() {
        let goals = detectGoals(previous: [m("x", 1, 0)], current: [])
        XCTAssertEqual(goals, [])
    }
}
