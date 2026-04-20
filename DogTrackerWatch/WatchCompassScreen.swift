import SwiftUI

/// Top-level watch UI. Navigation root: a list of assigned dogs. Tapping
/// one pushes the full-screen compass page for that tracker.
///
/// Empty state takes over when we haven't yet received a snapshot with
/// any trackers (or when the phone is disconnected from the radio).
struct WatchCompassScreen: View {
    @Environment(WatchSession.self) private var session

    var body: some View {
        NavigationStack {
            if session.snapshot.trackers.isEmpty {
                WatchEmptyState(linkState: session.snapshot.linkState,
                                isActivated: session.isActivated)
            } else {
                WatchDogsListScreen()
            }
        }
    }
}
