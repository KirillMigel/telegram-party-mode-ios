import Foundation
import CoreGraphics

@main struct WelcomeBurstCheck {
    static func main() {
        let card = CGRect(x: 167, y: 154, width: 68, height: 68)
        assert(WelcomeBurst.portal(time: 0, card: card).y == card.midY - 42)
        assert(WelcomeBurst.portal(time: 1, card: card).y == card.midY)
        for index in 0..<WelcomeBurst.count {
            assert(WelcomeBurst.sticker(index, time: 0, card: card, width: 402).opacity == 0)
            let delay = 0.48 + Double(index)*0.065 + Double(index/4)*0.14
            let launch = WelcomeBurst.sticker(index, time: delay, card: card, width: 402)
            assert(launch.center == WelcomeBurst.portal(time: delay, card: card), "Every sprite must leave the visible portal")
            for frame in 0...3600 {
                let pose = WelcomeBurst.sticker(index, time: Double(frame)/120, card: card, width: 402)
                assert(pose.center.x.isFinite && pose.center.y.isFinite && pose.rotation.isFinite)
                assert(pose.size > 0 && (0...1).contains(pose.opacity))
                assert(pose.center.x-pose.size*0.625 >= 0 && pose.center.x+pose.size*0.625 <= 402)
                assert(pose.center.y+pose.size*0.625 < card.midY+116, "The stickers must stay above the message area")
            }
            let settled = (0...600).map { WelcomeBurst.sticker(index, time: 10+Double($0)/60, card: card, width: 402) }
            let sizes = settled.map(\.size)
            assert(sizes.max()! / sizes.min()! > 1.13, "Every sticker must keep pulsing after the launch")
            assert(settled.allSatisfy { $0.center == settled[0].center && $0.rotation == settled[0].rotation }, "Settled stickers must stay at their anchors")
        }
        assert((0..<WelcomeBurst.count).allSatisfy { WelcomeBurst.sticker($0, time: 60, card: card, width: 402).opacity == 1 }, "Settled stickers must remain fully bright")
        let first = WelcomeBurst.sticker(0, time: 0.6, card: card, width: 402)
        let last = WelcomeBurst.sticker(WelcomeBurst.count-1, time: 0.6, card: card, width: 402)
        assert(first.opacity > 0 && last.opacity == 0, "The burst is staggered, not simultaneous")
        print("PASS: six staggered stickers, fixed resting anchors, continuous pulse and visible portal origin")
    }
}
