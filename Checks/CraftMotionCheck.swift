import Foundation

@main @MainActor
struct CraftMotionCheck {
    static func main() {
        assert(ChatEasing.value(0) == 0 && ChatEasing.value(1) == 1)
        assert(abs(ChatEasing.value(0.5)-0.5) < 0.000001)
        var previous = 0.0
        for step in 0...100 {
            let x = Double(step)/100, y = ChatEasing.value(x)
            assert(y >= previous && y <= 1)
            assert(abs(y + ChatEasing.value(1-x)-1) < 0.000001)
            previous = y
        }
        assert(ChatEasing.value(0.1) < 0.02, "Opening must accelerate from rest")
        assert(ChatEasing.speed(0) == 0 && ChatEasing.speed(1) == 0)
        let opening = BezierMotion(start: .zero, target: MotionVector(progress: 1), startedAt: 10, duration: 0.48)
        assert(opening.sample(at: 10).value == .zero)
        assert(abs(opening.sample(at: 10.24).value.progress-0.5) < 0.000001)
        assert(opening.sample(at: 11).value.progress == 1 && opening.sample(at: 11).velocity.progress == 0)
        let delayed = BezierMotion(start: .zero, target: MotionVector(progress: 1), startedAt: 10.12, duration: 0.48)
        assert(delayed.sample(at: 10.1).value.progress == 0)
        assert(delayed.sample(at: 10.5).value.progress < opening.sample(at: 10.5).value.progress)
        let navigation = Motion(curveDuration: 0.48)
        navigation.move(to: MotionVector(progress: 1))
        navigation.beginDrag()
        let live = navigation.sample().value.progress
        navigation.dragChat(distance: -20, width: 400)
        assert(abs(navigation.sample().value.progress - (live+0.05)) < 0.000001)
        navigation.move(to: .zero, velocity: MotionVector(progress: -2))
        assert(abs(navigation.spring.sample(at: navigation.spring.startedAt).velocity.progress + 2) < 0.000001)
        assert(SeregaSelector.strength(at: 0) == 1 && SeregaSelector.strength(at: 0.18) == 0)
        let overshoot = SeregaSelector.strength(at: 0.269)
        assert(abs(32*overshoot + 6.2) < 0.1)
        assert(abs(1-0.22*overshoot - 1.042) < 0.002)
        assert(abs(12*overshoot + 2.3) < 0.05)
        assert(SeregaSelector.strength(at: 0.68) == 0)
        assert(SeregaSelector.newCharacterOffset(old: "John, Alicia", new: "John, Alicia, Thomas") == 12)
        assert(SeregaSelector.newCharacterOffset(old: "Alicia Brown", new: "New Group") == 0)
        assert(Array("A 👨‍👩‍👧‍👦 é").count == 5, "Stagger indexes must count whole graphemes")
        print("PASS: exact Bézier inversion, symmetric acceleration/deceleration, gesture interruption, release velocity, Serega overshoot and exact settling, appended names, graphemes")
    }
}
