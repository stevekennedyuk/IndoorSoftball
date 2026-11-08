import Foundation

extension Game {
    /// Plain-text report for sharing (Messages, WhatsApp, email…).
    var textReport: String {
        var lines: [String] = []
        lines.append("Indoor Softball – \(awayName) v \(homeName)")
        lines.append("Play started: \(playStart.formatted(date: .abbreviated, time: .shortened))")
        if let end = endedAt { lines.append("Finished: \(end.formatted(date: .omitted, time: .shortened))") }
        lines.append(isFinished ? resultText : "In progress (\(current.label))")
        lines.append("")
        lines.append("\(awayName): \(total(.away).scoreString)   \(homeName): \(total(.home).scoreString)")
        lines.append("")
        for inning in 1...max(1, inningsCount) {
            lines.append("Inning \(inning)")
            for team in Team.allCases {
                guard let h = half(team: team, inning: inning) else { continue }
                if isReached(h) {
                    let neg = h.negative == 0 ? "−0" : h.negative.signedString
                    lines.append("  \(h.isTop ? "Top" : "Bot") \(name(team)): +\(h.positive) \(neg) = \(h.net.scoreString)")
                } else {
                    lines.append("  \(h.isTop ? "Top" : "Bot") \(name(team)): not played")
                }
            }
            if let bottom = half(team: .home, inning: inning), isReached(bottom) {
                lines.append("  End of inning: \(awayName) \(cumulative(.away, throughInning: inning).scoreString) – \(homeName) \(cumulative(.home, throughInning: inning).scoreString)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
