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

/// A goal surfaced to the UI for one match. `token` is a monotonic id assigned by the
/// store so the view re-animates even when consecutive goals are otherwise identical.
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
/// (matched by id) are compared, so a match's first appearance is a baseline and never
/// reports its existing score as a goal. Each side that increased is reported once, with
/// `delta` = the score increase.
public func detectGoals(previous: [Match], current: [Match]) -> [Goal] {
    let prevById = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) // duplicate ids shouldn't occur in a snapshot; keep the first defensively
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
