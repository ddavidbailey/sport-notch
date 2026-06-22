import Foundation

public enum GoalSide: Sendable, Equatable { case home, away }

public struct Goal: Sendable, Equatable {
    public let matchId: String
    public let side: GoalSide
    public let delta: Int
    public init(matchId: String, side: GoalSide, delta: Int) {
        self.matchId = matchId
        self.side = side
        self.delta = delta
    }
}

/// goal surfaced UI one match. `token` monotonic id assigned
/// store view re-animates even consecutive goals otherwise identical.
public struct GoalFlash: Sendable, Equatable {
    public let side: GoalSide
    public let delta: Int
    public let token: Int
    public init(side: GoalSide, delta: Int, token: Int) {
        self.side = side
        self.delta = delta
        self.token = token
    }
}

/// Goals scored between two live-match snapshots. Only matches present in BOTH snapshots
/// (matched by id) compared, match's first appearance baseline never
/// reports existing score goal. Each side increased reported once,
/// `delta` = score increase.
public func detectGoals(previous: [Match], current: [Match]) -> [Goal] {
    let prevById = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var goals: [Goal] = []
    for match in current {
        guard let old = prevById[match.id] else { continue }
        if match.homeScore > old.homeScore {
            goals.append(Goal(matchId: match.id, side: .home, delta: match.homeScore - old.homeScore))
        }
        if match.awayScore > old.awayScore {
            goals.append(Goal(matchId: match.id, side: .away, delta: match.awayScore - old.awayScore))
        }
    }
    return goals
}
