import SwiftUI
import SwiftData

struct TileManagerScreen: View {
    @Query(sort: \TileRegion.downloadedAt, order: .reverse) private var regions: [TileRegion]
    @Environment(\.modelContext) private var modelContext
    @State private var showDownloadSheet = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Offline Tiles")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showDownloadSheet = true
                        } label: {
                            Label("Add Region", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showDownloadSheet) {
                    TileDownloadSheet()
                }
        }
    }

    @ViewBuilder private var content: some View {
        if regions.isEmpty {
            ContentUnavailableView(
                "No offline regions",
                systemImage: "square.grid.3x3.square",
                description: Text("Tap + to download USGS topo tiles for offline use.\nDo this on Wi-Fi before heading into the backcountry.")
            )
        } else {
            List {
                ForEach(regions) { region in
                    TileRegionRow(region: region)
                }
                .onDelete(perform: deleteRegions)
            }
        }
    }

    private func deleteRegions(at offsets: IndexSet) {
        for i in offsets {
            let region = regions[i]
            // Delete the MBTiles file
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("TileRegions")
            let file = dir.appendingPathComponent(region.filename)
            try? FileManager.default.removeItem(at: file)
            modelContext.delete(region)
        }
        try? modelContext.save()
    }
}

private struct TileRegionRow: View {
    let region: TileRegion

    var body: some View {
        VStack(alignment: .leading) {
            Text(region.name).font(.headline)
            Text("z\(region.minZoom)–\(region.maxZoom) · \(sizeString)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Downloaded \(region.downloadedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: region.sizeBytes, countStyle: .file)
    }
}

// MARK: - Download sheet

struct TileDownloadSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var regionName = ""
    @State private var minLat = ""
    @State private var maxLat = ""
    @State private var minLon = ""
    @State private var maxLon = ""
    @State private var minZoom = 10
    @State private var maxZoom = 15
    @State private var isDownloading = false
    @State private var progress = 0
    @State private var total = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Region") {
                    TextField("Name (e.g. Yellowstone)", text: $regionName)
                }
                Section("Bounding Box") {
                    TextField("Min Latitude", text: $minLat)
                        .keyboardType(.decimalPad)
                    TextField("Max Latitude", text: $maxLat)
                        .keyboardType(.decimalPad)
                    TextField("Min Longitude", text: $minLon)
                        .keyboardType(.decimalPad)
                    TextField("Max Longitude", text: $maxLon)
                        .keyboardType(.decimalPad)
                }
                Section("Zoom Levels") {
                    Stepper("Min zoom: \(minZoom)", value: $minZoom, in: 1...16)
                    Stepper("Max zoom: \(maxZoom)", value: $maxZoom, in: minZoom...16)
                    Text(estimatedInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isDownloading {
                    Section("Progress") {
                        ProgressView(value: Double(progress), total: Double(max(total, 1)))
                        Text("\(progress)/\(total) tiles")
                            .font(.caption.monospaced())
                    }
                }
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Download Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") { startDownload() }
                        .disabled(!canDownload)
                }
            }
        }
    }

    private var canDownload: Bool {
        !regionName.isEmpty && !isDownloading &&
        Double(minLat) != nil && Double(maxLat) != nil &&
        Double(minLon) != nil && Double(maxLon) != nil
    }

    private var estimatedInfo: String {
        guard let mnLa = Double(minLat), let mxLa = Double(maxLat),
              let mnLo = Double(minLon), let mxLo = Double(maxLon) else {
            return "Enter coordinates to see estimate"
        }
        var count = 0
        for z in minZoom...maxZoom {
            let n = 1 << z
            let xRange = tileX(lon: mnLo, zoom: z)...tileX(lon: mxLo, zoom: z)
            let yRange = tileY(lat: mxLa, zoom: z)...tileY(lat: mnLa, zoom: z)
            count += (xRange.count) * (yRange.count)
        }
        let estMB = Double(count) * 30 / 1024 // ~30 KB per tile avg
        return "~\(count) tiles, est. \(Int(estMB)) MB"
    }

    private func tileX(lon: Double, zoom: Int) -> Int {
        let n = Double(1 << zoom)
        return max(0, Int(floor((lon + 180) / 360 * n)))
    }

    private func tileY(lat: Double, zoom: Int) -> Int {
        let n = Double(1 << zoom)
        let r = lat * .pi / 180
        return max(0, Int(floor((1 - log(tan(r) + 1 / cos(r)) / .pi) / 2 * n)))
    }

    private func startDownload() {
        guard let mnLa = Double(minLat), let mxLa = Double(maxLat),
              let mnLo = Double(minLon), let mxLo = Double(maxLon) else { return }

        isDownloading = true
        errorMessage = nil

        Task {
            do {
                let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("TileRegions")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let filename = "\(regionName.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).mbtiles"
                let fileURL = dir.appendingPathComponent(filename)

                let downloader = TileDownloader()
                let size = try await downloader.download(
                    minLat: mnLa, maxLat: mxLa,
                    minLon: mnLo, maxLon: mxLo,
                    minZoom: minZoom, maxZoom: maxZoom,
                    outputURL: fileURL
                ) { done, tot in
                    Task { @MainActor in
                        progress = done
                        total = tot
                    }
                }

                let region = TileRegion(
                    name: regionName,
                    filename: filename,
                    minLatitude: mnLa, maxLatitude: mxLa,
                    minLongitude: mnLo, maxLongitude: mxLo,
                    minZoom: minZoom, maxZoom: maxZoom,
                    sizeBytes: size
                )
                modelContext.insert(region)
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDownloading = false
            }
        }
    }
}

#Preview {
    TileManagerScreen()
        .modelContainer(for: [Tracker.self, Fix.self, TileRegion.self], inMemory: true)
}
