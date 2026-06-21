public enum Flag {
    /// FIFA/IOC 3-letter code -> ISO 3166-1 alpha-2. Starter subset; complete for
    /// every participating nation during implementation (spec §9). FIFA and ISO
    /// codes differ, so this must be an explicit map, not truncation.
    static let isoByFifaCode: [String: String] = [
        "ECU": "EC", "CUW": "CW", "GER": "DE", "FRA": "FR", "BRA": "BR",
        "ARG": "AR", "ESP": "ES", "USA": "US", "MEX": "MX", "POR": "PT",
        "NED": "NL", "BEL": "BE", "CRO": "HR", "JPN": "JP", "SUI": "CH",
        "ITA": "IT", "URU": "UY", "COL": "CO", "SEN": "SN", "MAR": "MA",
    ]

    /// Home nations are not ISO countries; map to the GB subdivision tag string.
    static let subdivisionByFifaCode: [String: String] = [
        "ENG": "gbeng", "SCO": "gbsct", "WAL": "gbwls",
    ]

    /// Flag emoji for a FIFA 3-letter country code, or "" when unmapped.
    public static func emoji(forCountryCode code: String) -> String {
        let key = code.uppercased()
        if let sub = subdivisionByFifaCode[key] { return tagFlag(sub) }
        if let iso = isoByFifaCode[key] { return regionalIndicator(iso) }
        return ""
    }

    static func regionalIndicator(_ iso2: String) -> String {
        let base: UInt32 = 0x1F1E6 // regional indicator 'A'
        var out = ""
        for scalar in iso2.uppercased().unicodeScalars {
            guard (65...90).contains(scalar.value) else { return "" }
            out.unicodeScalars.append(UnicodeScalar(base + (scalar.value - 65))!)
        }
        return out
    }

    static func tagFlag(_ subdivision: String) -> String {
        var out = String(UnicodeScalar(0x1F3F4)!) // waving black flag
        for ch in subdivision.unicodeScalars {
            guard ch.value <= 0x2FFFF,
                  let tag = UnicodeScalar(0xE0000 + ch.value) else { return "" }
            out.unicodeScalars.append(tag)
        }
        out.unicodeScalars.append(UnicodeScalar(0xE007F)!) // cancel tag
        return out
    }
}
