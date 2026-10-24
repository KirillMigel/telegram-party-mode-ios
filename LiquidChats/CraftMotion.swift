import Foundation
import CoreGraphics

enum PhotoPickerMorph {
    static func destination(source: CGRect, width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat) -> CGRect {
        let panelWidth = min(340, width-32)
        // Two square rows, 2 pt between cells, and the existing 6 pt glass rim.
        let panelHeight = min(12+2*(panelWidth-16)/3+2, height-top-bottom-100)
        let x = min(width-16-panelWidth, max(16, source.midX-panelWidth/2))
        let y = min(height-bottom-16-panelHeight, max(top+60, source.minY))
        return CGRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    static func frame(source: CGRect, target: CGRect, progress: Double) -> CGRect {
        let p = max(0, progress)
        // Width leads height, keeping a rounded, inflated surface before it settles.
        let bulge = p < 1 ? sin(.pi*p) : 0
        let w = source.width+(target.width-source.width)*(p+0.16*bulge)
        let h = source.height+(target.height-source.height)*(p-0.10*bulge)
        let centerX = source.midX+(target.midX-source.midX)*p
        return CGRect(x: centerX-w/2, y: source.minY+(target.minY-source.minY)*p, width: w, height: h)
    }
}

struct AvatarTransferPose {
    let direction: CGVector
    let tail: CGFloat
    let head: CGFloat
    let radius: CGFloat
    let squeeze: CGFloat
}

enum AvatarTransferMotion {
    static let duration = 0.42

    private static func smooth(_ value: Double) -> Double {
        let p = min(1, max(0, value))
        return p*p*p*(p*(p*6-15)+10)
    }

    static func replacementProgress(_ progress: Double) -> Double {
        smooth((progress-0.66)/0.28)
    }

    static func pose(progress: Double, source: CGRect, target: CGRect) -> AvatarTransferPose {
        let dx = target.midX-source.midX, dy = target.midY-source.midY
        let distance = hypot(dx, dy)
        let direction = distance > 0.001 ? CGVector(dx: dx/distance, dy: dy/distance) : CGVector(dx: 0, dy: -1)
        let p = min(1, max(0, progress/0.92))
        let sourceRadius = max(1, source.width/2), targetRadius = max(1, target.width/2)
        let head = sourceRadius + (distance+targetRadius-sourceRadius)*smooth(p/0.8)
        let tail = -sourceRadius + (distance-targetRadius+sourceRadius)*smooth((p-0.18)/0.82)
        return AvatarTransferPose(direction: direction, tail: tail, head: head,
                                  radius: sourceRadius+(targetRadius-sourceRadius)*smooth(p),
                                  squeeze: 4*sin(.pi*p))
    }
}

// User-supplied cubic Bézier: x must be inverted before evaluating y.
enum ChatEasing {
    static func parameter(_ fraction: Double) -> Double {
        let fraction = min(1, max(0, fraction))
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let t = (low + high) / 2
            let x = 3 * (1-t) * (1-t) * t * 0.66 + 3 * (1-t) * t * t * 0.34 + t*t*t
            if x < fraction { low = t } else { high = t }
        }
        return (low + high) / 2
    }
    static func value(_ fraction: Double) -> Double {
        if fraction <= 0 { return 0 }; if fraction >= 1 { return 1 }
        let t = parameter(fraction)
        return 3 * (1-t) * t*t + t*t*t
    }
    static func speed(_ fraction: Double) -> Double {
        guard fraction > 0 && fraction < 1 else { return 0 }
        let t = parameter(fraction)
        let dx = 3*(1-t)*(1-t)*0.66 + 6*(1-t)*t*(0.34-0.66) + 3*t*t*(1-0.34)
        return 6*(1-t)*t / dx
    }
}

struct BezierMotion {
    let start: MotionVector
    let target: MotionVector
    let startedAt: TimeInterval
    let duration: Double
    func sample(at time: TimeInterval) -> SpringSample {
        let fraction = (time-startedAt) / duration
        let p = ChatEasing.value(fraction), v = ChatEasing.speed(fraction) / duration
        func value(_ a: Double, _ b: Double) -> Double { a + (b-a)*p }
        func speed(_ a: Double, _ b: Double) -> Double { (b-a)*v }
        return SpringSample(value: MotionVector(progress: value(start.progress,target.progress), x: value(start.x,target.x), y: value(start.y,target.y)),
                            velocity: MotionVector(progress: speed(start.progress,target.progress), x: speed(start.x,target.x), y: speed(start.y,target.y)))
    }
}

// Exact portable selector from the requested Serega Emotional preset.
enum SeregaSelector {
    static func strength(at time: Double) -> Double {
        if time <= 0 { return 1 }
        if time >= 0.68 { return 0 }
        if time < 0.18 { return 1-time/0.18 }
        let local = time-0.18, w = 2*Double.pi
        return (-1/0.18) * sin(local*w) / (exp(10*local)*w)
    }
    static func newCharacterOffset(old: String, new: String) -> Int {
        guard new.hasPrefix(old) else { return 0 }
        return old.count
    }
}

struct AvatarJourney {
    let groupID: Int
    let members: [Conversation]
    let origins: [Int: CGRect]
    let startedAt: TimeInterval

