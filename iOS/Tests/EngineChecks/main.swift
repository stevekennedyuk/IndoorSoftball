import Foundation

// Runs SharedTests/cases.json against the iOS engine – the same cases the
// Android engine runs in Android/shared (ScoringCasesTest.kt).
// Run with:  iOS/Tests/run-engine-checks.sh

var failures = 0
func check<T: Equatable>(_ got: T, _ want: T, _ what: String) {
    if got != want {
        failures += 1
        print("FAIL \(what)\n  expected: \(want)\n  got:      \(got)")
    }
}

func settings(_ c: [String: Any]) -> GameSettings {
    var s = GameSettings()
    s.scoring = (c["scoring"] as? String) == "outdoor" ? .outdoor : .indoor
    s.innings = c["innings"] as? Int ?? 2
    s.homeRunPoints = c["homeRunPoints"] as? Int ?? 5
    s.outAtHomeByCatcherPoints = c["outAtHomeByCatcherPoints"] as? Int ?? -2
    return s
}

MainActor.assumeIsolated {
    let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "SharedTests/cases.json"
    guard let data = FileManager.default.contents(atPath: path),
          let cases = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("Can't read \(path)")
        exit(2)
    }

    @MainActor func makeStore() -> GameStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cases-" + UUID().uuidString)
        return GameStore(persistence: Persistence(directory: dir), deviceName: "Test", startTicker: false)
    }

    @MainActor func tap(_ store: GameStore, _ tap: String) {
        let parts = tap.components(separatedBy: "x")
        let what = parts[0]
        let times = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
        for _ in 0..<times {
            switch what {
            case "+1": store.record(.adjustPlus)
            case "-1": store.record(.adjustMinus)
            case "HR": store.record(.homeRun)
            case "OC": store.record(.outAtHomeByCatcher)
            case "undo": store.undo()
            default:
                guard what.hasPrefix("HR+"), let n = Int(what.dropFirst(3)) else { fatalError("Unknown tap \(tap)") }
                store.record(.homeRun, runnersOn: n)
            }
        }
    }

    let tallies = cases["tallies"] as? [[String: Any]] ?? []
    for c in tallies {
        let name = c["name"] as? String ?? "?"
        let store = makeStore()
        store.settings = settings(c)
        store.newGame()
        for t in c["taps"] as? [String] ?? [] { tap(store, t) }
        let half = store.game!.current
        check(half.positive, c["plus"] as? Int ?? .min, "\(name): plus")
        check(half.negative, c["minus"] as? Int ?? .min, "\(name): minus")
        check(half.net, c["total"] as? Int ?? .min, "\(name): total")
    }

    let games = cases["games"] as? [[String: Any]] ?? []
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = .current
    parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
    for c in games {
        let name = c["name"] as? String ?? "?"
        let play = parser.date(from: c["playStart"] as? String ?? "")!
        let store = makeStore()
        store.settings = settings(c)
        // Set up ten minutes before play starts: the document must use the play-start time.
        store.newGame(awayName: c["away"] as? String, homeName: c["home"] as? String,
                      location: c["location"] as? String, at: play.addingTimeInterval(-600))
        store.startClock(at: play)
        for (i, taps) in (c["halves"] as? [[String]] ?? []).enumerated() {
            if i > 0 { store.startNextHalf(at: play.addingTimeInterval(Double(i) * 60)) }
            for t in taps { tap(store, t) }
        }
        store.finishGame(at: play.addingTimeInterval(1800))
        let g = store.game!
        check(g.total(.away), c["awayTotal"] as? Int ?? .min, "\(name): away total")
        check(g.total(.home), c["homeTotal"] as? Int ?? .min, "\(name): home total")
        let winner = g.winner == .away ? "away" : (g.winner == .home ? "home" : "tie")
        check(winner, c["winner"] as? String ?? "", "\(name): winner")
        check(g.exportFileName, c["fileName"] as? String ?? "", "\(name): file name")
        check(g.shareSubject, c["subject"] as? String ?? "", "\(name): subject")
        check(g.resultsDocument, c["document"] as? String ?? "", "\(name): document")
    }

    if failures == 0 {
        print("iOS engine: \(tallies.count) tally cases and \(games.count) game cases passed")
    } else {
        print("\(failures) check(s) FAILED")
        exit(1)
    }
}
