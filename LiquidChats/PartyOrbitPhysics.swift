import Foundation
import CoreGraphics

enum PartyBodyID: Hashable {
    case avatar(Int), sticker(Int)
    var mass: CGFloat { if case .avatar = self { 2 } else { 1 } }
}

struct PartyOrbitTarget {
    let id: PartyBodyID
    let frame: CGRect
}

/// Moving orbit anchors plus spring offsets keep collisions independent from the entrance paths.
struct PartyOrbitPhysics {
    struct Body {
        var offset = CGVector.zero
        var velocity = CGVector.zero
    }
    struct Drag {
        let id: PartyBodyID
        let grabOffset: CGVector
        var center: CGPoint
        var velocity: CGVector
    }
    private(set) var bodies: [PartyBodyID: Body] = [:]
    private(set) var drag: Drag?
    private var lastTime: Double?
    private var previous: [PartyBodyID: CGRect] = [:]

    var isActive: Bool { drag != nil || bodies.values.contains { hypot($0.offset.dx, $0.offset.dy) > 0.1 || hypot($0.velocity.dx, $0.velocity.dy) > 0.1 } }

    func frame(_ target: PartyOrbitTarget, weight: CGFloat = 1) -> CGRect {
        let offset = bodies[target.id]?.offset ?? .zero
        return target.frame.offsetBy(dx: offset.dx*weight, dy: offset.dy*weight)
    }

    mutating func move(_ id: PartyBodyID, target: CGRect, start: CGPoint, location: CGPoint, velocity: CGVector) {
        if drag?.id != id {
            let presented = frame(.init(id: id, frame: target))
            drag = Drag(id: id, grabOffset: .init(dx: presented.midX-start.x, dy: presented.midY-start.y),
                        center: .init(x: presented.midX, y: presented.midY), velocity: .zero)
        }
        guard var held = drag else { return }
        held.center = .init(x: location.x+held.grabOffset.dx, y: location.y+held.grabOffset.dy)
        held.velocity = Self.limited(velocity, to: 700)
        drag = held
        bodies[id] = Body(offset: .init(dx: held.center.x-target.midX, dy: held.center.y-target.midY), velocity: held.velocity)
    }

    mutating func release(_ id: PartyBodyID, velocity: CGVector, reduceMotion: Bool) {
        guard drag?.id == id else { return }
        if reduceMotion { bodies[id] = Body() }
        else { bodies[id, default: Body()].velocity = Self.limited(velocity, to: 700) }
        drag = nil
    }

    mutating func update(time: Double, targets: [PartyOrbitTarget], collisions: Bool, reduceMotion: Bool = false) {
        let current = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0.frame) })
        defer { lastTime = time; previous = current }
        bodies = bodies.filter { current[$0.key] != nil }
        for target in targets where bodies[target.id] == nil { bodies[target.id] = Body() }
        guard let lastTime, time > lastTime else { return }
        let resumed = time-lastTime > 0.12
        let dt = min(0.05, time-lastTime)
        let steps = max(1, Int(ceil(dt*120)))
        let h = dt/Double(steps)
        let baseVelocities = Dictionary(uniqueKeysWithValues: targets.map { target in
            let old = resumed ? target.frame : previous[target.id] ?? target.frame
            return (target.id, Self.limited(.init(dx: (target.frame.midX-old.midX)/dt,
                                                dy: (target.frame.midY-old.midY)/dt), to: 500))
        })
        for _ in 0..<steps {
            for target in targets {
                var body = bodies[target.id] ?? Body()
                if let drag, drag.id == target.id {
                    body.offset = .init(dx: drag.center.x-target.frame.midX, dy: drag.center.y-target.frame.midY)
                    body.velocity = drag.velocity
                } else if reduceMotion { body = Body() }
                else {
                    body.velocity.dx += (-42*body.offset.dx-8.5*body.velocity.dx)*h
                    body.velocity.dy += (-42*body.offset.dy-8.5*body.velocity.dy)*h
                    body.velocity = Self.limited(body.velocity, to: 900)
                    body.offset.dx += body.velocity.dx*h
                    body.offset.dy += body.velocity.dy*h
                }
                bodies[target.id] = body
            }
            guard collisions, !reduceMotion else { continue }
            for a in targets.indices {
                for b in targets.indices where b > a {
                    resolve(targets[a], targets[b], baseA: baseVelocities[targets[a].id] ?? .zero,
                            baseB: baseVelocities[targets[b].id] ?? .zero)
                }
            }
        }
    }

    private mutating func resolve(_ a: PartyOrbitTarget, _ b: PartyOrbitTarget, baseA: CGVector, baseB: CGVector) {
        var bodyA = bodies[a.id] ?? Body(), bodyB = bodies[b.id] ?? Body()
        let dx = b.frame.midX+bodyB.offset.dx-a.frame.midX-bodyA.offset.dx
        let dy = b.frame.midY+bodyB.offset.dy-a.frame.midY-bodyA.offset.dy
        let distance = hypot(dx, dy)
        let overlap = (a.frame.width+b.frame.width)*0.48-distance
        guard overlap > 0 else { return }
        let normal = CGVector(dx: distance > 0.001 ? dx/distance : 1, dy: distance > 0.001 ? dy/distance : 0)
        let invA = drag?.id == a.id ? 0 : 1/a.id.mass
        let invB = drag?.id == b.id ? 0 : 1/b.id.mass
        let sum = invA+invB
        guard sum > 0 else { return }
        let correction = max(0, overlap-0.3)*0.7/sum
        bodyA.offset.dx -= normal.dx*correction*invA
        bodyA.offset.dy -= normal.dy*correction*invA
        bodyB.offset.dx += normal.dx*correction*invB
        bodyB.offset.dy += normal.dy*correction*invB
        let relative = (bodyB.velocity.dx+baseB.dx-bodyA.velocity.dx-baseA.dx)*normal.dx +
                       (bodyB.velocity.dy+baseB.dy-bodyA.velocity.dy-baseA.dy)*normal.dy
        if relative < 0 {
            let impulse = min(700, -relative*1.65/sum)
            bodyA.velocity.dx -= normal.dx*impulse*invA
            bodyA.velocity.dy -= normal.dy*impulse*invA
            bodyB.velocity.dx += normal.dx*impulse*invB
            bodyB.velocity.dy += normal.dy*impulse*invB
        }
        bodies[a.id] = bodyA
        bodies[b.id] = bodyB
    }

    private static func limited(_ vector: CGVector, to limit: CGFloat) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length.isFinite else { return .zero }
        let scale = length > limit ? limit/length : 1
        return .init(dx: vector.dx*scale, dy: vector.dy*scale)
    }
}
