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
                    Text("\(store.settings.scoring.title) · \(store.settings.innings) inn × \(Theme.duration(store.settings.halfInningSeconds))")
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

/// New game on the Watch: always Away v Home (rename it later in History on the
/// iPhone, which also renames the saved results file).
struct WatchNewGameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Away").foregroundStyle(Theme.away)
                    Text("v").foregroundStyle(.secondary)
                    Text("Home").foregroundStyle(Theme.home)
                }
                .font(.headline)
                Toggle("Outdoor scoring", isOn: Binding(
                    get: { store.settings.scoring == .outdoor },
                    set: { store.settings.scoring = $0 ? .outdoor : .indoor }))
                Text("\(store.settings.scoring.title) · \(store.settings.innings) innings · \(Theme.duration(store.settings.halfInningSeconds)) halves")
                    .font(.footnote)
                Button {
                    store.newGame(awayName: "Away", homeName: "Home", rememberNames: false)
                    dismiss()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .listItemTint(Theme.positive)
            } footer: {
                Text("Add team names afterwards in History on your iPhone.")
            }
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
                NavigationLink {
                    AboutView(compact: true)
                } label: {
                    Label("About", systemImage: "info.circle")
                }
                Text("Version \(AppInfo.version)")
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

    var body: some View {
        if let g = store.game {
            let h = g.current
            VStack(spacing: 4) {
                let outdoor = g.settings.scoring == .outdoor
                HStack(spacing: 4) {
                    if outdoor {
                        tally("Runs \(h.net.scoreString)", Theme.pointsColor(h.net), boxed: true)
                    } else {
                        tally("+\(h.positive)", Theme.positive)
                        tally(h.negative == 0 ? "−0" : h.negative.signedString, Theme.negative)
                        tally(h.net.scoreString, Theme.pointsColor(h.net), boxed: true)
                    }
                }
                if store.clockStatus() == .timeUp {
                    Text("TIME – still scoring \(h.shortLabel)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.negative)
                }
                if outdoor {
                    // Outdoor: +1 run, and a home run with 1–3 runners on (2–4 runs).
                    HStack(spacing: 4) {
                        big("+1", Theme.positive) { store.record(.adjustPlus) }
                        undoButton
                    }
                    HStack(spacing: 4) {
                        ForEach(1...3, id: \.self) { n in
                            big("HR+\(n)", Theme.warning, size: 18) { store.record(.homeRun, runnersOn: n) }
                                .accessibilityLabel("Home run plus \(n), \(n + 1) runs")
                        }
                    }
                    .frame(height: 44)
                } else {
                    HStack(spacing: 4) {
                        big("+1", Theme.positive) { store.record(.adjustPlus) }
                        big("−1", Theme.negative) { store.record(.adjustMinus) }
                    }
                    HStack(spacing: 4) {
                        big("HR \(g.settings.homeRunPoints.signedString)", Theme.warning, size: 20) { store.record(.homeRun) }
                            .accessibilityLabel("Home run")
                        big("OC \(g.settings.outAtHomeByCatcherPoints.signedString)", Theme.negative, size: 20) {
                            store.record(.outAtHomeByCatcher)
                        }
                        .accessibilityLabel("Out by catcher at home")
                        undoButton
                    }
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var undoButton: some View {
        Button { store.undo() } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadButtonStyle(color: .gray))
        .frame(width: 36)
        .disabled(!store.canUndo)
        .accessibilityLabel("Undo last")
    }

    private func tally(_ value: String, _ color: Color, boxed: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6).fill(boxed ? Color.white.opacity(0.12) : Color.clear))
    }

    private func big(_ title: String, _ color: Color, size: CGFloat = 34, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadButtonStyle(color: color))
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
                if timeUp {
                    if g.isLastHalf { store.finishGame() } else { store.startNextHalfAndClock() }
                } else {
                    confirm = true
                }
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
