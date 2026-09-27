import CoreTransferable
import UniformTypeIdentifiers

/// The current plan as a .json file named after it, for sharing into an AI chat to adjust, or to keep.
struct SharedPlan: Transferable {
    let data: Data
    let fileName: String

    @MainActor
    init(plan: TrainingPlan) {
        // Written now, on the main thread, so sharing can hand it over without the main thread:
        // the share sheet may be holding it while it waits for the data, and asking for it back would freeze the app.
        data = Data(PlanFile.write(plan).utf8)
        // Slashes and colons can't be in a file name: "5K Sub-25" stays, "Base 1/2" becomes "Base 1-2".
        fileName = plan.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".json"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { shared in
            shared.data
        }
        .suggestedFileName { shared in
            shared.fileName
        }
    }
}
