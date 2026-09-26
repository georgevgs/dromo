import SwiftUI

@main
struct Sub25App: App {
    @State private var store = PlanStore()
    @State private var watch = WatchSchedule()

    var body: some Scene {
        WindowGroup {
            PlanView()
                .environment(store)
                .environment(watch)
        }
    }
}
