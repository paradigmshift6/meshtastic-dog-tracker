import SwiftUI

/// Top-level watch UI. One swipeable page per tracker, plus an empty-state
/// page if the phone hasn't sent any trackers yet.
struct WatchCompassScreen: View {
    @Environment(WatchSession.self) private var session
    @State private var selection: UInt32 = 0

    var body: some View {
        Group {
            if session.snapshot.trackers.isEmpty {
                WatchEmptyState(linkState: session.snapshot.linkState,
                                isActivated: session.isActivated)
            } else {
                TabView(selection: $selection) {
                    ForEach(session.snapshot.trackers) { tracker in
                        WatchCompassPage(tracker: tracker)
                            .tag(tracker.nodeNum)
                    }
                }
                .tabViewStyle(.verticalPage)
                .onAppear {
                    if !session.snapshot.trackers.contains(where: { $0.nodeNum == selection }) {
                        selection = session.snapshot.trackers.first?.nodeNum ?? 0
                    }
                }
                .onChange(of: session.snapshot.trackers.map(\.nodeNum)) { _, ids in
                    if !ids.contains(selection), let first = ids.first {
                        selection = first
                    }
                }
            }
        }
    }
}
