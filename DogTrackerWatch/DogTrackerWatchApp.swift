import SwiftUI

@main
struct DogTrackerWatchApp: App {
    @State private var session = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchCompassScreen()
                .environment(session)
                .onAppear { session.start() }
        }
    }
}
