import XCTest
@testable import SportNotchCore

final class MatchStatusTests: XCTestCase {
    func testLiveCodeMapsToLive() {
        XCTAssertEqual(MatchStatus(matchStatus: 3, period: 3), .live)
    }

    func testHalftimePeriodMapsToHalftime() {
        // A live match (status 3) in period 4 is the half-time break.
        XCTAssertEqual(MatchStatus(matchStatus: 3, period: 4), .halftime)
    }

    func testSecondHalfStaysLive() {
        // Period 5 (second half) is play, not the break, so it remains live.
        XCTAssertEqual(MatchStatus(matchStatus: 3, period: 5), .live)
    }

    func testUnknownCodeFallsBack() {
        XCTAssertEqual(MatchStatus(matchStatus: 999, period: 0), .unknown)
    }
}
