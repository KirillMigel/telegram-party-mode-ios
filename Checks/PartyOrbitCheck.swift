import Foundation
import CoreGraphics

@main struct PartyOrbitCheck {
    static func main() {
        let avatar = PartyOrbitTarget(id: .avatar(0), frame: CGRect(x: 90, y: 180, width: 50, height: 50))
        let orb = PartyOrbitTarget(id: .sticker(0), frame: CGRect(x: 200, y: 180, width: 50, height: 50))
        let second = PartyOrbitTarget(id: .sticker(1), frame: CGRect(x: 260, y: 180, width: 50, height: 50))
        let targets = [avatar, orb, second]
        var physics = PartyOrbitPhysics()
        physics.update(time: 0, targets: targets, collisions: true)
        physics.move(.avatar(0), target: avatar.frame, start: CGPoint(x: 105, y: 205),
                     location: CGPoint(x: 105, y: 205), velocity: .zero)
        assert(physics.frame(avatar) == avatar.frame, "Grabbing off-center must not snap the portrait")
        physics.move(.avatar(0), target: avatar.frame, start: CGPoint(x: 105, y: 205),
                     location: CGPoint(x: 205, y: 205), velocity: CGVector(dx: 350, dy: 0))
        for frame in 1...60 { physics.update(time: Double(frame)/120, targets: targets, collisions: true) }
        assert(abs(physics.frame(avatar).midX-215) < 0.001, "A held body tracks the finger rather than collision correction")
        assert(physics.frame(avatar, weight: 0) == avatar.frame, "Returning to the list must shed the orbit offset")
        assert(physics.frame(orb).midX > orb.frame.midX+5, "Dragging a portrait must push an orb")
        assert(physics.frame(second).midX > second.frame.midX+1, "Orbs must pass an impulse to another orb")
        physics.release(.avatar(0), velocity: .zero, reduceMotion: false)
        var overshot = false
        for frame in 61...1260 {
            physics.update(time: Double(frame)/120, targets: targets, collisions: true)
            if physics.frame(avatar).midX < avatar.frame.midX { overshot = true }
        }
        assert(overshot, "Release should bounce across the orbit before settling")
        for target in targets {
            assert(abs(physics.frame(target).midX-target.frame.midX) < 0.1)
            assert(abs(physics.frame(target).midY-target.frame.midY) < 0.1)
        }
        physics.move(.avatar(0), target: avatar.frame, start: CGPoint(x: 115, y: 205),
                     location: CGPoint(x: 155, y: 245), velocity: CGVector(dx: 100, dy: 100))
        physics.release(.avatar(0), velocity: .zero, reduceMotion: true)
        assert(physics.frame(avatar) == avatar.frame, "Reduce Motion returns without a bounce")

        var reverse = PartyOrbitPhysics()
        reverse.update(time: 0, targets: [avatar, orb], collisions: true)
        reverse.move(.sticker(0), target: orb.frame, start: CGPoint(x: 225, y: 205),
                     location: CGPoint(x: 145, y: 205), velocity: CGVector(dx: -350, dy: 0))
        reverse.update(time: 1.0/120, targets: [avatar, orb], collisions: true)
        assert(reverse.frame(avatar).midX < avatar.frame.midX-1, "An orb must push a portrait in the opposite direction too")

        var crowded = PartyOrbitPhysics()
        for frame in 0...3600 {
            let time = Double(frame)/120
            let moving = (0..<16).map { index in
                let angle = Double(index)*2*Double.pi/16+time*0.3
                let id: PartyBodyID = index < 4 ? .avatar(index) : .sticker(index-4)
                return PartyOrbitTarget(id: id, frame: CGRect(x: 180+cos(angle)*110, y: 200+sin(angle)*55, width: 52, height: 52))
            }
            crowded.update(time: time, targets: moving, collisions: true)
            for body in crowded.bodies.values {
                assert(body.offset.dx.isFinite && body.offset.dy.isFinite)
                assert(hypot(body.offset.dx, body.offset.dy) < 250, "Dense collisions must stay bounded")
            }
        }
        crowded.update(time: 1000, targets: targets, collisions: true)
        assert(crowded.bodies.values.allSatisfy { $0.velocity.dx.isFinite && $0.velocity.dy.isFinite })
        print("PASS: off-center grab, finger tracking, avatar/orb and orb/orb impulses, bounce return, Reduce Motion, dense collisions and resume")
    }
}
