import Foundation

public enum MatchStatus: Equatable, Sendable {
    case scheduled, live, halftime, finished, abandoned, unknown

    /// Maps FIFA's undocumented numeric codes to a domain status. Confirmed against
    /// the live feed: 0 = not-started (scheduled), 3 = live. While a match is live the
    /// `period` distinguishes the half-time break (4) from play (3 = first half,
    /// 5 = second half); the feed nulls MatchTime during the break, so this is the only
    /// reliable half-time signal. Other codes (including the calendar's unreliable
    /// values) degrade to `.unknown` rather than guessing.
    public init(matchStatus: Int, period: Int) {
        switch matchStatus {
        case 0: self = .scheduled
        case 3: self = period == 4 ? .halftime : .live
        default: self = .unknown
        }
    }
}

public struct Team: Equatable, Sendable {
    public let name: String
    public let abbreviation: String
    public let countryCode: String

    public var flag: String { Flag.emoji(forCountryCode: countryCode) }

    public init(name: String, abbreviation: String, countryCode: String) {
        self.name = name
        self.abbreviation = abbreviation
        self.countryCode = countryCode
    }
}

public struct Match: Equatable, Identifiable, Sendable {
    public let id: String
    public let competitionId: String
    public let home: Team
    public let away: Team
    public let homeScore: Int
    public let awayScore: Int
    public let status: MatchStatus
    public let clock: String
    public let kickoff: Date

    public var isLive: Bool { status == .live || status == .halftime }
    public var isHalftime: Bool { status == .halftime }
    public var isFinished: Bool { status == .finished }

    public init(id: String, competitionId: String, home: Team, away: Team,
                homeScore: Int, awayScore: Int, status: MatchStatus,
                clock: String, kickoff: Date) {
        self.id = id
        self.competitionId = competitionId
        self.home = home
        self.away = away
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.status = status
        self.clock = clock
        self.kickoff = kickoff
    }

    /// A copy marked `.finished`, for retaining a match's final score once it leaves the
    /// live feed. Score, teams, and kickoff are preserved; only the status changes.
    public func markedFinished() -> Match {
        Match(id: id, competitionId: competitionId, home: home, away: away,
              homeScore: homeScore, awayScore: awayScore, status: .finished,
              clock: clock, kickoff: kickoff)
    }
}
