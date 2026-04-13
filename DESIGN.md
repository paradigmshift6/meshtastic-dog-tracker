# Meshtastic Dog Tracker — Design Doc

**Status:** Draft v1
**Target:** iOS 17+, native Swift/SwiftUI, App Store distribution
**Author context:** Personal project for tracking off-leash dogs in remote (no cell) areas using Meshtastic LoRa trackers running stock firmware.

---

## 1. Goals

1. Show up to **3 dog trackers** on a topographic map alongside the user's own location.
2. **Compass view**: large arrow pointing toward a selected dog with distance and "age of fix" readout.
3. **One-tap "Ping"**: request an immediate position update from a tracker out-of-band of its normal interval.
4. **Fully offline-capable**: pre-downloaded topo tiles, no cloud services on the critical path.
5. Ship to the App Store.

### Non-goals (v1)
- Geofencing / leave-zone alerts (v2 candidate).
- Multi-user sharing (v2 candidate).
- Android.
- Anything that requires modifying the tracker firmware.

---

## 2. System Architecture

```
┌────────────────────┐  LoRa   ┌──────────────────┐  BLE   ┌──────────────────┐
│ Dog tracker node   │ ──────► │ User's "handheld"│ ─────► │ iPhone app       │
│ (stock Meshtastic, │ ◄────── │ Meshtastic node  │ ◄───── │ (this project)   │
│ position module)   │  mesh   │ (paired to phone)│        │                  │
└────────────────────┘         └──────────────────┘        └──────────────────┘
```

**Critical implication:** the iPhone never talks to the dog's tracker directly. It talks to a *companion* Meshtastic node carried by the user, which relays mesh traffic over BLE. Any tracker in LoRa range (directly or via mesh hops) is reachable.

### Layers inside the app

| Layer | Responsibility | Key types |
|---|---|---|
| **BLE transport** | CoreBluetooth: scan, connect, read FROMRADIO, write TORADIO, subscribe to FROMNUM notifications, reconnect on drop. | `BLEManager`, `MeshtasticPeripheral` |
| **Protocol** | Encode/decode Meshtastic protobufs (`FromRadio`, `ToRadio`, `MeshPacket`, `Position`, `NodeInfo`, `User`). | Generated SwiftProtobuf code from `.proto` files |
| **Mesh service** | Manages local NodeDB cache, packet ID allocation, pending request tracking, ack/response correlation. | `MeshService`, `NodeDB`, `PendingRequest` |
| **Domain** | Tracker assignments (which node IDs are "dogs"), names, colors, position history. | `Tracker`, `Fix`, `TrackerStore` |
| **Persistence** | SwiftData (iOS 17+) for trackers, fixes, settings. Files for MBTiles. | `@Model` types |
| **Map / tiles** | MapLibre Native iOS, MBTiles raster source, region downloader. | `MapView`, `TileRegionManager` |
| **UI** | SwiftUI views: Map, Compass, Trackers list, Tile manager, Settings. | |

---

## 3. Meshtastic Protocol Details

These are the load-bearing facts the implementation depends on. All from stock firmware, no custom changes.

### 3.1 BLE service

- **Service UUID:** `6ba1b218-15a8-461f-9fa8-5dcae273eafd`
- **TORADIO** (`f75c76d2-129e-4dad-a1dd-7866124401e7`) — write: serialized `ToRadio` protobuf.
- **FROMRADIO** (`2c55e69e-4993-11ed-b878-0242ac120002`) — read: serialized `FromRadio` protobuf. Read repeatedly until empty.
- **FROMNUM** (`ed9da18c-a800-4f66-a670-aa7547e34453`) — notify: a uint32 counter; increments when new FROMRADIO data is available. Subscribe and read FROMRADIO each time it ticks.

### 3.2 Session bring-up

1. Connect to peripheral, discover services/characteristics.
2. Subscribe to FROMNUM notifications.
3. Write a `ToRadio { want_config_id: <random u32> }` to TORADIO.
4. Drain FROMRADIO until you receive a `FromRadio.config_complete_id` matching the request.
5. During the drain, the radio sends `MyNodeInfo`, `NodeInfo` (one per known node — populates NodeDB), `Config`, `ModuleConfig`, `Channel`, etc. Cache it all.
6. After config_complete: stay subscribed; new packets arrive via FROMNUM ticks.

### 3.3 Receiving positions

A position update arrives as a `FromRadio.packet` (`MeshPacket`) where `decoded.portnum == POSITION_APP` and `decoded.payload` is a serialized `Position` protobuf. Fields used:

- `latitude_i`, `longitude_i` — int32, fixed-point 1e-7 degrees
- `altitude` — meters
- `time` — Unix seconds (GPS time of fix)
- `sats_in_view`, `precision_bits`, `ground_speed`, `ground_track`

The packet's `from` field is the tracker's node number (uint32). We index fixes by that.

### 3.4 Requesting a position (the "Ping" feature)

Build and send:

```
ToRadio.packet = MeshPacket {
  to: <tracker node num>
  want_ack: true
  id: <random non-zero u32>
  decoded: Data {
    portnum: POSITION_APP
    payload: <empty>
    want_response: true
  }
}
```

