import SwiftUI

/// Live scoring, laid out to fit the screen without scrolling.
/// - iPhone portrait: scoreboard, clock, tallies, then the +1 / −1 / HR buttons,
///   which stretch to fill the remaining height.
/// - iPad, or iPhone landscape: scoreboard + clock (+ line score on iPad) on the
///   left, tallies + buttons on the right.
/// Moving to the next half is done from the clock: once time is up its main
/// button becomes "Start Bottom 1" (or "End Game"). Ending a half early is in
/// the ⋯ menu.
struct LiveGameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    let newGame: () -> Void

    @State private var confirmEndHalf = false
    @State private var confirmEndGame = false
    @State private var confirmDiscard = false
    @State private var showScores = false

    private var isPad: Bool { hSize == .regular && vSize == .regular }
    private var twoColumns: Bool { hSize == .regular || vSize == .compact }

    var body: some View {
        Group {
            if twoColumns {
                HStack(alignment: .top, spacing: isPad ? 20 : 12) {
                    VStack(spacing: isPad ? 16 : 8) {
                        ScoreHeader(size: isPad ? .large : .compact)
                        // On iPad the clock grows to fill the column (big digits for the scorer's table).
                        ClockCard(size: isPad ? .large : .compact, expand: isPad)
                        if isPad { lineScoreCard } else { Spacer(minLength: 0) }
                    }
                    VStack(spacing: isPad ? 16 : 8) {
                        HalfTallyBar(size: isPad ? .large : .compact)
                        ScoringPad(size: isPad ? .large : .compact)
                    }
                    .frame(maxWidth: isPad ? 560 : .infinity)
                }
                .padding(isPad ? 20 : 10)
            } else {
                VStack(spacing: 10) {
                    ScoreHeader(size: .regular)
                    ClockCard(size: .regular)
                    HalfTallyBar(size: .regular)
                    ScoringPad(size: .regular)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(store.game?.current.label ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPad {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showScores = true } label: {
                        Label("Scores", systemImage: "tablecells")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
        .sheet(isPresented: $showScores) { scoresSheet }
        .confirmationDialog(endHalfTitle, isPresented: $confirmEndHalf, titleVisibility: .visible) {
            Button(endHalfButton) { advance() }
        } message: {
            Text(endHalfMessage)
        }
        .confirmationDialog("End the game now?", isPresented: $confirmEndGame, titleVisibility: .visible) {
            Button("End game – result stands") { store.finishGame() }
        } message: {
            Text("Unplayed halves will be left blank.")
        }
        .confirmationDialog("Discard this game?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { store.discardGame() }
        } message: {
            Text("It won't be saved to History.")
        }
    }

    // MARK: Menu

    private var menu: some View {
        Menu {
            if let g = store.game {
                Button { confirmEndHalf = true } label: {
                    Label(g.isLastHalf ? "End game" : "End \(g.current.label) now",
                          systemImage: g.isLastHalf ? "flag.checkered" : "forward.end")
                }
            }
            Button { showScores = true } label: { Label("Scores so far", systemImage: "tablecells") }
            Divider()
            Button { newGame() } label: { Label("New game…", systemImage: "plus") }
            Button { confirmEndGame = true } label: { Label("End game now", systemImage: "flag.checkered") }
            Button(role: .destructive) { confirmDiscard = true } label: { Label("Discard game", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var endHalfTitle: String {
        guard let g = store.game else { return "" }
        if store.clockStatus() == .timeUp { return g.isLastHalf ? "End the game?" : "Start \(nextLabel(g))?" }
        return "Time isn't up yet"
    }

    private var endHalfButton: String {
        guard let g = store.game else { return "OK" }
        return g.isLastHalf ? "End game" : "End \(g.current.label), start \(nextLabel(g))"
    }

    private var endHalfMessage: String {
        guard let g = store.game else { return "" }
        let t = g.current.timer
        let left = t.hasStarted ? "\(Theme.clock(store.remaining())) left on the clock." : "The clock hasn't been started."
        return "\(left) \(g.current.label) scores will be locked."
    }

    private func nextLabel(_ g: Game) -> String {
        g.isLastHalf ? "" : g.halves[g.currentIndex + 1].label
    }

    private func advance() {
        guard let g = store.game else { return }
        if g.isLastHalf { store.finishGame() } else { store.startNextHalf() }
    }

    // MARK: Scores

    private var lineScoreCard: some View {
        Group {
            if let g = store.game {
                LineScoreView(game: g)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
            }
        }
    }

    private var scoresSheet: some View {
        NavigationStack {
            ScrollView {
                if let g = store.game { GameSummaryView(game: g).padding() }
            }
            .navigationTitle("Scores so far")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showScores = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Sizing for the three layouts.
enum PanelSize {
    case compact   // iPhone landscape
    case regular   // iPhone portrait
    case large     // iPad
}

// MARK: - Scoreboard

struct ScoreHeader: View {
    @Environment(GameStore.self) private var store
    let size: PanelSize

    private var scoreFont: CGFloat { size == .large ? 72 : (size == .regular ? 44 : 34) }

    var body: some View {
        if let g = store.game {
            HStack(spacing: 8) {
                tile(.away, g)
                VStack(spacing: 0) {
                    Text(g.current.isTop ? "TOP" : "BOT")
                        .font(.caption2.weight(.heavy))
                    Text("\(g.current.inning)")
                        .font(.system(size: size == .large ? 40 : 26, weight: .heavy, design: .rounded))
                    Text("of \(g.inningsCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: size == .large ? 70 : 44)
                tile(.home, g)
            }
        }
    }

    private func tile(_ team: Team, _ g: Game) -> some View {
        let batting = g.current.battingTeam == team
        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                if batting { Image(systemName: "figure.softball").font(.caption) }
                Text(g.name(team))
                    .font(size == .large ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(g.total(team).scoreString)
                .font(.system(size: scoreFont, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: g.total(team))
            Text(batting ? "AT BAT" : "FIELDING")
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(batting ? Theme.color(team) : Color.clear))
                .foregroundStyle(batting ? Color.black : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size == .large ? 10 : 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.color(team).opacity(batting ? 0.28 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.color(team).opacity(batting ? 1 : 0.3), lineWidth: batting ? 2 : 1)
        )
    }
}

// MARK: - Clock

struct ClockCard: View {
    @Environment(GameStore.self) private var store
    let size: PanelSize
    /// Stretch to fill the available height (iPad left column).
    var expand = false

    private var clockFont: CGFloat { size == .large ? (expand ? 170 : 110) : (size == .regular ? 64 : 52) }

    var body: some View {
        if let g = store.game {
            let status = store.clockStatus()
            let remaining = store.remaining()
            let color = Theme.clockColor(status)
            let timer = g.current.timer
            let timeUp = status == .timeUp

            VStack(spacing: size == .large ? 10 : 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(timeUp ? "TIME – \(g.current.label) over" : Theme.statusText(status).uppercased())
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(color)
                        .lineLimit(1)
                    Spacer()
                    Text("\(g.current.label) · \(Theme.duration(g.settings.halfInningSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if expand { Spacer(minLength: 0) }
                Text(Theme.clock(remaining))
                    .font(.system(size: clockFont, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .pulsing(timeUp)
                if expand { Spacer(minLength: 0) }

                ProgressBar(fraction: timer.progress(at: store.now), color: color)

                if timeUp {
                    // The half is over: scores can still be entered until this is tapped.
                    Button {
                        if g.isLastHalf { store.finishGame() } else { store.startNextHalfAndClock() }
                    } label: {
                        Label(g.isLastHalf ? "End Game" : "Start \(g.halves[g.currentIndex + 1].label)",
                              systemImage: g.isLastHalf ? "flag.checkered" : "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.negative)
                    .controlSize(.large)
                } else {
                    HStack(spacing: 10) {
                        Button { store.addTime(-30) } label: {
                            Text("−30s").frame(minWidth: 50)
                        }
                        .buttonStyle(.bordered)

                        Button { store.toggleClock() } label: {
                            Label(timer.isRunning ? "Pause" : (timer.hasStarted ? "Resume" : "Start clock"),
                                  systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(timer.isRunning ? Theme.warning : Theme.positive)

                        Button { store.addTime(30) } label: {
                            Text("+30s").frame(minWidth: 50)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(size == .compact ? .regular : .large)
                }
            }
            .frame(maxHeight: expand ? .infinity : nil)
            .padding(size == .large ? 16 : 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(timeUp ? Theme.negative.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(color.opacity(status == .ready || status == .paused ? 0.3 : 0.9), lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: status)
        }
    }
}

// MARK: - Half tally

/// Plus, Minus and Total for the half being scored.
struct HalfTallyBar: View {
    @Environment(GameStore.self) private var store
    let size: PanelSize

    private var valueFont: CGFloat { size == .large ? 48 : (size == .regular ? 32 : 28) }

    var body: some View {
        if let g = store.game {
            let h = g.current
            VStack(spacing: 4) {
                Text("\(h.label) – \(g.name(h.battingTeam)) batting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.color(h.battingTeam))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    stat("PLUS", "+\(h.positive)", Theme.positive)
                    stat("MINUS", h.negative == 0 ? "−0" : h.negative.signedString, Theme.negative)
                    stat("TOTAL", h.net.scoreString, Theme.pointsColor(h.net), emphasised: true)
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color, emphasised: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: valueFont, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size == .large ? 10 : 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(emphasised ? Theme.cardRaised : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(emphasised ? 0.6 : 0.25), lineWidth: emphasised ? 2 : 1))
    }
}
