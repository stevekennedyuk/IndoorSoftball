import SwiftUI

struct WatchRootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        NavigationStack {
            if let g = store.game, !g.isFinished {
                TabView {
                    WatchClockPage()
                    WatchScorePage()
                    WatchTallyPage()
                    WatchControlsPage()
                }
                .tabViewStyle(.verticalPage)
            } else {
                WatchStartView()
            }
        }
    }
}

// MARK: - Start / finished

struct WatchStartView: View {
    @Environment(GameStore.self) private var store
    @State private var showNewGame = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let g = store.game, g.isFinished {
                    GameSummaryView(game: g, compact: true)
                } else {
                    Image(systemName: "figure.softball")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.positive)
                    Text("Indoor Softball").font(.headline)
                    Text("\(store.settings.innings) inn × \(Theme.duration(store.settings.halfInningSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showNewGame = true
                } label: {
                    Label("New Game", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                if store.game?.isFinished == true {
                    Button("Close", role: .cancel) { store.closeFinishedGame() }
                }
            }
        }
        .navigationTitle("Softball")
        .sheet(isPresented: $showNewGame) { WatchNewGameView() }
    }
}

struct WatchNewGameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var away = ""
    @State private var home = ""

    var body: some View {
        Form {
            Section("Teams") {
                TextField("Away", text: $away)
                TextField("Home", text: $home)
            }
            Section {
                Text("\(store.settings.innings) innings · \(Theme.duration(store.settings.halfInningSeconds)) halves")
                    .font(.footnote)
                Button {
                    store.newGame(awayName: away, homeName: home)
                    dismiss()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .listItemTint(Theme.positive)
            }
        }
        .onAppear {
            away = store.settings.awayName
            home = store.settings.homeName
        }
    }
}

struct WatchSettingsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            SettingsSections(settings: $store.settings, compact: true)
            Section("About") {
                Text("Version \(AppInfo.version)")
                Text("\(AppInfo.copyright)\nnettek.uk")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Page 1: clock

struct WatchClockPage: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let g = store.game {
            let status = store.clockStatus()
            let color = Theme.clockColor(status)
            let timer = g.current.timer
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    miniScore(.away, g)
                    miniScore(.home, g)
                }
                Text(status == .timeUp ? "TIME – \(g.current.label)" : g.current.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status == .timeUp ? Theme.negative : .secondary)
                Text(Theme.clock(store.remaining()))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .pulsing(status == .timeUp)
                ProgressBar(fraction: timer.progress(at: store.now), color: color)
                    .padding(.horizontal, 4)
                if status == .timeUp {
                    NextHalfButton()
                } else {
                    Button {
                        store.toggleClock()
                    } label: {
                        Label(timer.isRunning ? "Pause" : (timer.hasStarted ? "Resume" : "Start"),
                              systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.headline)
                    }
                    .tint(timer.isRunning ? Theme.warning : Theme.positive)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 4)
            .containerBackground(status == .timeUp ? Theme.negative.gradient : color.opacity(0.25).gradient, for: .tabView)
        }
    }

    private func miniScore(_ team: Team, _ g: Game) -> some View {
        let batting = g.current.battingTeam == team
        return VStack(spacing: 0) {
            Text(g.name(team))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Text(g.total(team).scoreString)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.color(team).opacity(batting ? 0.45 : 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.color(team), lineWidth: batting ? 1.5 : 0))
    }
}

// MARK: - Page 2: scoring

