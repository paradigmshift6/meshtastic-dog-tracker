import SwiftUI

@main
struct DogTrackerWatchApp: App {
    @State private var session = WatchSession()
    @State private var heading = WatchHeadingProvider()

    var body: some Scene {
        WindowGroup {
            WatchCompassScreen()
                .environment(session)
                .environment(heading)
                .onAppear {
                    session.start()
                    heading.start()
                }
        }
    }
}
