#!/usr/bin/env bash
# Regenerate DogTracker.xcodeproj from project.yml.
#
# XcodeGen stages its output in NSTemporaryDirectory (/var/folders/…) then
# copies the bundle to the destination. On /Volumes the cross-volume bundle
# copy triggers a macOS TCC "Operation not permitted" error regardless of
# TMPDIR overrides. Work around it by generating into /tmp (same local volume
# as /var/folders) then cp -R the result back.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -rf /tmp/DogTracker.xcodeproj
xcodegen generate --spec project.yml --project /tmp "$@"
rm -rf "$ROOT/DogTracker.xcodeproj"
cp -R /tmp/DogTracker.xcodeproj "$ROOT/DogTracker.xcodeproj"
rm -rf /tmp/DogTracker.xcodeproj
