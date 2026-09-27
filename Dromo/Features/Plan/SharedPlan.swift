import Foundation

/// The current plan as a .json file named after it, for sharing into an AI chat to adjust, or to keep.
/// A real file, written whenever the plan changes, so the share sheet has everything it needs the moment
/// Share is tapped rather than asking the app for the data once it's open.
enum SharedPlan {
    private static let folder = URL.temporaryDirectory.appending(path: "Shared Plan")

    /// Where the plan's file is. Slashes and colons can't be in a file name: "5K Sub-25" stays, "Base 1/2" becomes "Base 1-2".
    static func url(for plan: TrainingPlan) -> URL {
        let name = plan.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return folder.appending(path: name + ".json")
    }

    /// Writes the plan's file, in place of the one for any earlier plan.
    static func save(_ plan: TrainingPlan) {
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? PlanFile.write(plan).write(to: url(for: plan), atomically: true, encoding: .utf8)
    }
}
