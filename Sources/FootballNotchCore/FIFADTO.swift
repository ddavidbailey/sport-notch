import Foundation

public let worldCupCompetitionId = "17"

/// Decodes to `nil` instead of throwing when an element is malformed, so one bad
/// match in the array doesn't discard the whole payload (spec §7).
fileprivate struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct FIFALocalizedText: Decodable {
    let description: String
    enum CodingKeys: String, CodingKey { case description = "Description" }
}

struct FIFATeamDTO: Decodable {
    let score: Int?
    let idCountry: String?
    let abbreviation: String?
    let teamName: [FIFALocalizedText]?
    enum CodingKeys: String, CodingKey {
        case score = "Score"
        case idCountry = "IdCountry"
        case abbreviation = "Abbreviation"
        case teamName = "TeamName"
    }
    func toDomain() -> Team {
        Team(name: teamName?.first?.description ?? "",
             abbreviation: abbreviation ?? "",
             countryCode: idCountry ?? "")
    }
}

struct FIFAMatchDTO: Decodable {
    // ISO8601DateFormatter is thread-safe for concurrent reads on Apple platforms.
    private nonisolated(unsafe) static let isoFormatter = ISO8601DateFormatter()
    let idMatch: String
    let idCompetition: String
    let matchStatus: Int?
    let period: Int?
    let matchTime: String?
    let date: String?
    let homeTeam: FIFATeamDTO
    let awayTeam: FIFATeamDTO
    enum CodingKeys: String, CodingKey {
        case idMatch = "IdMatch"
        case idCompetition = "IdCompetition"
        case matchStatus = "MatchStatus"
        case period = "Period"
        case matchTime = "MatchTime"
        case date = "Date"
        case homeTeam = "HomeTeam"
        case awayTeam = "AwayTeam"
    }
    func toDomain() -> Match {
        Match(id: idMatch,
              competitionId: idCompetition,
              home: homeTeam.toDomain(),
              away: awayTeam.toDomain(),
              homeScore: homeTeam.score ?? 0,
              awayScore: awayTeam.score ?? 0,
              status: MatchStatus(matchStatus: matchStatus ?? -1, period: period ?? -1),
              clock: matchTime ?? "",
              kickoff: date.flatMap { Self.isoFormatter.date(from: $0) }
                       ?? Date(timeIntervalSince1970: 0))
    }
}

fileprivate struct FIFAResponseDTO: Decodable {
    let results: [FailableDecodable<FIFAMatchDTO>]
    enum CodingKeys: String, CodingKey { case results = "Results" }
}

/// Decodes a FIFA `Results` payload and keeps only World Cup matches.
public func decodeLiveMatches(from data: Data) throws -> [Match] {
    let response = try JSONDecoder().decode(FIFAResponseDTO.self, from: data)
    return response.results
        .compactMap { $0.value }
        .filter { $0.idCompetition == worldCupCompetitionId }
        .map { $0.toDomain() }
}
