import Foundation

/// Where the share extension leaves a plan for the app: a file in the app group both can read.
/// A share extension can't open its app, so the app picks the plan up the next time it comes to the front.
enum PlanInbox {
    static let appGroup = "group.eu.vagdas.sub25"

    /// nil when the app group isn't set up (its entitlement is missing).
    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "Shared plan.txt")
    }

    /// Leaves a plan's text for the app, replacing any left before. Returns whether it was saved.
    static func leave(_ text: String) -> Bool {
        guard let fileURL else { return false }
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// The plan's text left by the extension, if any, taking it out of the inbox.
    static func take() -> String? {
        guard let fileURL, let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: fileURL)
        return text
    }
}
