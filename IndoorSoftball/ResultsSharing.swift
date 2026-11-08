import SwiftUI
import MessageUI

/// Sends a game's results. "Email results" opens Apple Mail's composer with the
/// subject, a readable summary and the CSV attached, addressed to the "Send
/// results to" setting if set. If Mail isn't set up on the device (common, and
/// usual on review devices), it falls back to the share sheet with the same
/// file and text, so the button always does something.
@MainActor
@Observable
final class ResultsSender {
    var mail: MailDraft?
    var share: ShareItems?

    func email(_ game: Game, to address: String) {
        guard let url = ResultsArchive.standard.ensureFile(for: game),
              let data = try? Data(contentsOf: url) else { return }
        if MFMailComposeViewController.canSendMail() {
            mail = MailDraft(to: address.isEmpty ? [] : [address],
                             subject: game.emailSubject,
                             body: game.emailBody,
                             attachment: data,
                             fileName: game.exportFileName)
        } else {
            share = ShareItems(items: [game.emailBody, url], subject: game.emailSubject)
        }
    }

    func shareFile(_ game: Game) {
        guard let url = ResultsArchive.standard.ensureFile(for: game) else { return }
        share = ShareItems(items: [url], subject: game.emailSubject)
    }
}

struct MailDraft: Identifiable {
    let id = UUID()
    var to: [String]
    var subject: String
    var body: String
    var attachment: Data
    var fileName: String
}

struct ShareItems: Identifiable {
    let id = UUID()
    var items: [Any]
    var subject: String
}

extension View {
    /// Attaches the mail composer and share sheet driven by a ResultsSender.
    func resultsSheets(_ sender: ResultsSender) -> some View {
        let b = Bindable(sender)
        return self
            .sheet(item: b.mail) { draft in
                MailComposer(draft: draft) { sender.mail = nil }
                    .ignoresSafeArea()
            }
            .sheet(item: b.share) { items in
                ActivityView(items: items.items, subject: items.subject) { sender.share = nil }
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
    }
}

// MARK: - Mail composer

struct MailComposer: UIViewControllerRepresentable {
    let draft: MailDraft
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(draft.to)
        vc.setSubject(draft.subject)
        vc.setMessageBody(draft.body, isHTML: false)
        vc.addAttachmentData(draft.attachment, mimeType: "text/csv", fileName: draft.fileName)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onDone()
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

// MARK: - Rename teams

/// "Team names" alert used on the final screen and in History.
struct RenameTeamsModifier: ViewModifier {
    @Environment(GameStore.self) private var store
    let game: Game
    @Binding var isPresented: Bool
    @State private var away = ""
    @State private var home = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shown in
                if shown { away = game.awayName; home = game.homeName }
            }
            .alert("Team names", isPresented: $isPresented) {
                TextField("Away team", text: $away)
                TextField("Home team", text: $home)
                Button("Save") { store.renameTeams(gameID: game.id, away: away, home: home) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The saved results file is renamed to match.")
            }
    }
}

extension View {
    func renameTeamsAlert(game: Game, isPresented: Binding<Bool>) -> some View {
        modifier(RenameTeamsModifier(game: game, isPresented: isPresented))
    }
}
