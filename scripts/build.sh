#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
case "$configuration" in Debug|Release) ;; *) echo 'Use Debug or Release' >&2; exit 2 ;; esac
xcodebuild -project LiquidChats.xcodeproj -scheme LiquidChats \
    -configuration "$configuration" -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
