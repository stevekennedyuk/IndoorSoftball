import Foundation

/// Saves settings, the game in progress and finished games as small JSON files
/// in Application Support, so a game survives the app being closed.
struct Persistence: Sendable {
    let directory: URL

    static var standard: Persistence {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return Persistence(directory: base.appendingPathComponent("IndoorSoftball", isDirectory: true))
    }

    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    private var currentURL: URL { directory.appendingPathComponent("current-game.json") }
    private var historyURL: URL { directory.appendingPathComponent("history.json") }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func encode<T: Encodable>(_ value: T) -> Data? { try? encoder.encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? { try? decoder.decode(type, from: data) }

    private func write<T: Encodable>(_ value: T?, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let value {
                guard let data = Self.encode(value) else { return }
                try data.write(to: url, options: .atomic)
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Persistence write failed for \(url.lastPathComponent): \(error)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Self.decode(type, from: data)
    }

    func loadSettings() -> GameSettings { read(GameSettings.self, from: settingsURL)?.sanitized() ?? .indoor }
    func saveSettings(_ s: GameSettings) { write(s, to: settingsURL) }

    func loadCurrentGame() -> Game? { read(Game.self, from: currentURL) }
    func saveCurrentGame(_ g: Game?) { write(g, to: currentURL) }

    func loadHistory() -> [Game] { read([Game].self, from: historyURL) ?? [] }
    func saveHistory(_ h: [Game]) { write(h, to: historyURL) }
}
