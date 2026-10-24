import Foundation
import CoreGraphics

@main struct PartyInteractionCheck {
    static func main() {
        let message = CGRect(x: 40, y: 350, width: 200, height: 60)
        let attachment = PartyStickerAttachment.drop(at: CGPoint(x: 90, y: 380), messages: [7: message])!
        assert(attachment.messageID == 7 && attachment.anchor == CGPoint(x: 0.25, y: 0.5))
        let edge = PartyStickerAttachment.drop(at: CGPoint(x: 245, y: 348), messages: [7: message])!
        assert(edge.anchor == CGPoint(x: 1, y: 0), "A forgiving edge drop must clamp the attachment to the bubble")
        assert(PartyStickerAttachment.drop(at: .zero, messages: [7: message]) == nil)
        assert(PartyStickerAttachment.drop(at: .zero, messages: [7: .zero]) == nil)
        let scrolled = message.offsetBy(dx: 0, dy: -150)
        assert(scrolled.minY+attachment.anchor.y*scrolled.height == 230, "Attachment coordinates must follow a scrolled bubble")

        let scales = (0...180).map { PartyEmphasis.speakerScale(age: Double($0)/100, reduceMotion: false) }
        assert(scales.first == 1 && scales.last == 1 && scales.max()! > 1.7)
        assert(PartyEmphasis.speakerScale(age: nil, reduceMotion: false) == 1)
        assert(PartyEmphasis.speakerScale(age: 0.5, reduceMotion: true) == 1.35)
        let disco = (0...125).map { PartyEmphasis.discoScale(time: Double($0)/100, reduceMotion: false) }
        assert(disco.max()!-disco.min()! > 0.31, "The disco pulse must be clearly visible")
        assert(PartyEmphasis.discoScale(time: 1, reduceMotion: true) == 1)

        let viewport = CGSize(width: 402, height: 874)
        let origin = CGPoint(x: 130, y: 185)
        let burst = PartyEmojiBurst(origin: origin, startedAt: 10)
        var quadrants = Set<Int>()
        for index in 0..<PartyEmojiBurst.count {
            assert(burst.pose(index, at: 10, viewport: viewport, reduceMotion: false).center == origin)
            let filling = burst.pose(index, at: 10.85, viewport: viewport, reduceMotion: false)
            quadrants.insert((filling.center.x < viewport.width/2 ? 0 : 1)+(filling.center.y < viewport.height/2 ? 0 : 2))
            for frame in 0...300 {
                let pose = burst.pose(index, at: 10+Double(frame)/100, viewport: viewport, reduceMotion: false)
                assert(pose.center.x.isFinite && pose.center.y.isFinite && (0...1).contains(pose.opacity))
            }
            assert(burst.pose(index, at: 13, viewport: viewport, reduceMotion: false).opacity == 0)
        }
        assert(quadrants.count == 4, "The shower must fill the screen in all directions from the selected participant")
        assert(burst.pose(1, at: 11, viewport: viewport, reduceMotion: true).center == CGPoint(x: origin.x, y: origin.y-30))
        print("PASS: bubble attachment and scroll anchoring, speaker emphasis, disco pulse, participant-origin shower, screen coverage and Reduce Motion")
    }
}
