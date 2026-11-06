import SwiftUI

/// Live scoring. iPhone: one scrolling column. iPad (regular width): scoreboard
/// and clock on the left, scoring pad on the right. A large "next half" button
/// is always pinned to the bottom.
struct LiveGameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    let newGame: () -> Void

    @State private var confirmEndGame = false
    @State private var confirmDiscard = false

    var body: some View {
        Group {
            if hSize == .regular {
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        VStack(spacing: 16) {
                            ScoreHeader(large: true)
                            ClockCard(large: true)
                            lineScoreCard
                        }
                        .padding([.leading, .vertical])
                    }
                    ScrollView {
                        VStack(spacing: 16) {
                            HalfTallyBar(large: true)
                            ScoringPad(large: true)
                        }
                        .padding([.trailing, .vertical])
                    }
                    .frame(maxWidth: 520)
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ScoreHeader(large: false)
                        ClockCard(large: false)
                        HalfTallyBar(large: false)
                        ScoringPad(large: false)
                        lineScoreCard
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { NextHalfBar() }
        .navigationTitle(store.game?.current.label ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { newGame() } label: { Label("New game…", systemImage: "plus") }
                    Button { confirmEndGame = true } label: { Label("End game now", systemImage: "flag.checkered") }
                    Divider()
                    Button(role: .destructive) { confirmDiscard = true } label: { Label("Discard game", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
}

// MARK: - Scoreboard

struct ScoreHeader: View {
    @Environment(GameStore.self) private var store
    let large: Bool

    var body: some View {
        if let g = store.game {
            HStack(spacing: 10) {
                tile(.away, g)
                VStack(spacing: 2) {
                    Text(g.current.isTop ? "TOP" : "BOT")
                        .font(.caption.weight(.heavy))
                    Text("\(g.current.inning)")
                        .font(.system(size: large ? 40 : 30, weight: .heavy, design: .rounded))
                    Text("of \(g.inningsCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: large ? 70 : 52)
                tile(.home, g)
            }
        }
    }

    private func tile(_ team: Team, _ g: Game) -> some View {
        let batting = g.current.battingTeam == team
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                if batting {
                    Image(systemName: "figure.softball").font(.caption)
                }
                Text(g.name(team))
                    .font(large ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(g.total(team).scoreString)
                .font(.system(size: large ? 72 : 52, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: g.total(team))
            Text(batting ? "AT BAT" : "FIELDING")
                .font(.caption2.weight(.heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(batting ? Theme.color(team) : Color.clear))
                .foregroundStyle(batting ? Color.black : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.color(team).opacity(batting ? 0.28 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.color(team).opacity(batting ? 1 : 0.3), lineWidth: batting ? 2 : 1)
        )
    }
}

// MARK: - Clock

struct ClockCard: View {
    @Environment(GameStore.self) private var store
    let large: Bool

    var body: some View {
        if let g = store.game {
            let status = store.clockStatus()
            let remaining = store.remaining()
            let color = Theme.clockColor(status)
            let timer = g.current.timer

            VStack(spacing: 10) {
                HStack {
                    Text(Theme.statusText(status).uppercased())
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(color)
                    Spacer()
                    Text("\(g.current.label) · \(Theme.duration(g.settings.halfInningSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(Theme.clock(remaining))
                    .font(.system(size: large ? 110 : 84, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .pulsing(status == .timeUp)

                ProgressBar(fraction: timer.progress(at: store.now), color: color)

                if status == .timeUp {
                    Text(g.isLastHalf
                         ? "\(g.current.label) is over. Enter any last scores, then End Game."
                         : "\(g.current.label) is over. Enter any last scores, then start \(g.halves[g.currentIndex + 1].label).")
                        .font(.callout.weight(.semibold))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button { store.addTime(-30) } label: {
                        Text("−30s").frame(minWidth: 56)
                    }
                    .buttonStyle(.bordered)
                    .disabled(remaining <= 0)

                    Button { store.toggleClock() } label: {
                        Label(timer.isRunning ? "Pause" : (timer.hasStarted ? "Resume" : "Start clock"),
                              systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(timer.isRunning ? Theme.warning : Theme.positive)
                    .disabled(status == .timeUp && !timer.isRunning)

                    Button { store.addTime(30) } label: {
                        Text("+30s").frame(minWidth: 56)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(status == .timeUp ? Theme.negative.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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
    let large: Bool

    var body: some View {
        if let g = store.game {
            let h = g.current
            VStack(spacing: 6) {
                Text("\(h.label) – \(g.name(h.battingTeam)) batting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.color(h.battingTeam))
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
                .font(.system(size: large ? 48 : 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(emphasised ? Theme.cardRaised : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(emphasised ? 0.6 : 0.25), lineWidth: emphasised ? 2 : 1))
    }
}

// MARK: - Next half / end game

struct NextHalfBar: View {
    @Environment(GameStore.self) private var store
    @State private var confirmEarly = false

    var body: some View {
        if let g = store.game, !g.isFinished {
            let status = store.clockStatus()
            let timeUp = status == .timeUp
            let title = g.isLastHalf ? "End Game" : "Start \(g.halves[g.currentIndex + 1].label)"
            let subtitle = g.isLastHalf ? "Locks in the final score" : "Closes \(g.current.label) scoring"

            Button {
                if timeUp { advance(g) } else { confirmEarly = true }
            } label: {
                HStack {
                    Image(systemName: g.isLastHalf ? "flag.checkered" : "arrow.right.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).opacity(0.8)
                    }
                    Spacer()
                    if timeUp {
                        Text("TIME").font(.caption.weight(.heavy))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.25)))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .frame(maxWidth: 900)
            }
            .buttonStyle(.borderedProminent)
            .tint(timeUp ? Theme.negative : Color(white: 0.3))
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .confirmationDialog(timeUp ? title : "Time isn't up yet", isPresented: $confirmEarly, titleVisibility: .visible) {
                Button(g.isLastHalf ? "End game now" : "End \(g.current.label) now") { advance(g) }
            } message: {
                Text(g.current.timer.hasStarted
                     ? "\(Theme.clock(store.remaining())) left on the clock for \(g.current.label)."
                     : "The clock hasn't been started for \(g.current.label).")
            }
        }
    }

    private func advance(_ g: Game) {
        if g.isLastHalf { store.finishGame() } else { store.startNextHalf() }
    }
}
