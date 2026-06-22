import XCTest
@testable import SportNotchCore

private struct StubFetcher: DataFetching {
    let payload: Data
    func data(from url: URL) async throws -> Data { payload }
}

final class ServiceTests: XCTestCase {
    func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testFetchLiveMatchesReturnsWorldCupOnly() async throws {
        let service = FIFAService(fetcher: StubFetcher(payload: try loadFixture("live_now")))
        let matches = try await service.fetchLiveMatches()
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.home.name, "Ecuador")
    }
}
