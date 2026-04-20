import SwiftUI
import WidgetKit

/// Renders the three watchOS widget families we support:
///   - accessoryCircular (Modular/Meridian corner)
///   - accessoryRectangular (Infograph Modular, Siri watch face)
///   - accessoryInline (smart stack single-line text)
///
/// Each family shows distance to the closest dog plus a directional
/// indicator. The arrow is anchored to true north (with a small "N"
/// marker so the user knows it isn't tracking their orientation) — the
/// user mentally translates "the dog is northeast." This is reliable
/// because complications don't have access to live heading data; an
/// orientation-relative arrow would silently lie whenever the user
/// rotated.
///
/// Tapping any family deep-links to the watch app's live compass page
/// for that dog via `pawmesh://dog/<nodeNum>`.
struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:      inline
        default: Text("—")
        }
    }

    // MARK: - Circular

    private var circular: some View {
        Group {
            if let closest = entry.closest, let meters = entry.closestMeters {
                let tier = FixAge.describe(closest.lastFix?.fixTime, now: entry.date).tier
                ZStack {
                    AccessoryWidgetBackground()
                    compassRose(arrowColor: tier.color, size: 28)
                    VStack {
                        Spacer()
                        Text(BearingMath.distanceString(meters,
                                                        useMetric: entry.snapshot.useMetric))
                            .font(.caption2.monospaced().bold())
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 2)
                }
                .widgetURL(deepLink(for: closest.nodeNum))
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "pawprint")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Rectangular

    private var rectangular: some View {
        Group {
            if entry.snapshot.trackers.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PawMesh").font(.headline)
                    Text("No dogs").font(.caption2).foregroundStyle(.secondary)
                }
            } else if let closest = entry.closest, let meters = entry.closestMeters {
                let described = FixAge.describe(closest.lastFix?.fixTime, now: entry.date)
                HStack(spacing: 8) {
                    compassRose(arrowColor: Color(hex: closest.colorHex) ?? .green,
                                size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(closest.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(BearingMath.distanceString(meters,
                                                        useMetric: entry.snapshot.useMetric))
                            .font(.caption.monospaced())
                        HStack(spacing: 3) {
                            Circle().fill(described.tier.color).frame(width: 5, height: 5)
                            Text(described.text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Waiting for fix")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(entry.closest.map { deepLink(for: $0.nodeNum) } ?? rootDeepLink)
    }

    // MARK: - Inline

    private var inline: some View {
        Group {
            if let closest = entry.closest, let meters = entry.closestMeters {
                // Inline can't render a rotated SwiftUI shape, so we use
                // a cardinal-direction letter as a textual proxy.
                let cardinal = entry.closestBearing.map(Self.cardinal(for:)) ?? ""
                let pieces = [
                    cardinal.isEmpty ? nil : cardinal,
                    BearingMath.distanceString(meters, useMetric: entry.snapshot.useMetric),
                    closest.name,
                ].compactMap { $0 }
                Text(pieces.joined(separator: " · "))
            } else {
                Text("PawMesh")
            }
        }
        .widgetURL(entry.closest.map { deepLink(for: $0.nodeNum) } ?? rootDeepLink)
    }

    // MARK: - Compass rose

    /// Compact compass: a small "N" tick at the top of an invisible circle,
    /// and an arrow rotated to the absolute bearing toward the dog. If we
    /// don't have a bearing yet, falls back to a paw print so the
    /// complication never looks broken.
    @ViewBuilder
    private func compassRose(arrowColor: Color, size: CGFloat) -> some View {
        ZStack {
            // North marker — small "N" pinned to the top of the rose so
            // the user knows the arrow is anchored to true north.
            VStack(spacing: 0) {
                Text("N")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(width: size, height: size)

            if let bearing = entry.closestBearing {
                Image(systemName: "location.north.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
                    .foregroundStyle(arrowColor)
                    .rotationEffect(.degrees(bearing))
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundStyle(arrowColor)
            }
        }
        .frame(width: size, height: size)
    }

    /// 8-point cardinal label (N, NE, E, SE, S, SW, W, NW) for a 0..360
    /// bearing.
    private static func cardinal(for bearing: Double) -> String {
        let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = ((bearing.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let idx = Int((normalized + 22.5) / 45) % 8
        return labels[idx]
    }

    // MARK: - Deep links

    /// The watch app's URL handler watches for `pawmesh://dog/<nodeNum>`
    /// and navigates straight to that tracker's compass page.
    private func deepLink(for nodeNum: UInt32) -> URL {
        URL(string: "pawmesh://dog/\(nodeNum)")!
    }

    private var rootDeepLink: URL { URL(string: "pawmesh://")! }
}
