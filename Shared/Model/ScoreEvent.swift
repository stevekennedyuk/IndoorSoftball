import Foundation

/// The things that can happen that change the score.
enum ScoreEventKind: String, Codable, CaseIterable, Sendable {
    case firstBase          // batter reaches 1st off the bat
    case secondBase         // batter reaches 2nd off the bat
    case thirdBase          // batter reaches 3rd off the bat
    case homeOnHit          // batter gets all the way home off the bat
    case runnerHome         // a runner already on base crosses home plate
    case homeRun            // ball hits the back wall: home run, all runners score
    case batterOut          // batter out (strike-out, caught, forced, etc.)
    case runnerOut          // runner out anywhere (other than below)
    case outAtHomeByCatcher // runner out at home, put out by the catcher
    case adjustPlus         // manual correction +1
    case adjustMinus        // manual correction -1

    /// Short label for buttons and logs.
    var shortLabel: String {
        switch self {
        case .firstBase: "1st"
        case .secondBase: "2nd"
        case .thirdBase: "3rd"
        case .homeOnHit: "Home"
        case .runnerHome: "Run"
        case .homeRun: "Home Run"
        case .batterOut: "Batter Out"
        case .runnerOut: "Runner Out"
        case .outAtHomeByCatcher: "Out @ Home"
        case .adjustPlus: "+1"
        case .adjustMinus: "−1"
        }
    }

    /// Fuller description for logs and accessibility.
    var longLabel: String {
        switch self {
        case .firstBase: "Batter to 1st"
        case .secondBase: "Batter to 2nd"
        case .thirdBase: "Batter to 3rd"
        case .homeOnHit: "Batter home off the hit"
        case .runnerHome: "Runner crossed home"
        case .homeRun: "Home run"
        case .batterOut: "Batter out"
        case .runnerOut: "Runner out"
        case .outAtHomeByCatcher: "Runner out at home by catcher"
        case .adjustPlus: "+1 point"
        case .adjustMinus: "−1 point"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .firstBase: "1.circle.fill"
        case .secondBase: "2.circle.fill"
        case .thirdBase: "3.circle.fill"
        case .homeOnHit: "house.fill"
        case .runnerHome: "figure.run"
        case .homeRun: "star.fill"
        case .batterOut: "xmark.circle.fill"
        case .runnerOut: "figure.run.circle.fill"
        case .outAtHomeByCatcher: "shield.lefthalf.filled"
        case .adjustPlus: "plus.circle"
        case .adjustMinus: "minus.circle"
        }
    }

    var isOut: Bool {
        switch self {
        case .batterOut, .runnerOut, .outAtHomeByCatcher: true
        default: false
        }
    }
}

/// One scoring entry in a half inning. The points are fixed when the entry is
/// made so later changes to settings never rewrite history.
struct ScoreEvent: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var kind: ScoreEventKind
    var points: Int
    /// For a home run: how many runners were on base (each scores `runPoints`).
    var runnersOn: Int = 0
    var timestamp: Date = Date()

    var description: String {
        if kind == .homeRun && runnersOn > 0 {
            return "\(kind.longLabel) + \(runnersOn) on"
        }
        return kind.longLabel
    }
}

/// Turns an event into points using the game's settings.
enum ScoringRules {
    static func points(for kind: ScoreEventKind, runnersOn: Int = 0, settings s: GameSettings) -> Int {
        switch kind {
        case .firstBase: return 1 * s.pointsPerBase
        case .secondBase: return 2 * s.pointsPerBase
        case .thirdBase: return 3 * s.pointsPerBase
        case .homeOnHit:
            // Indoor: 4 bases' worth. Outdoor variant (0 per base): the batter
            // scores like any runner crossing home.
            return s.pointsPerBase > 0 ? 4 * s.pointsPerBase : s.runPoints
        case .runnerHome: return s.runPoints
        case .homeRun: return s.homeRunPoints + max(0, min(runnersOn, 3)) * s.runPoints
        case .batterOut, .runnerOut: return s.outPoints
        case .outAtHomeByCatcher: return s.outAtHomeByCatcherPoints
        case .adjustPlus: return 1
        case .adjustMinus: return -1
        }
    }

    static func makeEvent(_ kind: ScoreEventKind, runnersOn: Int = 0, settings: GameSettings, at date: Date = Date()) -> ScoreEvent {
        let runners = kind == .homeRun ? max(0, min(runnersOn, 3)) : 0
        return ScoreEvent(kind: kind,
                          points: points(for: kind, runnersOn: runners, settings: settings),
                          runnersOn: runners,
                          timestamp: date)
    }
}

extension Int {
    /// "+3", "−2", "0" — uses a true minus sign for legibility.
    var signedString: String {
        if self > 0 { return "+\(self)" }
        if self < 0 { return "−\(-self)" }
        return "0"
    }

    /// "12", "−5" — plain score, true minus sign.
    var scoreString: String {
        self < 0 ? "−\(-self)" : "\(self)"
    }
}
