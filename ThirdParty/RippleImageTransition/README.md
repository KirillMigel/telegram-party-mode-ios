# Ripple Image Transition

Source: https://github.com/eujinco/ripple-image-transition

Original SwiftUI/Metal source files and MIT license are retained here; the exact source commit is recorded in SOURCE.txt. No sample media was downloaded or used.

`themeRipple` and `themeReveal` in `LiquidChats/WelcomeLens.metal` adapt the original Ripple and TransitionReveal shaders. Names and includes match this app; the reveal uses the equivalent ordered-edge form of smoothstep. The original amplitude 25, frequency 20, decay 3.5, speed 1200, ripple duration 2 s, reveal duration 0.45 s and feather 100 pt are retained. Chat wallpaper views replace the sample's prepared images. Both effects start at the selected theme circle. Additional theme taps wait until the atomic reveal is finished; Reduce Motion switches immediately.
