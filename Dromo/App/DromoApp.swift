import SwiftUI

@main
struct DromoApp: App {
    @State private var store = PlanStore()
    @State private var watch = WatchSchedule()

    init() {
        Theme.styleNavigationTitles()
    }

    var body: some Scene {
        WindowGroup {
            PlanView()
                .environment(store)
                .environment(watch)
        }
    }
}
