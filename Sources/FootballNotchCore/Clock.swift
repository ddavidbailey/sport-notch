import Foundation

/// Advances a simple "N'" clock by one minute for smooth ticking between polls.
/// Non-numeric clocks (stoppage "45+1'", "HT") are returned unchanged.
public func incrementClock(_ clock: String) -> String {
    let trimmed = clock.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
    if let minute = Int(trimmed) { return "\(minute + 1)'" }
    return clock
}

/// Formats the time until kickoff as H:MM:SS, clamped at zero.
public func countdownString(to kickoff: Date, now: Date) -> String {
    let remaining = max(0, Int(kickoff.timeIntervalSince(now)))
    return String(format: "%d:%02d:%02d",
                  remaining / 3600, (remaining % 3600) / 60, remaining % 60)
}
