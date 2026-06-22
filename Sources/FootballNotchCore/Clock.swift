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

/// Formats a kickoff for display: a locale short time ("9:00 PM") when `kickoff` is the
/// same calendar day as `now`, otherwise prefixed with the abbreviated weekday
/// ("Tue 9:00 PM"). Day boundaries and the displayed time use `calendar`'s time zone.
public func kickoffString(_ kickoff: Date, now: Date,
                          calendar: Calendar = .current,
                          locale: Locale = .current) -> String {
    let timeFmt = DateFormatter()
    timeFmt.locale = locale
    timeFmt.timeZone = calendar.timeZone
    timeFmt.setLocalizedDateFormatFromTemplate("jmm")
    let time = timeFmt.string(from: kickoff)

    if calendar.isDate(kickoff, inSameDayAs: now) { return time }

    let dayFmt = DateFormatter()
    dayFmt.locale = locale
    dayFmt.timeZone = calendar.timeZone
    dayFmt.dateFormat = "EEE"
    return "\(dayFmt.string(from: kickoff)) \(time)"
}
