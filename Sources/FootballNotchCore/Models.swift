import Foundation

public enum MatchStatus: Equatable {
    case scheduled, live, halftime, finished, abandoned, unknown

    /// Maps FIFA's undocumented numeric codes to a domain status.
    /// Only `.live` (observed value 3) is confirmed today; `.scheduled` is added
    /// in Task 7 after verifying the calendar endpoint. Unknown codes stay `.unknown`.
    public init(matchStatus: Int, period: Int) {
        switch matchStatus {
        case 3: self = .live
        default: self = .unknown
        }
    }
}

public struct Team: Equatable {
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

public struct Match: Equatable, Identifiable {
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
}
