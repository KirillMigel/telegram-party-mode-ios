Source: https://github.com/alexwidua/genie (main, retrieved 2026-10-14).
Original Shader.metal, ContentView.swift and MIT license are preserved here.

LiquidChats/AvatarGenie.metal adapts the staged smoother-step squeeze and
inverse sampling to a horizontal funnel terminating in an avatar. The original
vertical grid translation is replaced with a source-left to destination-point
mapping. No package or UIKit dependency is added.

The header text uses a vertical version of that funnel. Avatar replacement uses
the same inverse-sampling principle along the portal-to-appbar direction: its
leading edge moves before the tail, with staged smoother-step compression. The
geometry is computed in AvatarTransferMotion and rendered by avatarTransferGenie.
