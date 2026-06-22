import Foundation

public protocol FootballService: Sendable {
    func fetchLiveMatches() async throws -> [Match]
    func fetchUpcomingMatches() async throws -> [Match]
}

public protocol DataFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionFetcher: DataFetching {
    public init() {}
    public func data(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

/// The next match to show when nothing is live: the earliest kickoff strictly after
/// `now`. Selection is by kickoff, not status — the FIFA calendar's status codes are
/// not chronologically reliable for upcoming fixtures.
public func nextMatch(from matches: [Match], now: Date) -> Match? {
    matches
        .filter { $0.kickoff > now }
        .min { $0.kickoff < $1.kickoff }
}

/// The soonest upcoming matches (kickoff strictly after `now`), earliest first.
/// Ordered by kickoff for the same reason as `nextMatch`: calendar status codes are
/// not chronologically reliable.
public func upcomingMatches(from matches: [Match], now: Date, count: Int = 3) -> [Match] {
    matches
        .filter { $0.kickoff > now }
        .sorted { $0.kickoff < $1.kickoff }
        .prefix(count)
        .map { $0 }
}

/// 2026 World Cup season id (verified against api.fifa.com on 2026-06-21). The
/// competitions/seasons endpoint isn't reachable to derive this at runtime, so it is
/// pinned here and must be updated for a future tournament.
public let worldCupSeasonId = "285023"

public struct FIFAService: FootballService {
    private let fetcher: any DataFetching

    public init(fetcher: any DataFetching = URLSessionFetcher()) {
        self.fetcher = fetcher
    }

    private static let liveURL = URL(string:
        "https://api.fifa.com/api/v3/live/football/now?language=en")!

    /// The full World Cup calendar. The API's `from=` parameter returns a null payload,
    /// and a small `count` only reaches the tournament's opening matches, so we pull the
    /// whole schedule (104 matches) once and filter to the soonest fixtures locally.
    private static let calendarURL = URL(string:
        "https://api.fifa.com/api/v3/calendar/matches?idCompetition=\(worldCupCompetitionId)&idSeason=\(worldCupSeasonId)&count=120&language=en")!

    public func fetchLiveMatches() async throws -> [Match] {
        let data = try await fetcher.data(from: Self.liveURL)
        return try decodeLiveMatches(from: data)
    }

    public func fetchUpcomingMatches() async throws -> [Match] {
        let data = try await fetcher.data(from: Self.calendarURL)
        return upcomingMatches(from: try decodeLiveMatches(from: data), now: Date())
    }
}
