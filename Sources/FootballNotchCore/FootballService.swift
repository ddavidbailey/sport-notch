import Foundation

public protocol FootballService {
    func fetchLiveMatches() async throws -> [Match]
}

public protocol DataFetching {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionFetcher: DataFetching {
    public init() {}
    public func data(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

public struct FIFAService: FootballService {
    private let fetcher: any DataFetching

    public init(fetcher: any DataFetching = URLSessionFetcher()) {
        self.fetcher = fetcher
    }

    private static let liveURL = URL(string:
        "https://api.fifa.com/api/v3/live/football/now?language=en")!

    public func fetchLiveMatches() async throws -> [Match] {
        let data = try await fetcher.data(from: Self.liveURL)
        return try decodeLiveMatches(from: data)
    }
}
