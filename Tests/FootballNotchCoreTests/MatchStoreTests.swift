import XCTest
@testable import FootballNotchCore

private struct MockService: FootballService {
    var live: [Match] = []
    var next: Match? = nil
    var fail = false
    func fetchLiveMatches() async throws -> [Match] {
        if fail { throw URLError(.notConnectedToInternet) }
        return live
    }
    func fetchNextMatch() async throws -> Match? { next }
}

private func team(_ code: String) -> Team {
    Team(name: code, abbreviation: code, countryCode: code)
}
private func match(_ id: String, status: MatchStatus = .live) -> Match {
    Match(id: id, competitionId: "17", home: team("ECU"), away: team("CUW"),
          homeScore: 0, awayScore: 0, status: status, clock: "1'",
          kickoff: Date(timeIntervalSince1970: 0))
}

@MainActor
final class MatchStoreTests: XCTestCase {
    func testRefreshSelectsFirstMatchByDefault() async {
        let store = MatchStore(service: MockService(live: [match("a"), match("b")]))
        await store.refresh()
        XCTAssertEqual(store.liveMatches.count, 2)
        XCTAssertEqual(store.followedMatch?.id, "a")
        XCTAssertEqual(store.connection, .fresh)
    }

    func testSelectChangesFollowedMatch() async {
        let store = MatchStore(service: MockService(live: [match("a"), match("b")]))
        await store.refresh()
        store.select(matchId: "b")
        XCTAssertEqual(store.followedMatch?.id, "b")
    }

    func testSelectInvalidIdIsIgnored() async {
        let store = MatchStore(service: MockService(live: [match("a")]))
        await store.refresh()
        store.select(matchId: "zzz")
        XCTAssertEqual(store.followedMatch?.id, "a")
    }

    func testIdleFetchesNextMatch() async {
        let store = MatchStore(service: MockService(live: [], next: match("n", status: .scheduled)))
        await store.refresh()
        XCTAssertTrue(store.liveMatches.isEmpty)
        XCTAssertEqual(store.nextMatch?.id, "n")
    }

    func testErrorRetainsLastKnownData() async {
        final class ToggleMock: FootballService, @unchecked Sendable {
            var fail = false
            func fetchLiveMatches() async throws -> [Match] {
                if fail { throw URLError(.notConnectedToInternet) }
                return [match("a")]
            }
            func fetchNextMatch() async throws -> Match? { nil }
        }
        let svc = ToggleMock()
        let store = MatchStore(service: svc)
        await store.refresh()                          // succeeds — loads match "a"
        XCTAssertEqual(store.liveMatches.count, 1)
        XCTAssertEqual(store.connection, .fresh)
        svc.fail = true
        await store.refresh()                          // fails on next poll
        XCTAssertEqual(store.connection, .error)
        XCTAssertEqual(store.liveMatches.count, 1)     // retained, not cleared
        XCTAssertEqual(store.followedMatch?.id, "a")   // selection retained
    }

    func testPollIntervalLiveVsIdle() {
        XCTAssertEqual(pollInterval(isLive: true), 90)
        XCTAssertEqual(pollInterval(isLive: false), 600)
    }
}
