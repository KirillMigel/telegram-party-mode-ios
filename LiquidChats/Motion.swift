import Foundation
import Observation

struct MotionVector: Equatable {
    var progress: Double = 0
    var x: Double = 0
    var y: Double = 0
    static let zero = MotionVector()
}

struct SpringSample {
    var value: MotionVector
    var velocity: MotionVector
}

func shouldDismissProfile(translation: CGSize, predicted: CGSize) -> Bool {
    let horizontal = abs(translation.width) > abs(translation.height)
    return (horizontal ? predicted.width : predicted.height) > 110
}

// An analytic spring lets a new gesture grab the actual presentation position.
struct CriticalSpring {
    var start: MotionVector
    var target: MotionVector
    var velocity: MotionVector
    var startedAt: TimeInterval
    var response: Double = 0.40
    var dampingRatio: Double = 1

    func sample(at time: TimeInterval) -> SpringSample {
        let t = max(0, time - startedAt)
        let omega = 2 * Double.pi / response
        func axis(_ initial: Double, _ end: Double, _ speed: Double) -> (Double, Double) {
            let displacement = initial - end
            if dampingRatio < 1 {
                let decayRate = omega * dampingRatio
                let frequency = omega * sqrt(1-dampingRatio*dampingRatio)
                let coefficient = (speed + decayRate * displacement) / frequency
                let wave = displacement * cos(frequency*t) + coefficient * sin(frequency*t)
                let derivative = frequency * (-displacement * sin(frequency*t) + coefficient * cos(frequency*t))
                let decay = exp(-decayRate*t)
                return (end + wave*decay, (derivative-decayRate*wave)*decay)
            }
            let coefficient = speed + omega * displacement
            let decay = exp(-omega * t)
            return (end + (displacement + coefficient * t) * decay,
                    (coefficient - omega * (displacement + coefficient * t)) * decay)
        }
        let p = axis(start.progress, target.progress, velocity.progress)
        let x = axis(start.x, target.x, velocity.x)
        let y = axis(start.y, target.y, velocity.y)
        return SpringSample(value: MotionVector(progress: p.0, x: x.0, y: y.0),
                            velocity: MotionVector(progress: p.1, x: x.1, y: y.1))
    }
}

@MainActor @Observable
final class Motion {
    var spring = CriticalSpring(start: .zero, target: .zero, velocity: .zero, startedAt: 0)
    var dragging: MotionVector?
    var reduceMotion = false
    let curveDuration: Double?
    private var curve: BezierMotion?
    init(curveDuration: Double? = nil, response: Double = 0.4, dampingRatio: Double = 1) {
        self.curveDuration = curveDuration
        spring.response = response
        spring.dampingRatio = dampingRatio
    }
    private var animating = false
    private var settleTask: Task<Void, Never>?
    private var captured: MotionVector = .zero

    func sample(at date: Date = .now) -> SpringSample {
        if let dragging { return SpringSample(value: dragging, velocity: .zero) }
        return curve?.sample(at: date.timeIntervalSinceReferenceDate) ?? spring.sample(at: date.timeIntervalSinceReferenceDate)
    }

    var isActive: Bool {
        dragging != nil || animating
    }

    func move(to target: MotionVector, velocity: MotionVector? = nil, delay: Double = 0) {
        let current = sample()
        settleTask?.cancel()
        if reduceMotion {
            curve = nil
            spring = CriticalSpring(start: target, target: target, velocity: .zero, startedAt: 0,
                                    response: spring.response, dampingRatio: spring.dampingRatio)
            dragging = nil
            animating = false
            return
        }
        curve = velocity == nil ? curveDuration.map {
            BezierMotion(start: current.value, target: target, startedAt: Date.now.timeIntervalSinceReferenceDate + delay, duration: $0)
        } : nil
        spring = CriticalSpring(start: current.value, target: target,
                                velocity: velocity ?? current.velocity,
                                startedAt: Date.now.timeIntervalSinceReferenceDate + delay,
                                response: spring.response, dampingRatio: spring.dampingRatio)
        dragging = nil
        animating = true
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.animating = false
        }
    }

    func beginDrag() {
        guard dragging == nil else { return }
        captured = sample().value
        curve = nil
        settleTask?.cancel()
        animating = false
        dragging = captured
    }

    func dragProfile(x: Double, y: Double) {
        beginDrag()
        dragging = MotionVector(progress: captured.progress,
                                x: captured.x + (x >= 0 ? x : x * 0.22),
                                y: captured.y + (y >= 0 ? y : y * 0.22))
    }

    func drag(by translation: CGSize) {
        beginDrag()
        dragging = MotionVector(progress: captured.progress, x: captured.x + translation.width, y: captured.y + translation.height)
    }

    func dragChat(distance: Double, width: Double) {
        beginDrag()
        // A gesture may grab the title during its overshoot; preserve that presentation position.
        dragging = MotionVector(progress: min(max(1, captured.progress),
                                              max(min(0, captured.progress), captured.progress - distance / width)))
    }
}
