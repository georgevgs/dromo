import CoreTransferable
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Dromo

// The share sheet can ask for shared data while holding the main thread. Anything shared must be
// able to deliver without it, or the app freezes.

@MainActor
struct ShareTests {
    @Test func sharingThePlanNeverWaitsForTheMainThread() {
        #expect(deliversWhileMainThreadWaits(SharedPlan(plan: BundledPlan.plan), as: .json))
    }

    @Test func sharingThePromptNeverWaitsForTheMainThread() {
        #expect(deliversWhileMainThreadWaits(PlanFormat.prompt(today: .today), as: .utf8PlainText))
    }

    /// Asks for the data the way a share sheet can: blocking the main thread until it arrives.
    private func deliversWhileMainThreadWaits<T: Transferable & Sendable>(_ item: T, as type: UTType) -> Bool {
        let provider = NSItemProvider()
        provider.register(item)
        let arrived = DispatchSemaphore(value: 0)
        _ = provider.loadDataRepresentation(for: type) { data, _ in
            if data != nil {
                arrived.signal()
            }
        }
        return arrived.wait(timeout: .now() + 3) == .success
    }
}
