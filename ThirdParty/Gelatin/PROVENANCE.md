# Gelatin

Source: https://github.com/Polarizz/Gelatin

Pinned commit: 2a3ad4cdabe0b9d33b75b6d8839f6d36a1a1b81e

License: MIT, see LICENSE.

GelatinEffect.swift compiled in LiquidButtonMotion.swift. Original brightness/saturation boosts removed; stretch, press scale and release bounce tuned down through the existing parameters. Reduced Motion bypasses the modifier.

The avatar/check button uses maximumStretchFactor 0.9, stretchAmplificationFactor 1, pressedScaleFactor 1.06 and releaseBounceFactor 0.3. GelatinActionStyle owns activation separately: movement beyond 8 pt cancels a tap, so releasing an elastic drag cannot save the group name.
