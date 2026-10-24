import Foundation
import CoreGraphics

@main struct ThemeChoiceCheck {
    static func main() {
        var choice = GroupThemeChoice()
        assert(!choice.save(groupID: 1))
        choice.preview(.peach)
        assert(choice.visible(groupID: 1) == .meadow)
        choice.begin(groupID: 1)
        choice.preview(.newYear)
        assert(choice.visible(groupID: 1) == .newYear && choice.saved[1] == nil)
        assert(choice.visible(groupID: 2) == .meadow, "Preview must stay in its chat")
        assert(!choice.save(groupID: 2), "Late saves must not change another chat")
        assert(choice.save(groupID: 1) && choice.saved[1] == .newYear && choice.draft == nil)
        choice.begin(groupID: 1)
        choice.preview(.lavender)
        choice.cancel()
        assert(choice.visible(groupID: 1) == .newYear, "Cancel restores the saved wallpaper")
        choice.begin(groupID: 2)
        choice.preview(.lagoon)
        assert(choice.save(groupID: 2))
        assert(choice.saved[1] == .newYear && choice.saved[2] == .lagoon)
        let ripple = ThemeRippleTransition(from: .meadow, to: .newYear, origin: CGPoint(x: 380, y: 280), startedAt: 100)
        assert(ripple.age(at: 99) == 0 && ripple.age(at: 102) == ThemeRippleTransition.duration)
        for corner in [CGPoint.zero, CGPoint(x: 402, y: 0), CGPoint(x: 0, y: 874), CGPoint(x: 402, y: 874)] {
            assert(ripple.maxRadius(size: CGSize(width: 402, height: 874)) >= hypot(corner.x-ripple.origin.x, corner.y-ripple.origin.y)+100)
        }
        for height: CGFloat in [667, 812, 874, 956, 1200] {
            let bottom = ChatComposerLayout.bottomInset(height: height, safeBottom: 34, group: true)
            let stackCenter = height-bottom-26-65
            assert(stackCenter < height*0.5 && stackCenter > height*0.35)
            assert(ChatComposerLayout.bottomInset(height: height, safeBottom: 34, group: false) == 34)
        }
        print("PASS: preview, isolated saves, cancellation, stale save guards, midpoint layout")
    }
}
