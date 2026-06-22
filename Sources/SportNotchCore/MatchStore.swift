import Foundation
import Combine

public enum ConnectionState: Equatable, Sendable { case fresh, stale, error }

@MainActor
public final class MatchStore: ObservableObject {
    @Published public private(set) var liveMatches: [Match] = []
    @Published public private(set) var upcomingMatches: [Match] = []
    @Published public private(set) var followedMatchId: String?
    @Published public private(set) var connection: ConnectionState = .fresh
    @Published public private(set) var goalFlashes: [String: GoalFlash] = [:]

    /// The followed match retained with its final score after it left the live feed.
    /// Takes precedence as the displayed match and persists until the user selects
    /// another match (`select`) or that same match returns live (a transient blip).
    @Published public private(set) var finishedMatch: Match?

    /// When true, the notch is collapsed to just the soccer-ball pill. Cleared by the
    /// user reopening it (`restore`) or by a fresh kickoff (see `refresh`).
    @Published public private(set) var isMinimized = false

    private let service: any FootballService
    private var goalToken = 0

    public init(service: any FootballService) {
        self.service = service
    }

    /// All known matches, live ones first. Live matches kicked off in the past so they
    /// sort ahead of upcoming fixtures.
    private var allMatches: [Match] { liveMatches + upcomingMatches }

    /// The 3 soonest matches (live + upcoming), earliest kickoff first, de-duplicated.
    /// A match keeps its identity as it transitions from upcoming to live, so the user's
    /// selection survives kickoff.
    public var selectableMatches: [Match] {
        var seen = Set<String>()
        return allMatches
            .enumerated()
            .sorted { ($0.element.kickoff, $0.offset) < ($1.element.kickoff, $1.offset) }
            .map(\.element)
            .filter { seen.insert($0.id).inserted }
            .prefix(3)
            .map { $0 }
    }

    /// The match the user is following: the explicit selection if it still exists,
    /// otherwise the soonest match. Resolves to the live copy (with score) once the
    /// selected fixture kicks off.
    public var followedMatch: Match? {
        if let finishedMatch { return finishedMatch }
        if let id = followedMatchId, let match = allMatches.first(where: { $0.id == id }) {
            return match
        }
        return selectableMatches.first
    }

    public func select(matchId: String) {
        guard allMatches.contains(where: { $0.id == matchId }) else { return }
        finishedMatch = nil           // switching matches dismisses a retained FINAL
        followedMatchId = matchId
    }

    public func minimize() { isMinimized = true }
    public func restore() { isMinimized = false }

    /// Fetches live and upcoming matches, updating published state. Expects serial
    /// invocation — the app's poll loop awaits one refresh before the next.
    public func refresh() async {
        do {
            let live = try await service.fetchLiveMatches()
            let upcoming = try await service.fetchUpcomingMatches()
            let previousLive = liveMatches
            let previouslyDisplayed = followedMatch
            liveMatches = live
            upcomingMatches = upcoming

            for goal in detectGoals(previous: previousLive, current: live) {
                goalToken += 1
                goalFlashes[goal.matchId] = GoalFlash(side: goal.side, delta: goal.delta, token: goalToken)
            }

            // Self-heal: a retained match that reappears in play was a transient feed drop,
            // not an ending — let it resume showing live.
            if let finished = finishedMatch,
               live.contains(where: { $0.id == finished.id && $0.isLive }) {
                finishedMatch = nil
            }

            // Retain the displayed match's final score when it leaves the live feed. The
            // previous live snapshot carries the score; FINAL then persists until the user
            // selects another match.
            if finishedMatch == nil, let shown = previouslyDisplayed,
               let endedSnapshot = previousLive.first(where: { $0.id == shown.id && $0.isLive }),
               !live.contains(where: { $0.id == shown.id && $0.isLive }) {
                finishedMatch = endedSnapshot.markedFinished()
            }

            // A fresh kickoff while minimized reopens the notch and follows the new
            // match. "Fresh" means newly in play this refresh — a match that was already
            // live and is merely continuing is not a kickoff edge, so it won't reopen.
            if isMinimized {
                let wasLive = Set(previousLive.filter(\.isLive).map(\.id))
                if let kickoff = live
                    .filter({ $0.isLive && !wasLive.contains($0.id) })
                    .min(by: { $0.kickoff < $1.kickoff }) {
                    finishedMatch = nil
                    followedMatchId = kickoff.id
                    isMinimized = false
                }
            }

            // Drop a stale selection whose match has dropped out of both feeds.
            if let id = followedMatchId,
               !(live + upcoming).contains(where: { $0.id == id }) {
                followedMatchId = nil
            }
            connection = .fresh
        } catch {
            connection = .error // keep last known live/upcoming matches
        }
    }
}

/// Poll fast while a match is live, slowly while idle (protects the feed).
public func pollInterval(isLive: Bool) -> TimeInterval { isLive ? 30 : 600 }
