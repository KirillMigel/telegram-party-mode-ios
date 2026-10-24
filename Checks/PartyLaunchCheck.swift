import Foundation
import CoreGraphics

@main struct PartyLaunchCheck {
    static func main() {
        let start = PartyLaunchMotion.duration-PartyLaunchMotion.messageDuration
        assert(PartyLaunchMotion.messageProgress(time: start) == 0)
        assert(PartyLaunchMotion.messageProgress(time: PartyLaunchMotion.duration) == 1)
        assert(PartyLaunchMotion.messageProgress(time: nil) == 1, "Reopening a running party must use the final layout")
        assert(PartyLaunchMotion.messageProgress(time: 0, reduceMotion: true) == 1)
        var previous = 0.0
        for frame in 0...240 {
            let progress = PartyLaunchMotion.messageProgress(time: Double(frame)/120)
            assert(progress >= previous && progress <= 1)
            assert(progress-previous < 0.1, "No frame may release the entire banner and message spacing at once")
            previous = progress
        }
        assert(PartyLaunchMotion.messageProgress(time: start+PartyLaunchMotion.messageDuration/2) > 0.4)
        for source in [CGRect(x: 302, y: 650, width: 74, height: 40),
                       CGRect(x: 294, y: 382, width: 78, height: 38)] {
            let target = CGRect(x: 167, y: 154, width: 68, height: 68)
            let initial = PartyLaunchMotion.pose(time: 0, source: source, target: target)
            assert(initial.center == CGPoint(x: source.midX, y: source.midY))
            assert(abs(initial.scaleX*68-source.width) < 0.001 && abs(initial.scaleY*68-source.height) < 0.001)
            assert(initial.iconReveal == 0, "Start must first occupy its captured source")
            var overshot = false
            for frame in 0...240 {
                let time = Double(frame)/120
                let pose = PartyLaunchMotion.pose(time: time, source: source, target: target)
                assert(pose.center.x.isFinite && pose.center.y.isFinite && pose.scaleX > 0 && pose.scaleY > 0)
                assert((0...1).contains(pose.iconReveal))
                assert(pose.center.x-34*pose.scaleX > 0 && pose.center.x+34*pose.scaleX < 402)
                if pose.center.y < target.midY { overshot = true }
            }
            assert(overshot, "The arriving portal should softly overshoot and return")
            let end = PartyLaunchMotion.pose(time: PartyLaunchMotion.duration, source: source, target: target)
            assert(end.center == CGPoint(x: target.midX, y: target.midY) && end.scaleX == 1 && end.scaleY == 1)
            let before = PartyLaunchMotion.pose(time: PartyLaunchMotion.duration-0.00001, source: source, target: target)
            assert(hypot(before.center.x-end.center.x, before.center.y-end.center.y) < 0.1, "Finishing must not snap")
            let reduced = PartyLaunchMotion.pose(time: 0, source: source, target: target, reduceMotion: true)
            assert(reduced.center == end.center && reduced.scaleX == 1 && reduced.scaleY == 1 && reduced.iconReveal == 1)
        }
        print("PASS: Start origins, finite flight, smooth landing, continuous message layout, reopened party and Reduce Motion")
    }
}
