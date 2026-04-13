# Dog Tracker

iOS app for tracking off-leash dogs in remote (no-cell) areas using Meshtastic LoRa trackers running stock firmware. Connects to a companion Meshtastic node (Heltec V3) via BLE and displays dog positions on a USGS topographic map — fully offline.

**License:** GPL-3.0 (due to Meshtastic protobuf dependency).

## Features

- **Topo map** with live dog markers (USGS US Topo, public domain)
- **Compass** pointing toward selected dog with distance + fix age
- **One-tap Ping** to request immediate position from any tracker
- **Offline maps** — download USGS topo regions as MBTiles before heading out
- **Up to 3 dogs** with photo, name, and color
- **Background BLE** — keeps receiving positions with the screen off
- Supports stock Meshtastic firmware (no custom firmware needed)

## Hardware setup

```
[Dog tracker]  ──LoRa mesh──►  [Heltec V3 with you]  ──BLE──►  [iPhone app]
```

- Dog tracker: any Meshtastic node with position module enabled, `broadcast_secs = 120`
- Companion: Heltec V3 (or any BLE-capable Meshtastic node) paired to your iPhone

## First-time setup

1. Point `xcode-select` at your Xcode (not Command Line Tools):
   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. Install XcodeGen:
   ```sh
   brew install xcodegen
   ```
3. Generate the Xcode project:
   ```sh
   ./tools/regen.sh
   ```
4. Open `DogTracker.xcodeproj` in Xcode, pick a simulator or device, ⌘R.

## Regenerating protobufs

Only needed if you update the vendored Meshtastic `.proto` files:

```sh
brew install protobuf swift-protobuf  # one-time
./tools/generate_protos.sh
```

## Project layout

```
project.yml                    XcodeGen spec — edit this, not the .xcodeproj
tools/
  regen.sh                     Regenerate .xcodeproj from project.yml
  generate_protos.sh           Generate Swift from vendored .proto files
Vendor/
  meshtastic-protobufs/        Pinned at v2.7.21 (GPL-3.0)
DogTracker/
  DogTrackerApp.swift          @main, SwiftData container, service wiring
  Info.plist                   BLE/location/photos permissions, BG modes
  Assets.xcassets/             AppIcon, AccentColor
  Generated/                   *.pb.swift (auto-generated, committed)
  Models/                      SwiftData @Model: Tracker, Fix, TileRegion
  Radio/                       BLE transport, Meshtastic handshake, RadioController
  Mesh/                        MeshService, MeshNode (NodeDB, position routing)
  Map/                         MapLibre wrapper, MBTiles writer, tile downloader
  Compass/                     BearingMath, LocationProvider
  Utilities/                   Color hex parsing
  Views/                       SwiftUI screens (Map, Compass, Dogs, Tiles, Settings, Radio)
DogTrackerTests/               Unit tests (12 passing)
DESIGN.md                      Architecture + build plan
LICENSE                        GPL-3.0
```

The `.xcodeproj` is not committed — regenerate with `./tools/regen.sh` after pulling.
