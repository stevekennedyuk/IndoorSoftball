import Foundation

/// Results export: the CSV file saved for each finished game, its file name,
/// and the email subject/body used by "Email results".
extension Game {
    /// When play actually started (first time the clock was started), falling
    /// back to when the game was set up if the clock was never started.
    var playStart: Date { playStartedAt ?? startedAt }

    // MARK: File name

    /// e.g. "2026-11-08 1930 Hawks v Owls.csv" – date first so files sort in order.
    var exportFileName: String {
        "\(Self.stamp(playStart, "yyyy-MM-dd HHmm")) \(Self.fileSafe(awayName)) v \(Self.fileSafe(homeName)).csv"
    }

    /// Removes characters that aren't allowed (or are awkward) in file names.
    static func fileSafe(_ name: String) -> String {
        let banned = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        var s = name.components(separatedBy: banned).joined(separator: "-")
        s = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        if s.isEmpty { s = "Team" }
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

    // MARK: Email

    /// e.g. "Indoor Softball: Hawks 16 – Owls 17 (8 Nov 2026, 19:30)"
    var emailSubject: String {
        "Indoor Softball: \(awayName) \(total(.away).scoreString) – \(homeName) \(total(.home).scoreString) (\(Self.stamp(playStart, "d MMM yyyy, HH:mm")))"
    }

    var emailBody: String {
        textReport + "\n\nThe full scoresheet is attached as a CSV file (opens in Numbers, Excel or Google Sheets).\n\nSent from Indoor Softball – nettek.uk"
    }

    // MARK: CSV

    /// Spreadsheet-friendly scoresheet. Uses plain "-" for negatives so
    /// spreadsheets read them as numbers.
    var csv: String {
        func n(_ v: Int) -> String { String(v) }              // ASCII minus
        func field(_ s: String) -> String {
            if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        let a = field(awayName), h = field(homeName)
        var rows: [String] = []
        rows.append(field("Indoor Softball – \(awayName) v \(homeName)"))
        rows.append("Play started,\(Self.stamp(playStart, "yyyy-MM-dd HH:mm"))")
        if let end = endedAt { rows.append("Finished,\(Self.stamp(end, "yyyy-MM-dd HH:mm"))") }
        rows.append("Settings,\(settings.innings) innings x \(Self.durationText(settings.halfInningSeconds)) · HR +\(settings.homeRunPoints)")
        rows.append("")
        rows.append("Inning,Half,Batting,Plus,Minus,Half total,\(a) running,\(h) running")
        var runA = 0, runH = 0
        for half in halves {
            let batting = field(name(half.battingTeam))
            if isReached(half) {
                if half.battingTeam == .away { runA += half.net } else { runH += half.net }
                rows.append("\(half.inning),\(half.isTop ? "Top" : "Bottom"),\(batting),\(n(half.positive)),\(n(half.negative)),\(n(half.net)),\(n(runA)),\(n(runH))")
            } else {
                rows.append("\(half.inning),\(half.isTop ? "Top" : "Bottom"),\(batting),,,not played,,")
            }
        }
        rows.append("")
        rows.append("Inning,\(a),\(h)")
        for inning in 1...max(1, inningsCount) {
            if let bottom = half(team: .home, inning: inning), isReached(bottom) {
                rows.append("End of inning \(inning),\(n(cumulative(.away, throughInning: inning))),\(n(cumulative(.home, throughInning: inning)))")
            }
        }
        rows.append("")
        rows.append("Team,Plus,Minus,Total")
        rows.append("\(a),\(n(positiveTotal(.away))),\(n(negativeTotal(.away))),\(n(total(.away)))")
        rows.append("\(h),\(n(positiveTotal(.home))),\(n(negativeTotal(.home))),\(n(total(.home)))")
        let ta = total(.away), th = total(.home)
        let result: String
        if !isFinished { result = "In progress" }
        else if ta == th { result = "Tied \(ta) - \(th)" }
        else if ta > th { result = "\(awayName) win \(ta) - \(th)" }
        else { result = "\(homeName) win \(th) - \(ta)" }
        rows.append("Result,\(field(result))")
        return rows.joined(separator: "\r\n") + "\r\n"
    }
}