Stock firmware's position module replies with a fresh `Position` packet addressed back to us. We correlate the reply by `from == tracker` arriving after our request id, with a **timeout** (suggest 30s for direct, 60s if mesh hops > 0).

UI states for the Ping button: `idle → requesting (spinner + countdown) → success (new fix appears) | timeout (toast: "no response, try again")`.

### 3.5 Things to watch out for
- `latitude_i == 0 && longitude_i == 0` is the convention for "no fix" — filter these out.
- Stock firmware rate-limits responses; back-to-back pings within a few seconds may be dropped. Disable the button for ~10s after a press.
- `time` from the tracker is GPS time of fix, not transmission time. Display *both* "fix age" and "received age" in detail view; the compass should use fix age.
- Node numbers ≠ user-friendly IDs. The `User` sub-message carried in `NodeInfo` has `long_name` / `short_name` / hex `id` ("!a1b2c3d4"). Show both in the assignment screen.

---

## 4. Offline Topographic Maps

### 4.1 Choice: USGS US Topo via MapLibre + MBTiles

- **Renderer:** MapLibre Native iOS (Mapbox GL fork, BSD licensed, no token required).
- **Tile source:** USGS National Map "USGS Topo" raster tiles. Public domain (US Government work) — **no licensing barrier for App Store distribution**.
- **Storage format:** MBTiles (SQLite container of PNG tiles). MapLibre has a built-in MBTiles raster source. One file per downloaded region.
- **Coverage:** US only out of the box. For non-US trips we'll add OpenTopoMap (CC-BY-SA, requires attribution overlay) as a secondary source in v1.1.

### 4.2 Region download flow

In-app "Tile Manager" screen:
1. User pans/zooms a preview map to the area they care about.
2. Selects a zoom range (default z10–z15 for hiking; z16 if they want detail).
3. App calculates tile count + estimated MB and asks to confirm.
4. Downloader fetches tiles from USGS WMTS endpoint, writes them into a new MBTiles file in the app's Documents directory, named by the user.
5. List of downloaded regions is shown with size, bbox, and a delete button.

This must happen **while the phone has internet** (at home / on Wi-Fi) before going to the field. The app must make this obvious — a warning banner if no offline regions are available.

### 4.3 Tile budget sanity check
US Topo at z10–z15 for a 20×20 km area is roughly **50–150 MB**. A whole national park can be a few hundred MB. Acceptable.

---

## 5. Data Model (SwiftData)

```swift
@Model class Tracker {
    @Attribute(.unique) var nodeNum: UInt32   // Meshtastic node number
    var name: String                          // user-assigned ("Maple")
    var colorHex: String                      // marker color (ring around photo)
    @Attribute(.externalStorage) var photoData: Data?  // ~256x256 JPEG
    var assignedAt: Date
    @Relationship(deleteRule: .cascade) var fixes: [Fix]
}

@Model class Fix {
    var tracker: Tracker?
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var fixTime: Date          // GPS time from Position.time
    var receivedAt: Date       // when the phone got the packet
    var sats: Int?
    var precisionBits: Int?
    var source: FixSource      // .scheduled or .requested (from a Ping)
}

@Model class TileRegion {
    var name: String
    var filename: String       // MBTiles file in Documents
    var bbox: BoundingBox
    var minZoom: Int
    var maxZoom: Int
    var sizeBytes: Int64
    var downloadedAt: Date
}
```

Position history retention: keep all fixes; add a "Clear history" button in settings. At 1 fix/min × 3 dogs × 8 hr = 1,440 rows/day, this is trivial for SQLite.

---

## 6. UI / Screens

### 6.1 Map (primary screen)
- Full-screen MapLibre view with offline topo source.
- Markers: user (blue dot), each dog (colored pin with first letter of name).
- Tap a dog marker → bottom sheet: name, distance/bearing from user, fix age, lat/lon, "Ping" button, "Open compass" button, last 24h breadcrumb toggle.
- Top bar: connection status (BLE radio icon, green/yellow/red), tile region indicator.
- FAB: "Ping all" (sends position requests to all assigned trackers in sequence, ~2s spacing).

### 6.2 Compass
- Selected from map sheet or trackers list.
- Big arrow rotated to bearing (true north, accounting for magnetic declination via `CLHeading.trueHeading`).
- Center: distance ("237 m").
- Below arrow: "Last fix 3 min ago" with color coding (green <2 min, yellow <10, red older).
- Bottom: Ping button (same behavior as map sheet).
- Lock screen orientation to portrait here.

### 6.3 Trackers list / assignment
- Shows all nodes seen by the local NodeDB.
- For each: hex ID, long_name, last heard, signal (RSSI/SNR if available), and an "Assign as dog" toggle (cap at 3).
- Assigned dogs get a name + color picker.

### 6.4 Tile Manager
- List of downloaded regions.
- "Add region" → preview map → bbox + zoom → download with progress.
- Delete with confirmation.

### 6.5 Settings
- Paired Meshtastic node (re-pair / forget).
- History retention.
- Units (metric / imperial).
- Ping timeout.
- About / attribution.

