import SwiftUI

/// Reserves scroll space and gives the shared avatar/button layers one measured anchor.
struct GroupWelcomeAnchor: View {
    @Binding var buttonFrame: CGRect

    var body: some View {
        Color.clear.frame(height: 150)
            .overlay(alignment: .top) {
                Color.clear.frame(width: 68, height: 68)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.onChange(of: proxy.frame(in: .named("chats-root")), initial: true) {
                                let frame = proxy.frame(in: .named("chats-root"))
                                if !frame.isEmpty && buttonFrame != frame { buttonFrame = frame }
                            }
                        }
                    }
                    .padding(.top, 8)
            }
            .accessibilityHidden(true)
    }
}

/// Keep the banner's natural size while continuously releasing its occupied space.
struct PartyBannerSpace: Layout {
    var progress: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: size.height*(1-progress))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

struct PartyStartBanner: View {
    @Binding var startFrame: CGRect
    let start: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Party mode").font(.system(size: 17, weight: .semibold))
                Text("Users can change the chat theme, send gifts, and mess around.")
                    .font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: start) {
                Text("Start").font(.system(size: 13, weight: .semibold)).fixedSize()
                    .foregroundStyle(.white).frame(width: 78, height: 38)
                    .background(appleBlue.gradient, in: Capsule())
                    .glassEffect(.regular.tint(appleBlue.opacity(0.12)).interactive(), in: Capsule())
            }
            .buttonStyle(ElasticPressStyle()).modifier(LiquidButtonMotion())
            .accessibilityLabel("Start Party Mode")
            .accessibilityIdentifier("start-party-mode")
            .background {
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .named("chats-root")), initial: true) {
                        let frame = proxy.frame(in: .named("chats-root"))
                        if !frame.isEmpty && startFrame != frame { startFrame = frame }
                    }
                }
            }
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

struct PartyMessageLayout: Equatable {
    var bubble = CGRect.zero
    var avatar = CGRect.zero
}

struct PartyMessageLayoutKey: PreferenceKey {
    static let defaultValue: [Int: PartyMessageLayout] = [:]
    static func reduce(value: inout [Int: PartyMessageLayout], nextValue: () -> [Int: PartyMessageLayout]) {
        for (id, layout) in nextValue() {
            var merged = value[id] ?? PartyMessageLayout()
            if !layout.bubble.isEmpty { merged.bubble = layout.bubble }
            if !layout.avatar.isEmpty { merged.avatar = layout.avatar }
            value[id] = merged
        }
    }
}

/// Local participant replies for the group's entrance sequence.
struct PartyMessage: View {
    let member: Conversation
    let index: Int
    let date: Date
    let speakerScale: Double
    let attachments: [Int: PartyStickerAttachment]
    let celebrate: () -> Void
    let returnSticker: (Int) -> Void

    private let replies = ["Let’s party! 🎉", "I’m ready! 🪩", "Let’s gooo 🔥", "Party mode on ✨"]
    private let nameColors: [Color] = [.blue, .purple, .teal, .orange]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Image(member.avatar).resizable().scaledToFill()
                .frame(width: 28, height: 28).clipShape(Circle())
                .overlay { Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5) }
                .scaleEffect(speakerScale, anchor: .bottom)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: PartyMessageLayoutKey.self,
                                               value: [member.id: PartyMessageLayout(avatar: proxy.frame(in: .named("chats-root")))])
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(nameColors[index % nameColors.count])
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(replies[index % replies.count]).font(.system(size: 16))
                        .foregroundStyle(.black)
                    Text(date, format: .dateTime.hour().minute())
                        .font(.system(size: 9)).foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.white, in: .rect(topLeadingRadius: 15, bottomLeadingRadius: 4,
                                         bottomTrailingRadius: 15, topTrailingRadius: 15))
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PartyMessageLayoutKey.self,
                                           value: [member.id: PartyMessageLayout(bubble: proxy.frame(in: .named("chats-root")))])
                }
            }
            .overlay {
                GeometryReader { proxy in
                    ForEach(attachments.keys.sorted().filter { attachments[$0]?.messageID == member.id }, id: \.self) { id in
                        let anchor = attachments[id]!.anchor
                        Image("party-sticker-\(id % 10)").resizable().scaledToFit()
                            .frame(width: 38, height: 38).rotationEffect(.degrees(Double(id%3-1)*12))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            .position(x: anchor.x*proxy.size.width, y: anchor.y*proxy.size.height)
                            .transition(.scale(scale: 1.2).combined(with: .opacity))
                    }
                }
                .allowsHitTesting(false).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: celebrate)
            .contextMenu {
                Button("Celebrate", systemImage: "party.popper", action: celebrate)
                ForEach(attachments.keys.sorted().filter { attachments[$0]?.messageID == member.id }, id: \.self) { id in
                    Button("Return sticker \(id+1)", systemImage: "arrow.uturn.backward") { returnSticker(id) }
                }
            }
            Spacer(minLength: 36)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("party-message-\(member.id)")
        .accessibilityAction(named: "Celebrate", celebrate)
    }
}

struct PartyEmojiShower: View {
    let bursts: [PartyEmojiBurst]
    let time: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            for burst in bursts {
                for index in 0..<(reduceMotion ? 3 : PartyEmojiBurst.count) {
                    let pose = burst.pose(index, at: time, viewport: size, reduceMotion: reduceMotion)
                    guard pose.opacity > 0 else { continue }
                    var particle = context
                    particle.opacity = pose.opacity
                    particle.translateBy(x: pose.center.x, y: pose.center.y)
                    particle.rotate(by: .degrees(pose.angle))
                    particle.draw(Text(PartyEmojiBurst.symbols[(index*17+index/7)%PartyEmojiBurst.symbols.count])
                        .font(.system(size: pose.size)), at: .zero)
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
