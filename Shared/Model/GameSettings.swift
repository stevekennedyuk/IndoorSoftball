import Foundation

/// Rule and timing settings for a game.
///
/// Settings are edited in the Settings screen (or the New Game sheet) and are
/// remembered between launches, so they carry on from game to game until
/// changed. Each game takes a snapshot of them when it starts, so changing a
/// setting never alters a game already in progress.
struct GameSettings: Codable, Equatable, Sendable {
    /// Full innings (Away bats + Home bats = 1 inning).
    var innings: Int = 2
    /// Length of each half inning, in seconds (30-second steps).
    var halfInningSeconds: Int = 300
    /// Points the batter earns per base reached off the bat (0 = outdoor variant).
    var pointsPerBase: Int = 1
    /// Points for a home run off the back wall (outdoor variant: 4).
    var homeRunPoints: Int = 5
    /// Points for each runner crossing home plate (also each runner on base during a home run).
    var runPoints: Int = 1
    /// Points for a batter or runner being put out (normally negative).
    var outPoints: Int = -1
    /// Points for a runner put out at home by the catcher (normally negative).
    var outAtHomeByCatcherPoints: Int = -2
    /// Seconds remaining at which the "time nearly up" warning fires (0 = off).
    var warningSeconds: Int = 60
    /// Last-used team names, offered again for the next game.
    var awayName: String = "Away"
    var homeName: String = "Home"
    /// Last-used location (venue), offered again for the next game.
    var location: String = ""

    // MARK: Limits used by steppers

    static let inningsRange = 1...9
    static let halfInningRange = 30...1800        // 30 s to 30 min
    static let halfInningStep = 30
    static let pointsPerBaseRange = 0...5
    static let homeRunRange = 0...20
    static let runPointsRange = 0...5
    static let outRange = -5...0
    static let warningRange = 0...300

    // MARK: Presets

    /// Standard indoor rules (the defaults).
    static let indoor = GameSettings()

    /// Outdoor-style scoring: no points per base, 4 for a home run.
    static var outdoorVariant: GameSettings {
        var s = GameSettings()
        s.pointsPerBase = 0
        s.homeRunPoints = 4
        return s
    }

    /// Copies only the scoring rules from `other` (keeps time, innings and names).
    mutating func applyScoring(from other: GameSettings) {
        pointsPerBase = other.pointsPerBase
        homeRunPoints = other.homeRunPoints
        runPoints = other.runPoints
        outPoints = other.outPoints
        outAtHomeByCatcherPoints = other.outAtHomeByCatcherPoints
    }

    var halvesCount: Int { innings * 2 }

    // MARK: Codable (tolerant of missing keys so older saved data still loads)

    enum CodingKeys: String, CodingKey {
        case innings, halfInningSeconds, pointsPerBase, homeRunPoints, runPoints
        case outPoints, outAtHomeByCatcherPoints, warningSeconds, awayName, homeName, location
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GameSettings.indoor
        innings = try c.decodeIfPresent(Int.self, forKey: .innings) ?? d.innings
        halfInningSeconds = try c.decodeIfPresent(Int.self, forKey: .halfInningSeconds) ?? d.halfInningSeconds
        pointsPerBase = try c.decodeIfPresent(Int.self, forKey: .pointsPerBase) ?? d.pointsPerBase
        homeRunPoints = try c.decodeIfPresent(Int.self, forKey: .homeRunPoints) ?? d.homeRunPoints
        runPoints = try c.decodeIfPresent(Int.self, forKey: .runPoints) ?? d.runPoints
        outPoints = try c.decodeIfPresent(Int.self, forKey: .outPoints) ?? d.outPoints
        outAtHomeByCatcherPoints = try c.decodeIfPresent(Int.self, forKey: .outAtHomeByCatcherPoints) ?? d.outAtHomeByCatcherPoints
        warningSeconds = try c.decodeIfPresent(Int.self, forKey: .warningSeconds) ?? d.warningSeconds
        awayName = try c.decodeIfPresent(String.self, forKey: .awayName) ?? d.awayName
        homeName = try c.decodeIfPresent(String.self, forKey: .homeName) ?? d.homeName
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? d.location
    }

    /// Clamps every value into its allowed range.
    func sanitized() -> GameSettings {
        var s = self
        s.innings = s.innings.clamped(to: Self.inningsRange)
        let step = Self.halfInningStep
        s.halfInningSeconds = ((s.halfInningSeconds + step / 2) / step * step).clamped(to: Self.halfInningRange)
        s.pointsPerBase = s.pointsPerBase.clamped(to: Self.pointsPerBaseRange)
        s.homeRunPoints = s.homeRunPoints.clamped(to: Self.homeRunRange)
        s.runPoints = s.runPoints.clamped(to: Self.runPointsRange)
        s.outPoints = s.outPoints.clamped(to: Self.outRange)
        s.outAtHomeByCatcherPoints = s.outAtHomeByCatcherPoints.clamped(to: Self.outRange)
        s.warningSeconds = s.warningSeconds.clamped(to: Self.warningRange)
        s.location = s.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
