import XCTest
@testable import FootballNotchCore

private struct MockService: FootballService {
    var live: [Match] = []
    var upcoming: [Match] = []
    var fail = false
    func fetchLiveMatches() async throws -> [Match] {
        if fail { throw URLError(.notConnectedToInternet) }
        return live
    }
    func fetchUpcomingMatches() async throws -> [Match] { upcoming }
}

private func team(_ code: String) -> Team {
    Team(name: code, abbreviation: code, countryCode: code)
}
private func match(_ id: String, status: MatchStatus = .live,
                   kickoff: TimeInterval = 0) -> Match {
    Match(id: id, competitionId: "17", home: team("ECU"), away: team("CUW"),
          homeScore: 0, awayScore: 0, status: status, clock: "1'",
          kickoff: Date(timeIntervalSince1970: kickoff))
}

private final class MutableService: FootballService, @unchecked Sendable {
    var live: [Match]
    var upcoming: [Match]
    init(live: [Match], upcoming: [Match]) { self.live = live; self.upcoming = upcoming }
    func fetchLiveMatches() async throws -> [Match] { live }
    func fetchUpcomingMatches() async throws -> [Match] { upcoming }
}

private func liveMatch(_ id: String, _ home: Int, _ away: Int) -> Match {
    Match(id: id, competitionId: "17", home: team("ECU"), away: team("CUW"),
          homeScore: home, awayScore: away, status: .live, clock: "5'",
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

    func testFetchesUpcomingMatches() async {
        let store = MatchStore(service: MockService(
            live: [],
            upcoming: [match("n", status: .scheduled, kickoff: 100)]))
        await store.refresh()
        XCTAssertTrue(store.liveMatches.isEmpty)
        XCTAssertEqual(store.upcomingMatches.map(\.id), ["n"])
        XCTAssertEqual(store.followedMatch?.id, "n")
    }

    func testSelectableMatchesAreThreeSoonest() async {
        let store = MatchStore(service: MockService(
            live: [match("live", status: .live, kickoff: -100)],
            upcoming: [
                match("u1", status: .scheduled, kickoff: 100),
                match("u2", status: .scheduled, kickoff: 200),
                match("u3", status: .scheduled, kickoff: 300),
            ]))
        await store.refresh()
        // Live match kicked off in the past, so it sorts first; only 3 are kept.
        XCTAssertEqual(store.selectableMatches.map(\.id), ["live", "u1", "u2"])
    }

    func testSelectingUpcomingThenGoingLiveKeepsSelection() async {
        let svc = MockService(
            live: [],
            upcoming: [match("u1", status: .scheduled, kickoff: 100)])
        let store = MatchStore(service: svc)
        await store.refresh()
        store.select(matchId: "u1")
        XCTAssertEqual(store.followedMatch?.id, "u1")
        XCTAssertFalse(store.followedMatch?.isLive ?? true)

        // The same fixture now appears live with a score.
        let live = Match(id: "u1", competitionId: "17",
                         home: team("ECU"), away: team("CUW"),
                         homeScore: 2, awayScore: 1, status: .live,
                         clock: "67'", kickoff: Date(timeIntervalSince1970: 100))
        let store2 = MatchStore(service: MockService(live: [live], upcoming: []))
        await store2.refresh()
        store2.select(matchId: "u1")
        XCTAssertEqual(store2.followedMatch?.homeScore, 2)
        XCTAssertTrue(store2.followedMatch?.isLive ?? false)
    }

    func testErrorRetainsLastKnownData() async {
        final class ToggleMock: FootballService, @unchecked Sendable {
            var fail = false
            func fetchLiveMatches() async throws -> [Match] {
                if fail { throw URLError(.notConnectedToInternet) }
                return [match("a")]
            }
            func fetchUpcomingMatches() async throws -> [Match] { [] }
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
        XCTAssertEqual(pollInterval(isLive: true), 30)
        XCTAssertEqual(pollInterval(isLive: false), 600)
    }

    func testGoalBetweenRefreshesPublishesFlash() async {
        let svc = MutableService(live: [liveMatch("g", 0, 0)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()                       // baseline 0–0
        XCTAssertNil(store.goalFlashes["g"])

        svc.live = [liveMatch("g", 1, 0)]           // home team scores
        await store.refresh()

        XCTAssertEqual(store.goalFlashes["g"]?.side, .home)
        XCTAssertEqual(store.goalFlashes["g"]?.delta, 1)
        XCTAssertEqual(store.goalFlashes["g"]?.token, 1)
    }

    func testFirstRefreshDoesNotFlash() async {
        let store = MatchStore(service: MutableService(live: [liveMatch("g", 2, 1)], upcoming: []))
        await store.refresh()
        XCTAssertTrue(store.goalFlashes.isEmpty)
    }

    func testFollowedLiveMatchEndingShowsFinalScore() async {
        let svc = MutableService(live: [liveMatch("g", 2, 1)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()                       // live 2–1
        XCTAssertTrue(store.followedMatch?.isLive ?? false)

        svc.live = []                               // match ends, drops from /now
        await store.refresh()

        XCTAssertEqual(store.followedMatch?.id, "g")
        XCTAssertEqual(store.followedMatch?.homeScore, 2)
        XCTAssertEqual(store.followedMatch?.awayScore, 1)
        XCTAssertEqual(store.followedMatch?.status, .finished)
        XCTAssertTrue(store.followedMatch?.isFinished ?? false)
    }

    func testSelectingAnotherMatchClearsFinal() async {
        let svc = MutableService(live: [liveMatch("g", 2, 1)],
                                 upcoming: [match("n", status: .scheduled, kickoff: 100)])
        let store = MatchStore(service: svc)
        await store.refresh()
        svc.live = []                               // "g" ends -> FINAL
        await store.refresh()
        XCTAssertTrue(store.followedMatch?.isFinished ?? false)

        store.select(matchId: "n")                  // switch dismisses FINAL
        XCTAssertNil(store.finishedMatch)
        XCTAssertEqual(store.followedMatch?.id, "n")
    }

    func testLingeringNonLiveEntryCountsAsFinished() async {
        let svc = MutableService(live: [liveMatch("g", 2, 1)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()
        // The feed keeps the match for a poll but flips it out of "in play".
        svc.live = [Match(id: "g", competitionId: "17", home: team("ECU"), away: team("CUW"),
                          homeScore: 2, awayScore: 1, status: .unknown, clock: "FT",
                          kickoff: Date(timeIntervalSince1970: 0))]
        await store.refresh()
        XCTAssertEqual(store.followedMatch?.status, .finished)
        XCTAssertEqual(store.followedMatch?.homeScore, 2)
    }

    func testFinalSelfHealsIfMatchReappearsLive() async {
        let svc = MutableService(live: [liveMatch("g", 2, 1)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()
        svc.live = []                               // transient drop -> FINAL
        await store.refresh()
        XCTAssertTrue(store.followedMatch?.isFinished ?? false)

        svc.live = [liveMatch("g", 2, 1)]           // it was just a blip; back in play
        await store.refresh()
        XCTAssertNil(store.finishedMatch)
        XCTAssertTrue(store.followedMatch?.isLive ?? false)
    }

    func testFollowedNonLiveFeedEntryDoesNotFinish() async {
        // A scheduled fixture can appear in the live feed; if it is followed and then
        // drops without ever being in play, it must not be retained as FINAL.
        let svc = MutableService(live: [match("s", status: .scheduled, kickoff: 0)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()
        XCTAssertEqual(store.followedMatch?.id, "s")
        svc.live = []
        await store.refresh()
        XCTAssertNil(store.finishedMatch)
    }

    func testAutoFollowedMatchEndingSticksOverUpcoming() async {
        // No explicit selection: a live match that ends keeps showing FINAL rather than
        // jumping to the next upcoming fixture.
        let svc = MutableService(live: [liveMatch("g", 3, 0)],
                                 upcoming: [match("n", status: .scheduled, kickoff: 100)])
        let store = MatchStore(service: svc)
        await store.refresh()
        svc.live = []
        await store.refresh()
        XCTAssertEqual(store.followedMatch?.id, "g")
        XCTAssertTrue(store.followedMatch?.isFinished ?? false)
    }

    func testFinalPersistsAcrossLaterRefreshes() async {
        let svc = MutableService(live: [liveMatch("g", 1, 0)], upcoming: [])
        let store = MatchStore(service: svc)
        await store.refresh()
        svc.live = []
        await store.refresh()
        await store.refresh()                       // still gone, several polls later
        await store.refresh()
        XCTAssertEqual(store.followedMatch?.id, "g")
        XCTAssertTrue(store.followedMatch?.isFinished ?? false)
    }
}
