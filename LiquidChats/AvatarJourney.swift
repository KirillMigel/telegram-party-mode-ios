import SwiftUI

struct AvatarReplacement: Identifiable {
    let id = UUID()
    let groupID: Int
    let image: Image
    let startedAt: Date

    func progress(at date: Date) -> Double {
        #if DEBUG
        if let inspected = ProcessInfo.processInfo.environment["LIQUID_AVATAR_TRANSFER_FRAME"].flatMap(Double.init) {
            return min(1, max(0, inspected))
        }
        #endif
        return min(1, max(0, date.timeIntervalSince(startedAt)/AvatarTransferMotion.duration))
    }
}

/// The whole route stays in one render layer so the Genie tail can span both controls.
struct AvatarReplacementLayer: View {
    let replacement: AvatarReplacement
    let date: Date
    let source: CGRect
    let target: CGRect
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let progress = replacement.progress(at: date)
        let pose = AvatarTransferMotion.pose(progress: progress, source: source, target: target)
        ZStack(alignment: .topLeading) {
            replacement.image.resizable().scaledToFill()
                .frame(width: source.width, height: source.width).clipShape(Circle())
                .position(x: source.midX, y: source.midY)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .compositingGroup()
        .distortionEffect(ShaderLibrary.avatarTransferGenie(
            .float2(Float(source.midX), Float(source.midY)),
            .float2(Float(pose.direction.dx), Float(pose.direction.dy)),
            .float4(Float(pose.tail), Float(pose.head), Float(pose.radius), Float(pose.squeeze)),
            .float(Float(source.width/2))), maxSampleOffset: CGSize(width: width, height: height))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ListAvatarPose: Equatable {
    var frame: CGRect
    var angle: Double
    var raised: Bool
}

/// One portrait layer survives list dragging, group composition and navigation.
struct ChatAvatarLayer: View {
    @Namespace private var liquidAvatars

    let poses: [Int: ListAvatarPose]
    let conversations: [Conversation]
    let journey: AvatarJourney?
    let travel: Double
    let navigation: Double
    let profile: Double
    let card: CGRect
    let time: TimeInterval
    let width: CGFloat
    let height: CGFloat
    let composingMembers: [Int]
    let orbitFrames: [Int: CGRect]
    let canDrag: Bool
    let moveAvatar: (Int, DragGesture.Value) -> Void
    let releaseAvatar: (Int, DragGesture.Value) -> Void

    private var people: [Conversation] {
        guard let journey else { return conversations }
        let ids = Set(journey.members.map(\.id))
        return journey.members + conversations.filter { !ids.contains($0.id) }
    }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            ZStack(alignment: .topLeading) {
                ForEach(people) { person in
                    let index = journey?.members.firstIndex(where: { $0.id == person.id })
                    let pose = poses[person.id]
                    let rect = index.map { orbitFrames[person.id] ?? journey!.frame(for: $0, progress: travel, time: time, card: card, width: width) } ?? pose?.frame ?? .zero
                    Group {
                        if person.members.isEmpty {
                            Image(person.avatar).resizable().scaledToFill()
                                .frame(width: rect.width, height: rect.width).clipShape(Circle())
                                .overlay { Circle().strokeBorder(.white, lineWidth: index != nil || composingMembers.contains(person.id) ? 2.5 : 0) }
                                // Keep the portrait circular before the material; clipping
                                // afterwards would cut off the liquid connection.
                                // Keep the material across lift and navigation so its rim never pops.
                                .glassEffect(.regular, in: Circle())
                                .glassEffectID(person.id, in: liquidAvatars)
                        } else {
                            GroupPortrait(members: person.members)
                        }
                    }
                    .contentShape(Circle())
                    .gesture(index != nil && canDrag ? DragGesture(minimumDistance: 0, coordinateSpace: .named("chats-root"))
                        .onChanged { moveAvatar(person.id, $0) }
                        .onEnded { releaseAvatar(person.id, $0) } : nil)
                    .rotationEffect(.degrees(index == nil ? pose?.angle ?? 0 : 0))
                    .shadow(color: .black.opacity(index == nil ? 0 : 0.08 * travel), radius: 8, y: 5)
                    .position(x: rect.midX, y: rect.midY)
                    .opacity(rect.isEmpty ? 0 : index == nil ? 1 : 1 - profile)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: index == nil ? width * (1-navigation) : width)
                    }
                    .zIndex(index != nil ? 10 : pose?.raised == true ? 20 : Double(composingMembers.firstIndex(of: person.id) ?? 0))
                    .transaction { transaction in if index != nil { transaction.animation = nil } }
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(canDrag).accessibilityHidden(true)
    }
}