struct WatchScorePage: View {
    @Environment(GameStore.self) private var store
    @State private var askRunners = false

    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        if let g = store.game {
            let s = g.settings
            let h = g.current
            ScrollView {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(h.shortLabel).foregroundStyle(Theme.color(h.battingTeam))
                        Text("+\(h.positive)").foregroundStyle(Theme.positive)
                        Text(h.negative == 0 ? "−0" : h.negative.signedString).foregroundStyle(Theme.negative)
                        Text("= \(h.net.scoreString)").fontWeight(.bold)
                    }
                    .font(.caption.monospacedDigit())
                    if store.clockStatus() == .timeUp {
                        Text("TIME – still scoring \(h.label)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.negative)
                    }
                    LazyVGrid(columns: columns, spacing: 4) {
                        pad(.firstBase, s, Theme.positive)
                        pad(.secondBase, s, Theme.positive)
                        pad(.thirdBase, s, Theme.positive)
                        pad(.homeOnHit, s, Theme.positive)
                        pad(.runnerHome, s, Theme.positive)
                        Button { askRunners = true } label: {
                            watchLabel("HR", s.homeRunPoints.signedString + "+", Theme.warning)
                        }
                        .buttonStyle(PadButtonStyle(color: Theme.warning))
                        pad(.batterOut, s, Theme.negative, title: "Out B")
                        pad(.runnerOut, s, Theme.negative, title: "Out R")
                        pad(.outAtHomeByCatcher, s, Theme.negative, title: "Out@H")
                        Button { store.undo() } label: {
                            watchLabel("Undo", "↩︎", .secondary)
                        }
                        .buttonStyle(PadButtonStyle(color: .gray))
                        .disabled(!store.canUndo)
                    }
                }
            }
            .sheet(isPresented: $askRunners) {
                ScrollView {
                    VStack(spacing: 6) {
                        Text("Runners on base?").font(.headline)
                        ForEach(0...3, id: \.self) { n in
                            Button {
                                store.record(.homeRun, runnersOn: n)
                                askRunners = false
                            } label: {
                                HStack {
                                    Text(n == 0 ? "None" : "\(n)")
                                    Spacer()
                                    Text(ScoringRules.points(for: .homeRun, runnersOn: n, settings: s).signedString)
                                        .fontWeight(.bold)
                                }
                            }
                            .tint(Theme.warning)
                        }
                    }
                }
            }
        }
    }

    private func pad(_ kind: ScoreEventKind, _ s: GameSettings, _ color: Color, title: String? = nil) -> some View {
        Button {
            store.record(kind)
        } label: {
            watchLabel(title ?? kind.shortLabel, ScoringRules.points(for: kind, settings: s).signedString, color)
        }
        .buttonStyle(PadButtonStyle(color: color))
        .accessibilityLabel(kind.longLabel)
    }

    private func watchLabel(_ title: String, _ pts: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            Text(pts).font(.system(size: 15, weight: .heavy).monospacedDigit())
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}

// MARK: - Page 3: tallies

struct WatchTallyPage: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let g = store.game {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    LineScoreView(game: g, compact: true)
                    ForEach(1...g.inningsCount, id: \.self) { i in
                        InningCard(game: g, inning: i, compact: true)
                    }
                }
            }
        }
    }
}

// MARK: - Page 4: controls

struct WatchControlsPage: View {
    @Environment(GameStore.self) private var store
    @State private var confirmDiscard = false

    var body: some View {
        if let g = store.game {
            List {
                NextHalfButton()
                HStack {
                    Button("−30s") { store.addTime(-30) }
                        .buttonStyle(.bordered)
                    Button("+30s") { store.addTime(30) }
                        .buttonStyle(.bordered)
                }
                Button {
                    store.record(.adjustPlus)
                } label: { Label("Correction +1", systemImage: "plus") }
                Button {
                    store.record(.adjustMinus)
                } label: { Label("Correction −1", systemImage: "minus") }
                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                if !g.isLastHalf {
                    Button {
                        store.finishGame()
                    } label: { Label("End game now", systemImage: "flag.checkered") }
                }
                Button(role: .destructive) {
                    confirmDiscard = true
                } label: { Label("Discard game", systemImage: "trash") }
            }
            .confirmationDialog("Discard this game?", isPresented: $confirmDiscard) {
                Button("Discard", role: .destructive) { store.discardGame() }
            }
        }
    }
}

/// "Start Bottom 1" / "End Game" with a confirmation if time isn't up.
struct NextHalfButton: View {
    @Environment(GameStore.self) private var store
    @State private var confirm = false

    var body: some View {
        if let g = store.game, !g.isFinished {
            let timeUp = store.clockStatus() == .timeUp
            Button {
                if timeUp { advance(g) } else { confirm = true }
            } label: {
                Label(g.isLastHalf ? "End Game" : "Start \(g.halves[g.currentIndex + 1].shortLabel)",
                      systemImage: g.isLastHalf ? "flag.checkered" : "arrow.right.circle.fill")
                    .font(.headline)
            }
            .tint(timeUp ? Theme.negative : .gray)
            .buttonStyle(.borderedProminent)
            .confirmationDialog("Time isn't up – \(Theme.clock(store.remaining())) left", isPresented: $confirm) {
                Button(g.isLastHalf ? "End game" : "End \(g.current.label)") { advance(g) }
            }
        }
    }

    private func advance(_ g: Game) {
        if g.isLastHalf { store.finishGame() } else { store.startNextHalf() }
    }
}
