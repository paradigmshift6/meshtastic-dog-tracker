#!/usr/bin/env bash
# Regenerate Swift protobuf files from the vendored Meshtastic .proto sources.
#
# Run this whenever you update Vendor/meshtastic-protobufs/ to a new tag.
# The generated *.pb.swift files are committed so the iOS build doesn't need
# protoc — only the SwiftProtobuf runtime (added via SPM in project.yml).
#
# Prerequisites (one-time, dev machine only):
#   brew install protobuf swift-protobuf

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTO_DIR="$ROOT/Vendor/meshtastic-protobufs"
OUT_DIR="$ROOT/DogTracker/Generated"

if ! command -v protoc >/dev/null; then
  echo "error: protoc not found. Run: brew install protobuf" >&2
  exit 1
fi
if ! command -v protoc-gen-swift >/dev/null; then
  echo "error: protoc-gen-swift not found. Run: brew install swift-protobuf" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Generate Swift for the wire-protocol .proto files only.
#
# Skipped (not needed on iOS, and they pull in nanopb which we don't vendor):
#   - deviceonly.proto    device's local persisted state
#   - localonly.proto     imports deviceonly
#   - clientonly.proto    imports localonly
#
# The plugin honors `option swift_prefix = "";` so types land in the global
# namespace as `MeshPacket`, `Position`, etc. (not `Meshtastic_Position`).
cd "$PROTO_DIR"
PROTOS=()
for f in meshtastic/*.proto; do
  case "$(basename "$f")" in
    deviceonly.proto|localonly.proto|clientonly.proto) ;;
    *) PROTOS+=("$f") ;;
  esac
done

protoc \
  --proto_path=. \
  --swift_out="$OUT_DIR" \
  --swift_opt=Visibility=Public \
  "${PROTOS[@]}"

# Tag every generated file with the source version so it's obvious in code
# review where the file came from.
VERSION_TAG="$(grep '^Tag:' "$PROTO_DIR/VERSION" | awk '{print $2}')"
for f in "$OUT_DIR"/meshtastic/*.pb.swift; do
  tmp="$(mktemp)"
  {
    echo "// Generated from meshtastic/protobufs $VERSION_TAG by tools/generate_protos.sh"
    echo "// DO NOT EDIT BY HAND. Re-run the script after updating the vendored protos."
    echo
    cat "$f"
  } > "$tmp"
  mv "$tmp" "$f"
done

# Flatten meshtastic/ subdir into Generated/ so XcodeGen picks them up cleanly.
mv "$OUT_DIR"/meshtastic/*.pb.swift "$OUT_DIR/"
rmdir "$OUT_DIR/meshtastic"

echo "Generated $(ls "$OUT_DIR"/*.pb.swift | wc -l | tr -d ' ') Swift files in $OUT_DIR"
