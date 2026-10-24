#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks .build/ModuleCache
sources=(LiquidChats/GroupDraft.swift LiquidChats/Motion.swift LiquidChats/CraftMotion.swift LiquidChats/PartyOrbitPhysics.swift LiquidChats/PartyInteraction.swift Integration/PartyModeHostContract.swift)
for check in Checks/*Check.swift; do
    name="$(basename "$check" .swift)"
    xcrun swiftc -swift-version 6 -module-cache-path .build/ModuleCache "${sources[@]}" "$check" -o ".build/checks/$name"
    ".build/checks/$name"
done
