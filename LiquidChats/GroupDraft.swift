import Foundation
import CoreGraphics

enum ChatTheme: String, CaseIterable, Sendable {
    case meadow, peach, sand, mint, lagoon, lavender, newYear

    var name: String {
        switch self {
        case .meadow: "Meadow"
        case .peach: "Peach"
        case .sand: "Sand"
        case .mint: "Mint"
        case .lagoon: "Lagoon"
        case .lavender: "Lavender"
        case .newYear: "New Year"
        }
    }
}

struct GroupThemeChoice {
    private(set) var saved: [Int: ChatTheme] = [:]
    private(set) var draft: ChatTheme?
    private var editingGroupID: Int?

    mutating func begin(groupID: Int) { editingGroupID = groupID; draft = saved[groupID] ?? .meadow }
    mutating func preview(_ theme: ChatTheme) { if editingGroupID != nil { draft = theme } }
    @discardableResult mutating func save(groupID: Int) -> Bool {
        guard editingGroupID == groupID, let draft else { return false }
        saved[groupID] = draft
        cancel()
        return true
    }
    mutating func cancel() { draft = nil; editingGroupID = nil }
    func visible(groupID: Int) -> ChatTheme {
        editingGroupID == groupID ? draft ?? saved[groupID] ?? .meadow : saved[groupID] ?? .meadow
    }
}

enum ChatComposerLayout {
    static func bottomInset(height: CGFloat, safeBottom: CGFloat, group: Bool) -> CGFloat {
        max(safeBottom, 12) + (group ? max(64, height*0.5-110)+20 : 0)
    }
}

struct ThemeRippleTransition {
    static let revealDuration = 0.45
    static let duration = 2.0
    let from: ChatTheme
    let to: ChatTheme
    let origin: CGPoint
    let startedAt: TimeInterval

    func age(at time: TimeInterval) -> Double { max(0, time-startedAt) }
    func maxRadius(size: CGSize) -> CGFloat {
        [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height),
         CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x-origin.x, $0.y-origin.y) }.max()! + 100
    }
}

struct Conversation: Identifiable, Sendable {
    let id: Int
    var name: String
    let preview: String
    let time: String
    let avatar: String
    var unread = 0
    var muted = false
    var isGroup = false
    var members: [Conversation] = []
    var groupNameSet = false

    static let reference = [
        Conversation(id: 0, name: "Ewan GodDamn", preview: "Sunset spot at 7? I'll bring the camera", time: "12:41", avatar: "ewan"),
        Conversation(id: 1, name: "Alicia Brown", preview: "Sent you 17 Grams 💎", time: "12:20", avatar: "alicia", unread: 1),
        Conversation(id: 2, name: "Study Group", preview: "Emma\ncalculations.zip", time: "11:58", avatar: "study", muted: true, isGroup: true),
        Conversation(id: 3, name: "Thomas", preview: "Happy Birthday! 🎉", time: "11:22", avatar: "thomas", unread: 3, muted: true),
        Conversation(id: 4, name: "Jessica", preview: "See you at the gallery ✨", time: "10:47", avatar: "jessica")
    ]
}

struct GroupDraft {
    let anchorID: Int
    let textSourceID: Int
    var members: [Conversation]

    var memberIDs: [Int] { members.map(\.id) }
    var memberNames: String { members.map { String($0.name.split(separator: " ").first ?? "") }.joined(separator: ", ") }
    var preview: Conversation {
        Conversation(id: anchorID, name: "New Group", preview: memberNames, time: "", avatar: members[0].avatar,
                     isGroup: true, members: members)
    }

    static func merging(sourceID: Int, targetID: Int, conversations: [Conversation], current: GroupDraft?) -> GroupDraft? {
        guard sourceID != targetID,
              let source = conversations.first(where: { $0.id == sourceID }), !source.isGroup,
              let target = conversations.first(where: { $0.id == targetID }), !target.isGroup else { return nil }
        if var current {
            guard targetID == current.anchorID, !current.memberIDs.contains(sourceID) else { return nil }
            current.members.append(source)
            return current
        }
        return GroupDraft(anchorID: targetID, textSourceID: sourceID, members: [target, source])
    }

    func visible(in conversations: [Conversation]) -> [Conversation] {
        conversations.compactMap { item in
            if item.id == anchorID { return preview }
            return memberIDs.contains(item.id) ? nil : item
        }
    }

    func creating(in conversations: [Conversation]) -> [Conversation] {
        guard members.count >= 2 else { return conversations }
        let group = Conversation(id: anchorID, name: memberNames, preview: "Group created · \(members.count) members",
                                 time: "now", avatar: members[0].avatar, isGroup: true, members: members)
        return conversations.compactMap { item in
            if item.id == anchorID { return group }
            return memberIDs.contains(item.id) ? nil : item
        }
    }
}

enum GroupAvatarLayout {
    static func destination(personID: Int, rowIDs: [Int], draft: GroupDraft?, editInset: CGFloat, scrollOrigin: CGFloat) -> CGRect {
        if let draft, let memberIndex = draft.memberIDs.firstIndex(of: personID),
           let rowIndex = rowIDs.firstIndex(of: draft.anchorID) {
            let slots = frames(count: draft.members.count)
            guard memberIndex < slots.count else { return .zero }
            return slots[memberIndex]
                .offsetBy(dx: 16, dy: scrollOrigin + CGFloat(rowIndex) * 86.5 + 12)
        }
        guard let rowIndex = rowIDs.firstIndex(of: personID) else { return .zero }
        return CGRect(x: 16 + editInset, y: scrollOrigin + CGFloat(rowIndex) * 86.5 + 12, width: 62, height: 62)
    }

    static func frames(count: Int) -> [CGRect] {
        switch count {
        case ...0: return []
        case 1: return [CGRect(x: 0, y: 0, width: 62, height: 62)]
        case 2: return [CGRect(x: 18, y: 0, width: 44, height: 44), CGRect(x: 0, y: 18, width: 44, height: 44)]
        case 3: return [CGRect(x: 26, y: 0, width: 36, height: 36), CGRect(x: 0, y: 7, width: 36, height: 36), CGRect(x: 14, y: 26, width: 36, height: 36)]
        default: return [CGRect(x: 0, y: 0, width: 34, height: 34), CGRect(x: 28, y: 0, width: 34, height: 34),
                         CGRect(x: 0, y: 28, width: 34, height: 34), CGRect(x: 28, y: 28, width: 34, height: 34)]
        }
    }
}