    func frame(for index: Int, progress: Double, time: TimeInterval, card: CGRect, width: CGFloat) -> CGRect {
        let source = origins[members[index].id] ?? .zero
        let p = min(1, max(0, progress))
        let orbitTime = max(0, time - startedAt - 0.9)
        // Start the loop with zero velocity, matching the eased flight's landing.
        let clock = orbitTime - 0.5 * (1 - exp(-orbitTime / 0.5))
        let angle = Double.pi * 1.15 + Double(index) * 2 * .pi / Double(members.count) + clock * 2 * .pi / 12
        let radiusX = min(width / 2 - 28, card.width / 2 + 34)
        let radiusY = card.height * 0.3
        let end = CGPoint(x: card.midX + cos(angle) * radiusX, y: card.midY + sin(angle) * radiusY)
        let start = CGPoint(x: source.midX, y: source.midY)
        let c1 = CGPoint(x: start.x + width * 0.48, y: start.y - 90)
        let c2 = CGPoint(x: end.x + width * 0.14, y: end.y - 85)
        let q = 1 - p
        let center = CGPoint(x: q*q*q*start.x + 3*q*q*p*c1.x + 3*q*p*p*c2.x + p*p*p*end.x,
                             y: q*q*q*start.y + 3*q*q*p*c1.y + 3*q*p*p*c2.y + p*p*p*end.y)
        let diameter = source.width + (54 + 6 * sin(angle) - source.width) * p
        return CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    }
}

struct WelcomeStickerPose {
    let center: CGPoint
    let size: CGFloat
    let rotation: Double
    let opacity: Double
}

enum WelcomeBurst {
    static let count = 6

    static func portal(time: Double, card: CGRect) -> CGPoint {
        let p = ChatEasing.value(max(0, time) / 0.5)
        return CGPoint(x: card.midX, y: card.midY - 42 * (1-p))
    }

    static func sticker(_ index: Int, time: Double, card: CGRect, width: CGFloat) -> WelcomeStickerPose {
        let delay = 0.48 + Double(index) * 0.065 + Double(index/4) * 0.14
        let age = max(0, time - delay)
        let duration = 1.6 + Double(index % 4) * 0.12
        let fraction = min(1, age / duration)
        // Exponential ease-out preserves a brisk launch and a very soft landing.
        let p = fraction >= 1 ? 1 : 1 - pow(1 - fraction, 4)
        let source = portal(time: delay, card: card)
        let side: Double = index.isMultiple(of: 2) ? -1 : 1
        let row = index/2
        let radius = min(width/2-40, [114.0, 146.0, 126.0][row])
        let column = side*radius/288
        let end = CGPoint(x: card.midX+side*radius, y: card.midY+[-66.0, 0.0, 68.0][row])
        let q = 1 - p
        let drift = ChatEasing.value((age-duration)/0.9)
        let x = q*q*q*source.x + 3*q*q*p*(source.x + column*20) + 3*q*p*p*(end.x + column*24) + p*p*p*end.x
        let y = q*q*q*source.y + 3*q*q*p*(source.y-95) + 3*q*p*p*(end.y-25) + p*p*p*end.y
        let phase = Double(index)*2.399963
        // Only the size breathes after arrival; every sticker keeps a fixed anchor.
        let pulse = 1 + 0.07*sin(age*2.2+phase)*drift
        return WelcomeStickerPose(center: CGPoint(x: x, y: y),
                                  size: CGFloat(34 + index%4*7) * (0.8 + 0.2*p) * pulse,
                                  rotation: (-24 + Double(index%5)*12)*p,
                                  opacity: time < delay ? 0 : min(1, age/0.04))
    }
}



struct PartyLaunch {
    let source: CGRect
    let startedAt: TimeInterval
}

struct PartyPortalPose {
    let center: CGPoint
    let scaleX: Double
    let scaleY: Double
    let iconReveal: Double
}

enum PartyLaunchMotion {
    static let duration = 1.3
    static let burstLead = 0.48
    static let messageDuration = 0.28

    static func messageProgress(time: Double?, reduceMotion: Bool = false) -> Double {
        guard !reduceMotion, let time else { return 1 }
        return ChatEasing.value((time-(duration-messageDuration))/messageDuration)
    }

    static func pose(time: Double, source: CGRect, target: CGRect, reduceMotion: Bool = false) -> PartyPortalPose {
        guard !reduceMotion, time < duration else {
            return PartyPortalPose(center: CGPoint(x: target.midX, y: target.midY), scaleX: 1, scaleY: 1, iconReveal: 1)
        }
        let age = max(0, time)
        let inflate = ChatEasing.value(age/0.16)
        let flight = CriticalSpring(start: .zero, target: MotionVector(progress: 1), velocity: .zero,
                                    startedAt: 0.16, response: 0.78, dampingRatio: 0.8).sample(at: age).value.progress
        let p = max(0, flight), q = 1-p
        let start = CGPoint(x: source.midX, y: source.midY)
        let end = CGPoint(x: target.midX, y: target.midY)
        let c1 = CGPoint(x: start.x-110, y: start.y-80)
        let c2 = CGPoint(x: end.x+90, y: end.y+100)
        let center = CGPoint(x: q*q*q*start.x + 3*q*q*p*c1.x + 3*q*p*p*c2.x + p*p*p*end.x,
                             y: q*q*q*start.y + 3*q*q*p*c1.y + 3*q*p*p*c2.y + p*p*p*end.y)
        let stretch = sin(.pi*min(1, p))
        let swell = (1-min(1, p))*0.16*inflate
        let sx = source.width/target.width + (1-source.width/target.width)*inflate + swell-0.16*stretch
        let sy = source.height/target.height + (1-source.height/target.height)*inflate + swell+0.28*stretch
        return PartyPortalPose(center: center, scaleX: sx, scaleY: sy, iconReveal: ChatEasing.value(age/0.24))
    }
}
