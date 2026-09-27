import CoreTransferable
import UniformTypeIdentifiers

/// The current plan as a .json file named after it, for sharing into an AI chat to adjust, or to keep.
///
/// Written only when the share sheet asks for it, not each time the plan screen draws its Share button.
/// Nonisolated so the writing happens off the main thread: the share sheet may be holding the main thread
/// while it waits for the data, and needing it back would freeze the app.
nonisolated struct SharedPlan: Transferable {
    let plan: TrainingPlan

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { shared in
            Data(PlanFile.write(shared.plan).utf8)
        }
        .suggestedFileName { shared in
            // Slashes and colons can't be in a file name: "5K Sub-25" stays, "Base 1/2" becomes "Base 1-2".
            shared.plan.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".json"
        }
    }
}
