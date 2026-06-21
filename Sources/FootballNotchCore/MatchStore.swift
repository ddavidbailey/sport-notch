import Foundation
import Combine

public enum ConnectionState: Equatable, Sendable { case fresh, stale, error }

@MainActor
public final class MatchStore: ObservableObject {
    @Published public private(set) var liveMatches: [Match] = []
    @Published public private(set) var nextMatch: Match?
    @Published public private(set) var followedMatchId: String?
    @Published public private(set) var connection: ConnectionState = .fresh

    private let service: any FootballService

    public init(service: any FootballService) {
        self.service = service
    }

    /// The followed match, defaulting to the first live match when none chosen.
    public var followedMatch: Match? {
        liveMatches.first { $0.id == followedMatchId } ?? liveMatches.first
    }

    public func select(matchId: String) {
        guard liveMatches.contains(where: { $0.id == matchId }) else { return }
        followedMatchId = matchId
    }

    /// Fetches live matches (and the next match when idle), updating published state.
    /// Expects serial invocation — the app's poll loop awaits one refresh before the
    /// next, so there is no guard against overlapping calls.
    public func refresh() async {
        do {
            let live = try await service.fetchLiveMatches()
            liveMatches = live

            if let id = followedMatchId, !live.contains(where: { $0.id == id }) {
                followedMatchId = live.first?.id
            } else if followedMatchId == nil {
                followedMatchId = live.first?.id
            }

            nextMatch = live.isEmpty ? try await service.fetchNextMatch() : nil
            connection = .fresh
        } catch {
            connection = .error // keep last known liveMatches/nextMatch
        }
    }
}

/// Poll fast while a match is live, slowly while idle (protects the feed).
public func pollInterval(isLive: Bool) -> TimeInterval { isLive ? 90 : 600 }
