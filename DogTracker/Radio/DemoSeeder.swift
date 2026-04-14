import Foundation
import SwiftData
import OSLog

/// Seeds SwiftData with demo Tracker and Fix records so the app has data to
/// display without real Meshtastic hardware. Called once when demo mode is
/// first activated.
enum DemoSeeder {

    private static let log = Logger(subsystem: "com.levijohnson.DogTracker", category: "Demo")

    /// Check if demo data already exists — idempotent.
    static func seedIfNeeded(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        let demoNodes = DemoRadioTransport.demoDogs.map(\.nodeNum)

        // Check if we already have demo trackers
        let descriptor = FetchDescriptor<Tracker>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingNodes = Set(existing.map(\.nodeNum))
        let hasDemoData = demoNodes.allSatisfy { existingNodes.contains($0) }

        if hasDemoData {
            log.info("demo data already seeded")
            return
        }

        log.info("seeding demo data")

        // Remove any existing trackers first (clean slate for demo)
        for tracker in existing {
            context.delete(tracker)
        }

        // Create demo trackers with trail history
        for dog in DemoRadioTransport.demoDogs {
            let tracker = Tracker(
                nodeNum: dog.nodeNum,
                name: dog.longName,
                colorHex: dog.colorHex,
                assignedAt: Date().addingTimeInterval(-3600 * 2)  // "assigned 2 hours ago"
            )
            context.insert(tracker)

            // Create a trail of ~30 fixes over the past hour
            let fixCount = 30
            for i in 0..<fixCount {
                let t = Double(i)
                let age = Double(fixCount - i) * 120  // 2 minutes apart
                let angle = t * 0.3 + Double(dog.nodeNum) * 1.5
                let radius = 0.0005 + 0.0003 * sin(t * 0.1 + Double(dog.nodeNum))
                let lat = dog.baseLat + radius * sin(angle)
                let lon = dog.baseLon + radius * cos(angle)
                let alt = 2250.0 + 20 * sin(t * 0.15 + Double(dog.nodeNum))

                let fix = Fix(
                    tracker: tracker,
                    latitude: lat,
                    longitude: lon,
                    altitude: alt,
                    fixTime: Date().addingTimeInterval(-age),
                    receivedAt: Date().addingTimeInterval(-age + 2),
                    sats: Int.random(in: 8...14),
                    precisionBits: 32,
                    source: .scheduled
                )
                context.insert(fix)
            }
        }

        do {
            try context.save()
            log.info("demo data seeded: \(DemoRadioTransport.demoDogs.count) trackers with trails")
        } catch {
            log.error("failed to seed demo data: \(error.localizedDescription)")
        }
    }

    /// Remove all demo data when leaving demo mode.
    static func clearDemoData(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        let demoNodes = Set(DemoRadioTransport.demoDogs.map(\.nodeNum))

        let descriptor = FetchDescriptor<Tracker>()
        guard let trackers = try? context.fetch(descriptor) else { return }

        for tracker in trackers where demoNodes.contains(tracker.nodeNum) {
            context.delete(tracker)
        }
        try? context.save()
        log.info("demo data cleared")
    }
}
