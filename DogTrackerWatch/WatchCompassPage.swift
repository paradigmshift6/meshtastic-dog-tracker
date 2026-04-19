import SwiftUI
import CoreLocation

/// One page of the compass — single tracker.
///
/// Shows: tracker name + connection badge / arrow / distance / fix-age
/// indicator / ping button. Re-renders every second so the "ago" label and
/// the staleness color stay live without us pushing context every tick.
struct WatchCompassPage: View {
    @Environment(WatchSession.self) private var session
    let tracker: TrackerSnapshot

    /// Drives a 1Hz re-render so the fix-age label and color tier update
    /// even when no new snapshot has arrived from the phone.
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            header
            Spacer(minLength: 0)
            arrow
            distance
            fixAgeRow
            Spacer(minLength: 0)
            pingButton
        }
        .padding(.horizontal, 8)
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: tracker.colorHex) ?? .green)
                .frame(width: 10, height: 10)
            Text(tracker.name)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            linkBadge
        }
    }

    @ViewBuilder private var linkBadge: some View {
        switch session.snapshot.linkState {
        case .connected:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.green)
        case .connecting:
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.yellow)
        case .disconnected:
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Arrow + distance

    private var arrowAngle: Double? {
        guard let user = session.snapshot.userLocation,
              let fix = tracker.lastFix else { return nil }
        let userCoord = CLLocationCoordinate2D(latitude: user.latitude, longitude: user.longitude)
        let dogCoord = CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude)
        let bearing = BearingMath.bearing(from: userCoord, to: dogCoord)
        let heading = user.trueHeading ?? 0
        return bearing - heading
    }

    private var distanceMeters: Double? {
        guard let user = session.snapshot.userLocation,
              let fix = tracker.lastFix else { return nil }
        let userCoord = CLLocationCoordinate2D(latitude: user.latitude, longitude: user.longitude)
        let dogCoord = CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude)
        return BearingMath.distance(from: userCoord, to: dogCoord)
    }

    @ViewBuilder private var arrow: some View {
        if let angle = arrowAngle {
            Image(systemName: "location.north.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color(hex: tracker.colorHex) ?? .green)
                .rotationEffect(.degrees(angle))
                .animation(.easeOut(duration: 0.3), value: angle)
        } else {
            Image(systemName: "location.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var distance: some View {
        if let meters = distanceMeters {
            Text(BearingMath.distanceString(meters, useMetric: session.snapshot.useMetric))
                .font(.system(size: 22, weight: .bold, design: .rounded))
        } else if session.snapshot.userLocation == nil {
            Text("No phone location")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("Waiting for fix")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Fix age row

    private var fixAgeRow: some View {
        let described = FixAge.describe(tracker.lastFix?.fixTime, now: now)
        return HStack(spacing: 4) {
            Circle().fill(described.tier.color).frame(width: 6, height: 6)
            Text(described.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ping button

    @ViewBuilder private var pingButton: some View {
        switch session.pingState {
        case .sending(let nodeNum) where nodeNum == tracker.nodeNum,
             .waitingForFix(let nodeNum, _) where nodeNum == tracker.nodeNum:
            Button {
                // No-op while in flight; visually disabled below.
            } label: {
                Label("Pinging…", systemImage: "hourglass")
                    .font(.caption.bold())
            }
            .controlSize(.small)
            .disabled(true)

        case .success(let nodeNum) where nodeNum == tracker.nodeNum:
            Label("Updated!", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)

        case .error(let msg):
            VStack(spacing: 2) {
                pingActionButton
                Text(msg).font(.caption2).foregroundStyle(.red).lineLimit(1)
            }

        default:
            pingActionButton
        }
    }

    private var pingActionButton: some View {
        Button {
            session.sendPing(to: tracker.nodeNum)
        } label: {
            Label("Ping", systemImage: "location.magnifyingglass")
                .font(.caption.bold())
        }
        .controlSize(.small)
        .disabled(session.snapshot.linkState != .connected || !session.isReachable)
    }
}
