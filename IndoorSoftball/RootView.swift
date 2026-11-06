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
            Section("About") {
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
                Text("\(AppInfo.copyright) · nettek.uk")
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
                            GameDetailView(game: game)
                        } label: {
                            HistoryRow(game: game)
                        }
                    }
                    .onDelete { offsets in
                        store.deleteHistory(ids: Set(offsets.map { store.history[$0].id }))
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar { if !store.history.isEmpty { EditButton() } }
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
                Text(game.startedAt.formatted(date: .abbreviated, time: .shortened))
                if !game.scoredOn.isEmpty { Text("· \(game.scoredOn)") }
                if game.winner == nil && game.isFinished { Text("· tie") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
    let game: Game

    var body: some View {
        ScrollView {
            GameSummaryView(game: game)
                .padding()
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle("\(game.awayName) v \(game.homeName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: game.textReport) { Image(systemName: "square.and.arrow.up") }
        }
    }
}
