#!/bin/sh
# Compiles the iOS scoring engine (no UI) with the shared test cases and runs
# them. Works on a Mac with Xcode's command-line tools, or on Linux with Swift.
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/indoor-softball-engine-checks"
SWIFTC="${SWIFTC:-swiftc}"
"$SWIFTC" -swift-version 5 \
  Shared/Model/GameSettings.swift Shared/Model/ScoreEvent.swift Shared/Model/Game.swift \
  Shared/Model/GameExport.swift Shared/Model/GameReport.swift \
  Shared/Engine/GameFeedback.swift Shared/Engine/Persistence.swift Shared/Engine/GameStore.swift \
  Tests/EngineChecks/main.swift -o "$OUT"
"$OUT" ../SharedTests/cases.json
