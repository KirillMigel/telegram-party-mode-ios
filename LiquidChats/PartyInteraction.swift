import Foundation
import CoreGraphics

struct PartyStickerAttachment: Equatable {
    let messageID: Int
    let anchor: CGPoint

    static func drop(at center: CGPoint, messages: [Int: CGRect]) -> Self? {
        guard let id = messages.keys.sorted().first(where: {
            let rect = messages[$0]!
            return !rect.isEmpty && rect.insetBy(dx: -12, dy: -12).contains(center)
        }), let rect = messages[id] else { return nil }
        return Self(messageID: id, anchor: CGPoint(x: min(1, max(0, (center.x-rect.minX)/rect.width)),
                                                   y: min(1, max(0, (center.y-rect.minY)/rect.height))))
    }
}

enum PartyEmphasis {
    static let speakingDuration = 1.8

    static func speakerScale(age: Double?, reduceMotion: Bool) -> Double {
        guard let age, age >= 0, age < speakingDuration else { return 1 }
        if reduceMotion { return 1.35 }
        let attack = min(1, age/0.16)
        let release = min(1, (speakingDuration-age)/0.4)
        let envelope = attack*attack*(3-2*attack)*release*release*(3-2*release)
        return 1 + envelope*(0.62+0.12*sin(age*2*Double.pi*2.4))
    }

    static func discoScale(time: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 1 : 1+0.16*sin(time*2*Double.pi/1.25)+0.025*sin(time*4*Double.pi/1.25)
    }
}

struct PartyEmojiPose {
    let center: CGPoint
    let size: CGFloat
    let angle: Double
    let opacity: Double
}

struct PartyEmojiBurst: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let startedAt: TimeInterval
    static let duration = 2.8
    static let count = 120
    static let symbols = ["🎉", "🔥", "❤️", "🎊", "💖"]
    #if DEBUG
    private static let inspectionFrame = ProcessInfo.processInfo.environment["LIQUID_PARTY_REACTION_FRAME"].flatMap(Double.init)
    #endif

    func age(at time: TimeInterval) -> Double {
        #if DEBUG
        // A still frame lets UI checks inspect the brief shower without recording video.
        if let value = Self.inspectionFrame,
           value.isFinite, (0..<Self.duration).contains(value) { return value }
        #endif
        return time-startedAt
    }

    func pose(_ index: Int, at time: TimeInterval, viewport: CGSize, reduceMotion: Bool) -> PartyEmojiPose {
        let elapsed = age(at: time)
        let age = max(0, elapsed-Double(index%12)*0.012)
        let opacity = elapsed < 0 ? 0 : min(1, age/0.06)*min(1, max(0, (Self.duration-elapsed)/0.6))
        if reduceMotion {
            return PartyEmojiPose(center: CGPoint(x: origin.x+CGFloat(index-1)*30, y: origin.y-30),
                                  size: 28, angle: 0, opacity: opacity)
        }
        let cell = (index*37)%Self.count
        let jitterX = sin(Double(index)*12.9898)*0.44
        let jitterY = sin(Double(index)*7.233+1)*0.44
        let target = CGPoint(x: (CGFloat(cell%10)+0.5+jitterX)*viewport.width/10,
                             y: (CGFloat(cell/10)+0.5+jitterY)*viewport.height/12)
        let flightDuration = 0.65+Double((index*13)%9)*0.045
        let p = 1-pow(1-min(1, age/flightDuration), 3)
        let drift = max(0, age-0.65)
        return PartyEmojiPose(center: CGPoint(x: origin.x+(target.x-origin.x)*p+sin(age*2+Double(index))*drift*18,
                                               y: origin.y+(target.y-origin.y)*p+drift*drift*85),
                              size: CGFloat(24+index%6*3), angle: sin(Double(index))*35+age*Double(index%5-2)*25,
                              opacity: opacity)
    }
}