---

## 7. iOS Permissions & Capabilities

| Capability | Why | Info.plist key |
|---|---|---|
| Bluetooth | Talk to companion Meshtastic node | `NSBluetoothAlwaysUsageDescription` |
| Location: When In Use | Show user on map, compute bearing/distance | `NSLocationWhenInUseUsageDescription` |
| Location: Always (optional) | Background fix logging while screen off | `NSLocationAlwaysAndWhenInUseUsageDescription` |
| Background modes | `bluetooth-central`, `location` — keep BLE link alive when phone screen is off so position updates still arrive | Capabilities tab |
| Motion | Compass heading (`CLLocationManager` covers this; no extra key needed for heading itself) | — |

**App Store review notes:** purpose strings must be specific ("Used to relay GPS positions from your Meshtastic dog trackers and show their location on the map"). Background BLE is justified by the live-tracking use case — we'll mention it explicitly in the review notes.

---

## 8. Risks & Open Questions

| Risk | Mitigation |
|---|---|
| **Meshtastic protobuf drift.** Firmware bumps occasionally rename/add fields. | Pin to a known-good `.proto` version, write codec tests, document the firmware version range we support in About. |
| **BLE reconnection on iOS is fiddly.** Background disconnect/reconnect needs CoreBluetooth state restoration. | Implement state restoration from day one; test screen-off, app-backgrounded, and "phone in pocket for 30 min" cases. |
| **App Store rejection for vague purpose.** | Clear screenshots, demo video for review, specific permission strings, no dev/debug screens shipped. |
| **Tile licensing.** | USGS = public domain → safe. OpenTopoMap (v1.1) = CC-BY-SA → bake attribution into the map view. Never ship with a Mapbox/Google token. |
| **LoRa range reality.** Users may blame the app when a dog is just out of mesh range. | Show "last heard" prominently; surface SNR/RSSI; in-app help page explaining range expectations. |
| **Compass accuracy near metal/electronics.** | Show low-accuracy warning when `CLHeading.headingAccuracy` is poor; prompt the figure-8 calibration dance. |
| **Battery drain** on phone with screen-on map + BLE + GPS. | Add a "low power mode" that drops map FPS and disables breadcrumbs. |
| **Tracker firmware position module config.** Some users disable broadcast positions. | On first connection, check the tracker's NodeInfo + last position; if missing, warn the user. |

### Resolved
1. **Companion node:** Heltec V3 (ESP32 + SX1262, BLE-capable — no special handling needed beyond stock Meshtastic BLE service).
2. **Tracker fix interval:** `position.broadcast_secs = 120` (2 min). Drives:
   - Default Ping timeout: 30 s direct, 60 s if mesh hops > 0.
   - Fix-age color thresholds: **green ≤ 3 min, yellow ≤ 10 min, red > 10 min** (one fresh broadcast within green band, room for one missed broadcast in yellow).
3. **Dog photos on markers:** **In v1.** Implications:
   - Add `photoData: Data?` (or external file ref) to `Tracker` model.
   - Photo picker in tracker assignment screen (`PhotosPicker` from PhotosUI).
   - Marker rendering: circular cropped photo with colored ring (color = tracker color), fall back to colored pin with first letter if no photo set.
   - Compress to ~256×256 JPEG at write time to keep DB lean.
4. **Apple Watch:** v2. Architectural prep now: keep `MeshService`, `TrackerStore`, and the bearing/distance math in a framework-friendly module so a future watchOS target can link them. Compass screen on the wrist is the killer feature.

---

## 9. Build Plan (when we start coding)

Phased so each step produces something runnable.

1. **Project scaffold** — Xcode project, SwiftUI app, SwiftData stack, dependencies (SwiftProtobuf, MapLibre Native iOS) via SPM.
2. **Protobuf integration** — vendor the Meshtastic `.proto` files at a pinned commit, generate Swift, write a round-trip test.
3. **BLE transport** — scan, connect, FROMRADIO/TORADIO/FROMNUM, want_config_id handshake. Console-log every decoded `FromRadio`. (Milestone: see your own NodeDB dump in Xcode console.)
4. **Mesh service + NodeDB** — in-memory model of nodes, position handler.
5. **Trackers list + assignment UI** — pick which nodes are dogs, persist with SwiftData.
6. **MapLibre integration with a placeholder online tile source** — show user + dogs on a map. (Milestone: live dot moving as positions arrive.)
7. **Ping** — outbound position request, pending state, timeout, response correlation.
8. **Compass screen.**
9. **MBTiles offline source + Tile Manager + USGS downloader.**
10. **Background BLE / state restoration / hardening.**
11. **Polish, icons, App Store assets, TestFlight.**

Each phase ends with the app still launching and the previous phase still working.

---

## 10. What I need from you to start phase 1
- Confirm Xcode version (needs 15+ for iOS 17 SwiftData).
- Apple Developer account enrolled (can defer until phase 11 / TestFlight, but the bundle ID should be picked early).
- Your companion node hardware model.
- Tracker `position.broadcast_secs` value.
- Answers to the four open questions in §8.
