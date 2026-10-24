import Foundation

@main @MainActor
struct MotionCheck {
    static func main() async {
        let start = MotionVector(progress: 1, x: 140, y: 180)
        let velocity = MotionVector(progress: -0.2, x: 600, y: 800)
        let spring = CriticalSpring(start: start, target: .zero, velocity: velocity, startedAt: 10)
        let initial = spring.sample(at: 10)
        assert(initial.value == start)
        assert(abs(initial.velocity.x - 600) < 0.000001)
        assert(abs(initial.velocity.y - 800) < 0.000001)
        let moving = spring.sample(at: 10.08)
        let reversed = CriticalSpring(start: moving.value, target: MotionVector(progress: 1),
                                      velocity: moving.velocity, startedAt: 10.08)
        assert(reversed.sample(at: 10.08).value == moving.value)
        assert(abs(reversed.sample(at: 10.08).velocity.x - moving.velocity.x) < 0.000001)
        let settled = spring.sample(at: 12).value
        assert(abs(settled.progress) < 0.00001 && abs(settled.x) < 0.00001 && abs(settled.y) < 0.00001)
        for frame in 0...240 {
            let sample = reversed.sample(at: 10.08 + Double(frame) / 120)
            assert(sample.value.progress.isFinite && sample.value.x.isFinite && sample.value.y.isFinite)
        }
        let opening = CriticalSpring(start: .zero, target: MotionVector(progress: 1), velocity: .zero, startedAt: 0)
        var previous = 0.0
        for frame in 0...144 {
            let p = opening.sample(at: Double(frame) / 120).value.progress
            assert(p >= previous && p <= 1, "Opening should settle without a bounce")
            previous = p
        }
        assert(abs(previous - 1) < 0.000001)
        let pill = CriticalSpring(start: .zero, target: MotionVector(progress: 1), velocity: .zero,
                                  startedAt: 0, response: 0.58, dampingRatio: 0.64)
        let pillFrames = (0...144).map { pill.sample(at: Double($0)/120) }
        let overshoot = pillFrames.map(\.value.progress).max()!
        assert(overshoot > 1.05 && overshoot < 1.12, "The title pill must visibly overshoot its destination")
        assert(abs(pillFrames.last!.value.progress-1) < 0.001)
        let grabbed = pill.sample(at: 0.26)
        let returnPill = CriticalSpring(start: grabbed.value, target: .zero, velocity: grabbed.velocity,
                                        startedAt: 0.26, response: 0.58, dampingRatio: 0.64)
        assert(returnPill.sample(at: 0.26).value == grabbed.value)
        assert(abs(returnPill.sample(at: 0.26).velocity.progress-grabbed.velocity.progress) < 0.000001)
        assert((0...144).allSatisfy { returnPill.sample(at: 0.26+Double($0)/120).value.progress.isFinite })
        let animatedPill = Motion(response: 0.58, dampingRatio: 0.64)
        animatedPill.move(to: MotionVector(progress: 1))
        try? await Task.sleep(for: .milliseconds(320))
        animatedPill.beginDrag()
        let overshootingPill = animatedPill.sample().value
        assert(overshootingPill.progress > 1)
        animatedPill.dragChat(distance: 0, width: 402)
        assert(animatedPill.sample().value == overshootingPill, "Grabbing the pill during its bounce must not jump")
        let motion = Motion()
        assert(shouldDismissProfile(translation: CGSize(width: 30, height: 20), predicted: CGSize(width: 180, height: 50)))
        assert(!shouldDismissProfile(translation: CGSize(width: 180, height: 20), predicted: CGSize(width: 40, height: 20)))
        assert(!shouldDismissProfile(translation: CGSize(width: -140, height: 0), predicted: CGSize(width: -220, height: 0)))
        motion.reduceMotion = true
        motion.move(to: MotionVector(progress: 1))
        assert(motion.sample().value.progress == 1 && !motion.isActive)
        motion.dragProfile(x: -100, y: 100)
        assert(motion.sample().value.x == -22 && motion.sample().value.y == 100)
        motion.move(to: .zero)
        assert(motion.sample().value == .zero && !motion.isActive)
        motion.reduceMotion = false
        motion.move(to: MotionVector(progress: 1))
        try? await Task.sleep(for: .milliseconds(100))
        motion.beginDrag()
        let captured = motion.sample().value
        assert(captured.progress > 0 && captured.progress < 1)
        motion.dragProfile(x: 0, y: 0)
        assert(motion.sample().value == captured, "Grabbing a moving card must not jump")
        motion.dragProfile(x: 90, y: 120)
        let release = MotionVector(x: 600, y: 800)
        let beforeRelease = motion.sample().value
        motion.move(to: .zero, velocity: release)
        let initialRelease = motion.spring.sample(at: motion.spring.startedAt)
        assert(initialRelease.value == beforeRelease && initialRelease.velocity == release)
        try? await Task.sleep(for: .milliseconds(1250))
        assert(!motion.isActive && abs(motion.sample().value.y) < 0.001)
        print("PASS: release velocity, reversal continuity, soft default settling, header overshoot and reversal, finite frames, reduced motion, drag resistance, flick dismissal, reverse cancellation, mid-animation grab, idle stop")
    }
}
