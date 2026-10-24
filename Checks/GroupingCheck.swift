import Foundation

@main @MainActor
struct GroupingCheck {
    static func main() {
        let contacts = Conversation.reference
        assert(GroupDraft.merging(sourceID: 0, targetID: 0, conversations: contacts, current: nil) == nil)
        assert(GroupDraft.merging(sourceID: 0, targetID: 2, conversations: contacts, current: nil) == nil)
        assert(GroupDraft.merging(sourceID: 2, targetID: 0, conversations: contacts, current: nil) == nil)
        assert(GroupDraft.merging(sourceID: 99, targetID: 0, conversations: contacts, current: nil) == nil)
        let pair = GroupDraft.merging(sourceID: 0, targetID: 1, conversations: contacts, current: nil)!
        assert(pair.memberIDs == [1, 0] && pair.anchorID == 1 && pair.textSourceID == 0)
        assert(pair.visible(in: contacts).map(\.id) == [1, 2, 3, 4])
        assert(pair.visible(in: contacts)[0].members.count == 2)
        assert(GroupDraft.merging(sourceID: 0, targetID: 1, conversations: contacts, current: pair) == nil)
        assert(GroupDraft.merging(sourceID: 3, targetID: 4, conversations: contacts, current: pair) == nil)
        let triple = GroupDraft.merging(sourceID: 3, targetID: 1, conversations: contacts, current: pair)!
        let four = GroupDraft.merging(sourceID: 4, targetID: 1, conversations: contacts, current: triple)!
        assert(four.memberIDs == [1, 0, 3, 4])
        assert(four.visible(in: contacts).count == 2)
        assert(four.textSourceID == 0, "Adding another person must preserve the original title carrier")
        let rowIDs = pair.visible(in: contacts).map(\.id)
        let ewan = GroupAvatarLayout.destination(personID: 0, rowIDs: rowIDs, draft: pair, editInset: 36, scrollOrigin: -20)
        let alicia = GroupAvatarLayout.destination(personID: 1, rowIDs: rowIDs, draft: pair, editInset: 36, scrollOrigin: -20)
        assert(ewan.width == 44 && alicia.width == 44 && ewan.midY > alicia.midY)
        assert(ewan.minX == 16 && alicia.minX == 34, "Original avatars shrink into their own distinct slots")
        let study = GroupAvatarLayout.destination(personID: 2, rowIDs: rowIDs, draft: pair, editInset: 0, scrollOrigin: -20)
        assert(study.minY == 78.5 && study.width == 62, "Following rows collapse by exactly one row")
        let scrolled = GroupAvatarLayout.destination(personID: 4, rowIDs: [0,1,2,3,4], draft: nil, editInset: 36, scrollOrigin: -100)
        assert(scrolled.minX == 52 && scrolled.minY == 258)
        let created = four.creating(in: contacts)
        assert(created.count == 2 && created[0].isGroup && created[0].members.count == 4)
        assert(created[0].id == 1 && created[1].id == 2)
        assert(created[0].name == "Alicia, Ewan, Thomas, Jessica")
        assert(GroupDraft.merging(sourceID: 0, targetID: 1, conversations: created, current: nil) == nil)
        assert(contacts.count == 5 && contacts[1].members.isEmpty, "Cancelling a draft must leave originals available")
        for count in 0...8 {
            let frames = GroupAvatarLayout.frames(count: count)
            assert(frames.count == min(4, count))
            for frame in frames {
                assert(frame.minX >= 0 && frame.minY >= 0 && frame.maxX <= 62 && frame.maxY <= 62)
            }
        }
        let motion = Motion()
        motion.drag(by: CGSize(width: -40, height: 180))
        assert(motion.sample().value.x == -40 && motion.sample().value.y == 180, "Drag must track 1:1 in every direction")
        motion.move(to: .zero, velocity: MotionVector(x: -200, y: 400))
        let handoff = motion.spring.sample(at: motion.spring.startedAt)
        assert(abs(handoff.velocity.x + 200) < 0.00001 && abs(handoff.velocity.y - 400) < 0.00001)
        let longReturn = CriticalSpring(start: MotionVector(y: 500), target: .zero, velocity: MotionVector(y: 1500), startedAt: 0)
        assert(abs(longReturn.sample(at: 0.5).value.y) > 0.25, "A fixed timeout can restore the source before it arrives")
        let stopped = longReturn.sample(at: 1)
        assert(abs(stopped.value.y) < 0.25 && abs(stopped.velocity.y) < 5)
        print("PASS: eligible targets, ordered members, no duplicates, add 3/4 people, cancellation, group creation, avatar layouts, direct drag, release velocity")
    }
}
