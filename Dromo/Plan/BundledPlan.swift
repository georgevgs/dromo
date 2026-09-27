import Foundation

/// The plan Dromo starts with until one is imported: the Athens 5K, kept as a plan file (`BundledPlan.json`)
/// in the same format as any import.
enum BundledPlan {
    static let plan: TrainingPlan = {
        guard let url = Bundle.main.url(forResource: "BundledPlan", withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { fatalError("BundledPlan.json is missing from the app bundle.") }
        do throws(PlanFile.Problems) {
            return try PlanFile.read(text)
        } catch {
            fatalError("BundledPlan.json doesn't read: \(error.messages)")
        }
    }()
}
