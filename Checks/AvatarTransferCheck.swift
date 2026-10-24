import Foundation
import CoreGraphics

@main struct AvatarTransferCheck {
    static func main() {
        let source = CGRect(x: 167, y: 154, width: 68, height: 68)
        for target in [CGRect(x: 349, y: 51, width: 40, height: 40),
                       CGRect(x: 181, y: 168, width: 40, height: 40)] {
            let start = AvatarTransferMotion.pose(progress: 0, source: source, target: target)
            assert(start.tail == -34 && start.head == 34 && start.radius == 34 && start.squeeze == 0)
            let end = AvatarTransferMotion.pose(progress: 1, source: source, target: target)
            let center = (end.head+end.tail)/2
            assert(abs(source.midX+end.direction.dx*center-target.midX) < 0.000001)
            assert(abs(source.midY+end.direction.dy*center-target.midY) < 0.000001)
            assert(abs(end.head-end.tail-target.width) < 0.000001 && end.radius == target.width/2)
            for frame in 0...240 {
                let p = Double(frame)/240
                let pose = AvatarTransferMotion.pose(progress: p, source: source, target: target)
                assert(pose.head > pose.tail && pose.radius > 0)
                assert(pose.head.isFinite && pose.tail.isFinite && pose.squeeze.isFinite)
                assert(abs(hypot(pose.direction.dx, pose.direction.dy)-1) < 0.000001)
                assert((0...1).contains(AvatarTransferMotion.replacementProgress(p)))
            }
        }
        let stretched = AvatarTransferMotion.pose(progress: 0.45, source: source,
                                                  target: CGRect(x: 349, y: 51, width: 40, height: 40))
        assert(stretched.head-stretched.tail > source.width, "The leading edge must stretch ahead of the tail")
        assert(AvatarTransferMotion.replacementProgress(0.66) == 0)
        assert(AvatarTransferMotion.replacementProgress(1) == 1)
        print("PASS: exact source and destination, finite Genie span, coincident centers, delayed old-avatar displacement")
    }
}
