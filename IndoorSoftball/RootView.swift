import SwiftUI

struct RootView: View {
    @State private var tab = Tab.game

    enum Tab: Hashable { case game, history, settings }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { GameScreen() }
                .tabItem { Label("Game", systemImage: "sportscourt.fill") }
                .tag(Tab.game)
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet.rectangle.portrait") }
                .tag(Tab.history)
            NavigationStack { SettingsScreen() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
    }
}

// MARK: - Settings tab

struct SettingsScreen: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            if let g = store.game, !g.isFinished {
                Section {
                    Label("Changes apply from the next new game. The game in progress keeps the settings it started with.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            SettingsSections(settings: $store.settings)
            Section {
                Label("Saved in Files → On My iPhone/iPad → Indoor Softball", systemImage: "folder")
                    .font(.footnote)
            } header: {
                Text("Results")
            } footer: {
                Text("Every finished game is saved as a spreadsheet (CSV) file named home-away-location-date & time. Use Share results on the final screen or in History to send it.")
            }
            Section("About") {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Indoor Softball", systemImage: "info.circle")
                }
                LabeledContent("Version", value: AppInfo.version)
                Link(destination: AppInfo.supportURL) {
                    Label("Help & support", systemImage: "questionmark.circle")
                }
                Link(destination: AppInfo.privacyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
                Link(destination: AppInfo.feedbackMailURL) {
                    Label("Email feedback", systemImage: "envelope")
                }
                Text("Developed by \(AppInfo.developer) · \(AppInfo.copyright)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reset everything to indoor defaults", role: .destructive) {
                    let names = (store.settings.awayName, store.settings.homeName)
                    var s = GameSettings.indoor  // 2 innings, 5:00 halves, HR +5
                    s.awayName = names.0
                    s.homeName = names.1
                    store.settings = s
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - History tab

struct HistoryView: View {
    @Environment(GameStore.self) private var store
    @State private var pendingDelete: Set<UUID> = []
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView("No games yet",
                                       systemImage: "sportscourt",
                                       description: Text("Finished games — from this device or your Apple Watch — appear here."))
            } else {
                List {
                    ForEach(store.history) { game in
                        NavigationLink {
                            GameDetailView(gameID: game.id)
                        } label: {
                            HistoryRow(game: game)
                        }
                    }
                    .onDelete { offsets in
                        pendingDelete = Set(offsets.map { store.history[$0].id })
                        confirmDelete = true
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar { if !store.history.isEmpty { EditButton() } }
        .confirmationDialog(pendingDelete.count == 1 ? "Delete this game?" : "Delete \(pendingDelete.count) games?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete game and results file", role: .destructive) {
                store.deleteHistory(ids: pendingDelete, deleteFiles: true)
                pendingDelete = []
            }
            Button("Delete from History, keep file") {
                store.deleteHistory(ids: pendingDelete, deleteFiles: false)
                pendingDelete = []
            }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: {
            Text("Results files are in Files → On My iPhone/iPad → Indoor Softball.")
        }
    }
}

private struct HistoryRow: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                teamScore(.away)
                Text("–").foregroundStyle(.secondary)
                teamScore(.home)
            }
            .font(.headline)
            HStack(spacing: 6) {
                Text(game.playStart.formatted(date: .abbreviated, time: .shortened))
                if let loc = game.location { Text("· \(loc)").lineLimit(1) }
                if !game.scoredOn.isEmpty && !game.isFromWatch { Text("· \(game.scoredOn)") }
                if game.winner == nil && game.isFinished { Text("· tie") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if game.isFromWatch {
                Label(game.needsDetails ? "Scored on Watch · tap to add teams & location" : "Scored on Watch",
                      systemImage: "applewatch")
                    .font(.caption.weight(game.needsDetails ? .semibold : .regular))
                    .foregroundStyle(game.needsDetails ? Theme.warning : .secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func teamScore(_ team: Team) -> some View {
        HStack(spacing: 4) {
            if game.winner == team { Image(systemName: "trophy.fill").font(.caption).foregroundStyle(Theme.color(team)) }
            Text(game.name(team)).lineLimit(1)
            Text(game.total(team).scoreString)
                .monospacedDigit()
                .foregroundStyle(Theme.color(team))
        }
    }
}

struct GameDetailView: View {
    @Environment(GameStore.self) private var store
    let gameID: UUID
    @State private var sender = ResultsSender()
    @State private var renaming = false

    var body: some View {
        if let game = store.history.first(where: { $0.id == gameID }) {
            ScrollView {
                VStack(spacing: 16) {
                    if game.isFromWatch {
                        Button {
                            renaming = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applewatch")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.needsDetails ? "Add team names & location" : "Edit teams & location")
                                        .font(.headline)
                                    Text("Scored on Apple Watch. The results file is renamed to match.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill").font(.title2)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(game.needsDetails ? Theme.warning.opacity(0.18) : Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(game.needsDetails ? Theme.warning : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(game.needsDetails ? Theme.warning : .primary)
                    }
                    GameSummaryView(game: game)
                    Button {
                        sender.share(game)
                    } label: {
                        Label("Share results", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.away)
                    .controlSize(.large)
                }
                .padding()
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("\(game.awayName) v \(game.homeName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ResultsMenu(game: game, sender: sender, renaming: $renaming)
                }
            }
            .resultsSheets(sender)
            .gameDetailsAlert(game: game, isPresented: $renaming)
        } else {
            ContentUnavailableView("Game deleted", systemImage: "trash")
        }
    }
}
