import Foundation

/// Saves each finished game as a CSV file in the app's Documents folder, which
/// the Files app shows under On My iPhone/iPad → Indoor Softball (the iOS target
/// sets UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace).
/// File names come from the game (date, time and teams), so renaming a game
/// replaces its file. Used on iPhone/iPad only.
struct ResultsArchive: Sendable {
    let directory: URL

    static var standard: ResultsArchive {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return ResultsArchive(directory: docs)
    }

    func url(for game: Game) -> URL {
        directory.appendingPathComponent(game.exportFileName)
    }

    /// Writes (or rewrites) the game's CSV file. Returns its URL.
    @discardableResult
    func save(_ game: Game) -> URL? {
        let url = url(for: game)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // UTF-8 byte-order mark so Excel shows "–" and "·" correctly; Numbers/Sheets ignore it.
            try Data(("\u{FEFF}" + game.csv).utf8).write(to: url, options: .atomic)
            return url
        } catch {
            print("ResultsArchive save failed: \(error)")
            return nil
        }
    }

    /// The game's file, creating it if it isn't there (e.g. the user deleted it in Files).
    func ensureFile(for game: Game) -> URL? {
        let url = url(for: game)
        return FileManager.default.fileExists(atPath: url.path) ? url : save(game)
    }

    func delete(_ game: Game) {
        let url = url(for: game)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
