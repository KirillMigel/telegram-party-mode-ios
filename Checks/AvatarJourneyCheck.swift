import Foundation
import CoreGraphics

@main struct AvatarJourneyCheck {
    static func main() {
        let members = [Conversation.reference[1], Conversation.reference[0], Conversation.reference[3]]
        let sources = [1: CGRect(x: 34, y: 190, width: 36, height: 36),
                       0: CGRect(x: 16, y: 197, width: 36, height: 36),
                       3: CGRect(x: 30, y: 216, width: 36, height: 36)]
        let journey = AvatarJourney(groupID: 1, members: members, origins: sources, startedAt: 0)
        let card = CGRect(x: 167, y: 154, width: 68, height: 68)
        for index in members.indices {
            let origin = sources[members[index].id]!
            assert(journey.frame(for: index, progress: 0, time: 0, card: card, width: 402) == origin)
            assert(journey.frame(for: index, progress: 0, time: 10, card: card, width: 402) == origin,
                   "Closing must return every member to its captured source, irrespective of orbit phase")
            for step in 0...180 {
                let time = Double(step)/30
                let p = ChatEasing.value(time/0.9)
                let frame = journey.frame(for: index, progress: p, time: time, card: card, width: 402)
                assert(frame.width.isFinite && frame.midX.isFinite && frame.midY.isFinite && frame.width > 0)
                if p == 1 {
                    let nx = (frame.midX-card.midX)/68
                    let ny = (frame.midY-card.midY)/20.4
                    assert(abs(nx*nx+ny*ny-1) < 0.00001, "The landing must join the same ellipse as the loop")
                    assert(frame.minX >= 0 && frame.maxX <= 402)
                    assert(frame.maxY < card.midY+54, "The orbit must stay above the action caption")
                }
            }
            let before = journey.frame(for:index,progress:ChatEasing.value(0.8999/0.9),time:0.8999,card:card,width:402)
            let after = journey.frame(for:index,progress:1,time:0.9001,card:card,width:402)
            assert(hypot(after.midX-before.midX,after.midY-before.midY) < 0.001,
                   "The eased flight and accelerating orbit must meet without a position or velocity jump")
        }
        print("PASS: source identity, reversible return, curved flight, finite frames, elliptical loop, viewport bounds, smooth landing")
    }
}
