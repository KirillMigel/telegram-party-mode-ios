# Implementation handoff

This is a runnable SwiftUI reference for a proposed Party Mode in Telegram iOS. It is not an official Telegram project, a Telegram fork, a drop-in SDK, or an implemented Telegram adapter.

## Run and verify

Open `LiquidChats.xcodeproj` with Xcode 27 and an iOS 27 simulator. No account, API keys, external packages, or signing team are required for the simulator. For a physical device, select your own team and bundle ID.

```sh
./scripts/check.sh
./scripts/build.sh
python3 scripts/preflight.py
```

Long-press Ewan, drag onto Alicia, optionally add Thomas/Jessica, create the group, and press Start. The Start button becomes a pulsing disco ball with orbiting avatars, draggable stickers, light rays, and background ripples. The ball opens sequential title/avatar/theme setup. A sticker can attach to a message; a double tap emits celebratory emoji. All group state and messages are local demo data and reset on restart. The music pill is decorative.

## Porting boundaries

- Reuse the animation math, physics, shaders, and visual components in `LiquidChats`. Do not embed the entire `ChatsPrototype` as a second chat screen.
- `Integration/PartyModeHostContract.swift` defines a proposed adapter interface and stable account/peer/message identifiers. It does not call Telegram Engine and is not wired into the demo.
- Replace `Conversation.reference`, scheduled greetings, integer author-based message keys, asset-name lookups, and in-memory dictionaries with real host data. One author can have multiple messages; message identity must include account, peer, namespace, and message ID.
- Use existing Telegram flows for group creation, permissions, title updates, avatar upload, wallpapers, and themes. Complete mutations only after success, and preserve retry/cancel behavior on failure.
- Decide whether Party Mode and sticker placements are local or synchronized. No server operation or synchronization protocol for these features is supplied.
- Adapt containment, scroll coordinates, hit testing, keyboard layout, Metal resource lookup, Bazel targets, localization, and older-iOS fallbacks to the host app.

The detailed [integration map](TELEGRAM_INTEGRATION.md) links to Telegram-iOS commit `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838`; verify against your target revision. [Acceptance criteria](FEATURE_SPEC.md), [performance work](PERFORMANCE.md), and [validation results](VALIDATION.md) document the remaining work. No performance optimization or stable frame-rate claim is made.

## Licensing

The owner has **not granted a separate license for original code**. Coordinate implementation and redistribution terms with [KirillMigel](https://github.com/KirillMigel). Third-party license notices are preserved and apply to their respective components. Demo media rights are not granted for production. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
