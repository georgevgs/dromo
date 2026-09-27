import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Share to Dromo" for a chat's reply: leaves the plan for Dromo to open, and says so.
/// Checking and replacing happen in the app, where the preview, undo and Watch sync live.
final class ShareViewController: UIViewController {
    private var host: UIHostingController<ShareResultView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Up straight away, so the sheet isn't blank while the shared text loads.
        show(nil)
        Task {
            show(await send())
        }
    }

    private func send() async -> ShareOutcome {
        // Dromo shows up for any shared text, so only pass on what looks like a plan.
        guard let text = await sharedText(), text.contains("\"weeks\"") else { return .notAPlan }
        if PlanInbox.leave(text) {
            return .sent
        }
        return .failed
    }

    /// The first text in what was shared: an attachment, or the item's own text.
    private func sharedText() async -> String? {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    return text
                }
            }
            if let text = item.attributedContentText?.string {
                return text
            }
        }
        return nil
    }

    /// The outcome, or nil while still sending. The first call puts the view up; later ones update it.
    private func show(_ outcome: ShareOutcome?) {
        let result = ShareResultView(outcome: outcome) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        if let host {
            host.rootView = result
            return
        }
        let host = UIHostingController(rootView: result)
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
        self.host = host
    }
}

enum ShareOutcome {
    case sent, notAPlan, failed

    var title: String {
        switch self {
        case .sent: "Sent to Dromo"
        case .notAPlan: "Not a Plan"
        case .failed: "Couldn't Send"
        }
    }

    var symbol: String {
        switch self {
        case .sent: "checkmark.circle"
        case .notAPlan: "questionmark.circle"
        case .failed: "exclamationmark.circle"
        }
    }

    var message: String {
        switch self {
        case .sent: "Open Dromo to see the plan and replace your current one."
        case .notAPlan: "This doesn't look like a Dromo plan. Share the chat's whole reply, with the plan in it."
        case .failed: "Copy the reply and paste it into Dromo's New Plan instead."
        }
    }
}

private struct ShareResultView: View {
    /// nil while still sending.
    let outcome: ShareOutcome?
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let outcome {
                    ContentUnavailableView(outcome.title, systemImage: outcome.symbol, description: Text(outcome.message))
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Dromo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .disabled(outcome == nil)
                }
            }
        }
    }
}
