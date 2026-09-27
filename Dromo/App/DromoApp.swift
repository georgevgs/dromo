import SwiftUI

@main
struct DromoApp: App {
    @State private var store = PlanStore()
    @State private var watch = WatchSchedule()

    var body: some Scene {
        WindowGroup {
            PlanView()
                .environment(store)
                .environment(watch)
                .environment(\.paceScale, store.plan.paceScale)
        }
    }
}
