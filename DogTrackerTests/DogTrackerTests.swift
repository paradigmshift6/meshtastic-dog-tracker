import XCTest
import SwiftData
@testable import DogTracker

final class DogTrackerTests: XCTestCase {

    /// Sanity check: in-memory ModelContainer wires up cleanly with our @Model types.
    /// If a model relationship or attribute is malformed, this fails at container init.
    func testModelContainerBootstraps() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Tracker.self, Fix.self, TileRegion.self,
            configurations: config
        )

        let context = ModelContext(container)
        let tracker = Tracker(nodeNum: 0xa1b2c3d4, name: "Maple", colorHex: "#2E8B57")
        context.insert(tracker)

        let fix = Fix(
            tracker: tracker,
            latitude: 44.4280,
            longitude: -110.5885,
            fixTime: .now,
            source: .scheduled
        )
        context.insert(fix)

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tracker>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.fixes.count, 1)
        XCTAssertEqual(fetched.first?.fixes.first?.source, .scheduled)
    }
}
