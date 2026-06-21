import Foundation

public protocol FootballService: Sendable {
    func fetchLiveMatches() async throws -> [Match]
    func fetchNextMatch() async throws -> Match?
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

    /// Formats the outgoing `from` query parameter (distinct from the DTO parser's formatter).
    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()

    private static func nextMatchURL(now: Date) -> URL {
        let from = iso.string(from: now)
        return URL(string:
            "https://api.fifa.com/api/v3/calendar/matches?idCompetition=\(worldCupCompetitionId)&idSeason=\(worldCupSeasonId)&from=\(from)&count=20&language=en")!
    }

    public func fetchLiveMatches() async throws -> [Match] {
        let data = try await fetcher.data(from: Self.liveURL)
        return try decodeLiveMatches(from: data)
    }

    public func fetchNextMatch() async throws -> Match? {
        let now = Date()
        let data = try await fetcher.data(from: Self.nextMatchURL(now: now))
        return nextMatch(from: try decodeLiveMatches(from: data), now: now)
    }
}
