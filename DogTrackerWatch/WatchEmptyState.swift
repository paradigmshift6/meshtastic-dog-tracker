import SwiftUI

/// Shown when the watch has no trackers to display — either because none
/// are assigned on the phone, the phone hasn't sent a snapshot yet, or
/// WCSession hasn't activated.
struct WatchEmptyState: View {
    let linkState: RadioLinkState
    let isActivated: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var icon: String {
        if !isActivated { return "applewatch.slash" }
        switch linkState {
        case .connected: return "pawprint"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .disconnected: return "iphone.slash"
        }
    }

    private var title: String {
        if !isActivated { return "Connecting to phone" }
        switch linkState {
        case .connected: return "No dogs assigned"
        case .connecting: return "Phone connecting"
        case .disconnected: return "Phone not connected"
        }
    }

    private var detail: String {
        if !isActivated { return "Open PawMesh on iPhone." }
        switch linkState {
        case .connected:
            return "Assign a tracker as a dog in PawMesh on your iPhone."
        case .connecting:
            return "Phone is linking to the radio."
        case .disconnected:
            return "Open PawMesh on iPhone and reconnect to your radio."
        }
    }
}
