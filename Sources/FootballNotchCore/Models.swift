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
