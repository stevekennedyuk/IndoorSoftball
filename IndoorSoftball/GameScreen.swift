import SwiftUI

/// The Game tab: start screen, live scoring, or the finished-game summary.
struct GameScreen: View {
    @Environment(GameStore.self) private var store
    @State private var showNewGame = false

    var body: some View {
        Group {
            if let game = store.game {
                if game.isFinished {
                    FinishedGameView(game: game, newGame: { showNewGame = true })
                } else {
                    LiveGameView(newGame: { showNewGame = true })
                }
            } else {
                StartView(newGame: { showNewGame = true })
            }
        }
        .sheet(isPresented: $showNewGame) {
            NewGameSheet()
        }
    }
}

// MARK: - Start

private struct StartView: View {
    @Environment(GameStore.self) private var store
    let newGame: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "figure.softball")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.positive)
                    .padding(.top, 40)
                Text("Indoor Softball")
                    .font(.largeTitle.weight(.heavy))
                Text("Timed half innings · +1 / −1 / HR scoring · negative scores count")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    let s = store.settings
                    summaryRow("Innings", "\(s.innings)")
                    summaryRow("Time per half", Theme.duration(s.halfInningSeconds))
                    summaryRow("Home run", s.homeRunPoints.signedString)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .frame(maxWidth: 480)

                Button(action: newGame) {
                    Label("New Game", systemImage: "play.fill")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: 480)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }
}

// MARK: - New game

struct NewGameSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = GameSettings()
    @State private var away = ""
    @State private var home = ""

    var body: some View {
        NavigationStack {
            Form {
                if let g = store.game, !g.isFinished {
                    Section {
                        Label("Starting a new game abandons the game in progress (\(g.awayName) v \(g.homeName)).",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)
                            .font(.footnote)
                    }
                }
                TeamNameSection(away: $away, home: $home)
                SettingsSections(settings: $draft)
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        store.settings = draft
                        store.newGame(awayName: away, homeName: home)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                draft = store.settings
                away = store.settings.awayName
                home = store.settings.homeName
            }
        }
    }
}

// MARK: - Finished

private struct FinishedGameView: View {
    @Environment(GameStore.self) private var store
    let game: Game
    let newGame: () -> Void
    @State private var sender = ResultsSender()
    @State private var renaming = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GameSummaryView(game: game)
                Button {
                    sender.email(game, to: store.settings.resultsEmail)
                } label: {
                    Label("Email results", systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.away)
                .controlSize(.large)
                Text("Saved as \"\(game.exportFileName)\" in Files → On My \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") → Indoor Softball.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: newGame) {
                    Label("New Game", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Final")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ResultsMenu(game: game, sender: sender, renaming: $renaming)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { store.closeFinishedGame() }
            }
        }
        .resultsSheets(sender)
        .renameTeamsAlert(game: game, isPresented: $renaming)
    }
}

/// ⋯ menu for a finished game: email, share the file, change team names.
struct ResultsMenu: View {
    @Environment(GameStore.self) private var store
    let game: Game
    let sender: ResultsSender
    @Binding var renaming: Bool

    var body: some View {
        Menu {
            Button { sender.email(game, to: store.settings.resultsEmail) } label: {
                Label("Email results", systemImage: "envelope")
            }
            Button { sender.shareFile(game) } label: {
                Label("Share results file…", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button { renaming = true } label: {
                Label("Edit team names…", systemImage: "pencil")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share results")
    }
}
