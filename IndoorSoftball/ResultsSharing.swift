import SwiftUI

/// Shares a game's results through the standard share sheet: the results document plus a
/// readable summary, with a subject line for apps that use one (Mail, Gmail,
/// Outlook…). Messages, WhatsApp, AirDrop, Save to Files and so on all work.
@MainActor
@Observable
final class ResultsSender {
    var sheet: ShareItems?

    func share(_ game: Game) {
        guard let url = ResultsArchive.standard.ensureFile(for: game) else { return }
        sheet = ShareItems(items: [game.shareMessage, url], subject: game.shareSubject)
    }
}

struct ShareItems: Identifiable {
    let id = UUID()
    var items: [Any]
    var subject: String
}

extension View {
    /// Attaches the share sheet driven by a ResultsSender.
    func resultsSheets(_ sender: ResultsSender) -> some View {
        let b = Bindable(sender)
        return self.sheet(item: b.sheet) { items in
            ActivityView(items: items.items, subject: items.subject) { sender.sheet = nil }
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }
}

// MARK: - Share sheet

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let subject: String
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = SubjectItemSource(subject: subject, first: items.first)
        let activityItems: [Any] = [source] + Array(items.dropFirst())
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onDone() }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Gives Mail (and other apps that support it) a subject line when sharing.
final class SubjectItemSource: NSObject, UIActivityItemSource {
    let subject: String
    let first: Any?
    init(subject: String, first: Any?) { self.subject = subject; self.first = first }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        first ?? ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        first
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        subject
    }
}

// MARK: - Game details (teams + location)

/// "Game details" alert used on the final screen and in History.
struct GameDetailsModifier: ViewModifier {
    @Environment(GameStore.self) private var store
    let game: Game
    @Binding var isPresented: Bool
    @State private var away = ""
    @State private var home = ""
    @State private var location = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shown in
                if shown {
                    away = game.awayName
                    home = game.homeName
                    location = game.location ?? ""
                }
            }
            .alert("Game details", isPresented: $isPresented) {
                TextField("Home team", text: $home)
                TextField("Away team", text: $away)
                TextField("Location", text: $location)
                Button("Save") {
                    store.updateDetails(gameID: game.id, away: away, home: home, location: location)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The saved results file is renamed to match.")
            }
    }
}

extension View {
    func gameDetailsAlert(game: Game, isPresented: Binding<Bool>) -> some View {
        modifier(GameDetailsModifier(game: game, isPresented: isPresented))
    }
}
