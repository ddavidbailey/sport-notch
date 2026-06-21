import XCTest
@testable import FootballNotchCore

final class MatchStatusTests: XCTestCase {
    func testLiveCodeMapsToLive() {
        XCTAssertEqual(MatchStatus(matchStatus: 3, period: 3), .live)
    }

    func testUnknownCodeFallsBack() {
        XCTAssertEqual(MatchStatus(matchStatus: 999, period: 0), .unknown)
    }
}
