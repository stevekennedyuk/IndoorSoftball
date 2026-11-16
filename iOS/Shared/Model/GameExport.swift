import Foundation

/// Results export: the text document saved for each finished game, its file
/// name, and the subject / message used when sharing it.
extension Game {
    /// When play actually started (first time the clock was started), falling
    /// back to when the game was set up if the clock was never started.
    var playStart: Date { playStartedAt ?? startedAt }

    /// The location, or "Location" if none was entered (like "Home" / "Away"
    /// for team names left blank).
    var place: String {
        if let loc = location, !loc.isEmpty { return loc }
        return "Location"
    }

    /// Scored on the Apple Watch.
    var isFromWatch: Bool { scoredOn == "Watch" }

    /// A Watch game still showing the default Away / Home names or no location –
    /// History prompts for the details.
    var needsDetails: Bool {
        isFromWatch && ((awayName == "Away" && homeName == "Home") || location == nil)
    }

    // MARK: File name

    /// home-away-location-date&time, e.g.
    /// "Owls-Hawks-Hackney Leisure Centre-2026-11-08 1930.txt", or
    /// "Home-Away-Location-2026-11-08 1930.txt" if nothing was entered.
    var exportFileName: String {
        [Self.fileSafe(homeName, fallback: "Home"),
         Self.fileSafe(awayName, fallback: "Away"),
         Self.fileSafe(place, fallback: "Location"),
         Self.stamp(playStart, "yyyy-MM-dd HHmm")].joined(separator: "-") + ".txt"
    }

    /// Removes characters that aren't allowed (or are awkward) in file names.
    static func fileSafe(_ name: String, fallback: String = "Team") -> String {
        let banned = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        var s = name.components(separatedBy: banned).joined(separator: "-")
        s = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        if s.isEmpty { s = fallback }
        return String(s.prefix(40)).trimmingCharacters(in: .whitespaces)
    }

    /// "5:00", "30s" (Foundation-only so the export has no SwiftUI dependency).
    static func durationText(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func stamp(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    // MARK: Sharing

    /// Subject line apps such as Mail use when the file is shared, e.g.
    /// "Indoor Softball: Hawks 16 – Owls 17, Hackney Leisure Centre (8 Nov 2026, 19:30)"
    var shareSubject: String {
        "Indoor Softball: \(awayName) \(total(.away).scoreString) – \(homeName) \(total(.home).scoreString), \(place) (\(Self.stamp(playStart, "d MMM yyyy, HH:mm")))"
    }

    /// Message shared alongside the file: the results document itself.
    var shareMessage: String { resultsDocument }

    // MARK: Results document

    /// The results document, laid out as:
    ///
    ///     Hawks vs Owls : Hackney Leisure Centre : 08/11/2026 : 19:30
    ///     Inning 1
    ///     Hawks: +11 : -2 : 9
    ///     Owls: +8 : -2 : 6
    ///     Inning 2
    ///     Hawks: +9 : -2 : 7
    ///     Owls: +12 : -1 : 11
    ///
    ///     End Game
    ///     Hawks: 16
    ///     Owls: 17
    ///
    /// Each inning line is that team's plus, minus and total for the inning.
    /// Blank names / location appear as Away, Home and Location. A half that
    /// wasn't played (game ended early) shows "not played".
    var resultsDocument: String {
        func plus(_ v: Int) -> String { "+\(v)" }
        func minus(_ v: Int) -> String { v == 0 ? "-0" : "-\(-v)" }
        let header = ["\(awayName) vs \(homeName)", place,
                      Self.stamp(playStart, "dd/MM/yyyy"), Self.stamp(playStart, "HH:mm")]

        var lines = [header.joined(separator: " : ")]
        for inning in 1...max(1, inningsCount) {
            lines.append("Inning \(inning)")
            for team in [Team.away, .home] {
                guard let h = half(team: team, inning: inning) else { continue }
                if isReached(h) {
                    lines.append("\(name(team)): \(plus(h.positive)) : \(minus(h.negative)) : \(h.net)")
                } else {
                    lines.append("\(name(team)): not played")
                }
            }
        }
        lines.append("")
        lines.append(isFinished ? "End Game" : "Score so far")
        lines.append("\(awayName): \(total(.away))")
        lines.append("\(homeName): \(total(.home))")
        return lines.joined(separator: "\n") + "\n"
    }

}
