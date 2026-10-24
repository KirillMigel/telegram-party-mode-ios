import SwiftUI

private struct ChatFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ScrollOriginKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct DropTargetOutline: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            // A complete dash + gap is 9 pt, so wrapping the phase has no seam.
            let phase = reduceMotion ? 0 :
                -timeline.date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: 0.6) * 15
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.gray.opacity(0.5),
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4], dashPhase: phase))
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct GroupPortrait: View {
    let members: [Conversation]

    var body: some View {
        let frames = GroupAvatarLayout.frames(count: members.count)
        ZStack(alignment: .topLeading) {
            ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                if members.count > 4 && index == 3 {
                    Text("+\(members.count - 3)").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white).frame(width: frame.width, height: frame.height)
                        .background(telegramBlue, in: Circle()).overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                        .position(x: frame.midX, y: frame.midY)
                } else {
                    portrait(members[index], diameter: frame.width)
                        .position(x: frame.midX, y: frame.midY).zIndex(Double(index))
                }
            }
        }
        .frame(width: 62, height: 62)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func portrait(_ person: Conversation, diameter: CGFloat) -> some View {
        let image = Image(person.avatar).resizable().scaledToFill()
            .frame(width: diameter, height: diameter).clipShape(Circle())
            .overlay { Circle().strokeBorder(.white, lineWidth: members.count > 1 ? 2.5 : 0) }
        image
    }
}

private struct ChatRowText: View {
    let item: Conversation
    let isDraft: Bool
    let width: CGFloat
    var angle: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                EmotionalText(text: item.name, enabled: isDraft)
                    .font(.system(size: isDraft ? 17 : 18, weight: .semibold)).lineLimit(1)
                if item.avatar == "alicia" && !item.isGroup { Text("🏅").font(.system(size: 13)).transition(.opacity) }
                if item.muted { Image(systemName: "bell.slash.fill").font(.system(size: 13)).foregroundStyle(.tertiary) }
            }
            EmotionalText(text: item.preview, enabled: isDraft).font(.system(size: isDraft ? 14 : 16)).foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
        }
        .frame(width: max(0, width), height: 62, alignment: .topLeading)
        .rotationEffect(.degrees(angle), anchor: .leading)
    }
}

private struct CreateGroupButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    var body: some View {
        Button(action: action) {
            Text("Create").font(.system(size: 13, weight: .semibold)).fixedSize()
                .foregroundStyle(.white).scaleEffect(reduceMotion ? 1 : reveal)
                .frame(width: 78 * (reduceMotion ? 1 : reveal), height: 38 * (reduceMotion ? 1 : reveal))
                .background(appleBlue.gradient, in: Capsule())
                .glassEffect(.regular.tint(appleBlue.opacity(0.12)).interactive(), in: Capsule())
        }
        .buttonStyle(ElasticPressStyle()).modifier(LiquidButtonMotion())
        .frame(width: 78, height: 38)
        .opacity(reduceMotion ? 1 : reveal)
        .accessibilityLabel("Create").accessibilityIdentifier("create-group")
        .task {
            guard !reduceMotion else { reveal = 1; return }
            // The row itself is new, so a child insertion transition may never run.
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.65, bounce: 0.5)) { reveal = 1 }
        }
    }
}

private struct ConversationListRow: View {
    let item: Conversation
    let width: CGFloat
    let editProgress: Double
    let selected: Bool
    let isDraft: Bool
    let hideMetadata: Bool
    var createGroup: () -> Void

    var body: some View {
        let inset = isDraft ? 0 : 36 * editProgress
        HStack(alignment: .top, spacing: 13) {
            // Portraits and text live in one persistent layer above the row slots.
            Color.clear.frame(width: 62, height: 62)
            Color.clear.frame(width: max(0, width - 120 - (isDraft ? 78 : 52) - inset), height: 62)
            if isDraft {
                CreateGroupButton(action: createGroup).padding(.top, 10)
            } else {
                VStack(alignment: .trailing, spacing: 13) {
                    Text(item.time).font(.system(size: 14)).foregroundStyle(.secondary)
                    if item.unread > 0 {
                        Text("\(item.unread)").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white).frame(width: 23, height: 23)
                            .background(item.muted ? Color.gray.opacity(0.4) : telegramBlue, in: Circle())
                    }
                }
                .frame(width: 52, alignment: .trailing)
                .opacity(hideMetadata ? 0 : 1)
                .animation(.easeOut(duration: 0.08), value: hideMetadata)
                .transition(.opacity.animation(.linear(duration: 0.035)))
            }
        }
        .frame(width: width - 32 - inset, height: 86)
        .padding(.leading, 16 + inset).padding(.trailing, 16)
        .overlay(alignment: .leading) {
            if !isDraft {
                ZStack {
                    Circle().strokeBorder(Color.gray.opacity(0.4), lineWidth: 1.5)
                    if selected {
                        Circle().fill(telegramBlue)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24).padding(.leading, 16)
                .opacity(editProgress).offset(x: -36 * (1 - editProgress)).accessibilityHidden(true)
            }
        }
        .foregroundStyle(.black).contentShape(Rectangle())
    }
}

struct GroupingChatList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var conversations: [Conversation]
    @Binding var draft: GroupDraft?
    @Binding var presentedAvatars: [Int: ListAvatarPose]
    let width: CGFloat
    let search: String
    let rootOrigin: CGPoint
    let frameDate: Date
    let editProgress: Double
    let composing: Bool
    let cancelSignal: Int
    let selected: Set<Int>
    let onTap: (Conversation) -> Void
    let onBegin: () -> Void
    let onCreate: () -> Void

    @State private var retiredTextFrames: [Int: CGRect] = [:]
    @State private var scrollOrigin: CGFloat = 0
    @State private var frames: [Int: CGRect] = [:]
    @State private var liftedID: Int?
    @State private var liftedFrame = CGRect.zero
    @State private var hoveredID: Int?
    @State private var moving = false
    @State private var returning = false
    @State private var liftedAt = Date.now
    @State private var position = Motion()
    @State private var returnTask: Task<Void, Never>?
    @State private var pickerSource: Conversation?

    private var spring: Animation { reduceMotion ? .linear(duration: 0.001) : .spring(duration: 0.6, bounce: 0.36) }
    private var rows: [Conversation] {
        (draft?.visible(in: conversations) ?? conversations).filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.members.contains { $0.name.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    if rows.isEmpty { ContentUnavailableView.search(text: search).padding(.top, 48) }
                    ForEach(rows) { item in
                        listRow(item)
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(key: ChatFramesKey.self, value: [item.id: proxy.frame(in: .named("grouping-list"))])
                                }
                            }
                        Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
                            .padding(.leading, 91 + 36 * editProgress)
                    }
                    Color.clear.frame(height: 72)
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOriginKey.self, value: proxy.frame(in: .named("grouping-list")).minY)
                    }
                }
            }
            .scrollDisabled(liftedID != nil)

            TimelineView(.animation(paused: liftedID == nil)) { timeline in
                let displacement = position.sample(at: timeline.date).value
                let textOverlapsTarget = liftedTextOverlapsTarget(displacement: displacement)
                ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    // One view per original person survives lift, drop and composition changes.
                    ForEach(conversations) { person in
                        let portraitFrame = avatarFrame(person.id, displacement: displacement)
                        let angle = person.id == liftedID && !reduceMotion && !moving && !returning
                            ? sin(timeline.date.timeIntervalSince(liftedAt) * .pi * 8) * 0.8 : 0
                        let isCarrier = draft?.textSourceID == person.id
                        let displayItem = isCarrier ? draft!.preview : person
                        let textFrame = textFrame(person.id, displacement: displacement)
                        let collapsed = textOverlapsTarget && person.id == liftedID
                        let retired = draft?.memberIDs.contains(person.id) == true && !isCarrier
                        let origin = CGPoint(x: textFrame.minX - 91, y: textFrame.minY - 12)
                        let target = CGPoint(x: portraitFrame.midX - origin.x, y: portraitFrame.midY - origin.y)
                        GenieRowText(width: textFrame.width, target: target, collapsed: collapsed) {
                            ChatRowText(item: displayItem, isDraft: isCarrier, width: textFrame.width, angle: angle)
                        }
                            .opacity(textFrame.isEmpty || retired ? 0 : 1)
                            .animation(.easeOut(duration: 0.04), value: retired)
                            .position(x: origin.x + (textFrame.width + 91) / 2, y: origin.y + 43)
                            .zIndex(person.id == liftedID || isCarrier ? 11 : 0)
                    }
                }
                .foregroundStyle(.black).allowsHitTesting(false)
                .accessibilityElement(children: .ignore).accessibilityHidden(true)

                if let item = conversations.first(where: { $0.id == liftedID }) {
                    Color.clear.frame(width: width, height: 86).contentShape(Rectangle())
                        .offset(x: liftedFrame.minX + displacement.x, y: liftedFrame.minY + displacement.y)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("grouping-list"))
                            .onChanged { updateDrag($0) }.onEnded { finishDrag($0) })
                        .accessibilityLabel("Moving \(item.name)")
                        .accessibilityIdentifier("lifted-chat")
                        .accessibilityAction(.escape) { returnToOrigin(velocity: .zero) }
                        .zIndex(20)
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .clipped()
        .coordinateSpace(name: "grouping-list")
        .onPreferenceChange(ChatFramesKey.self) { frames = $0 }
        .onPreferenceChange(ScrollOriginKey.self) { value in
            withTransaction(Transaction(animation: nil)) { scrollOrigin = value }
        }
        .onAppear { publishAvatarPoses() }
        .onChange(of: frameDate) { publishAvatarPoses() }
        .onChange(of: rootOrigin) { publishAvatarPoses() }
        .onChange(of: scrollOrigin) { publishAvatarPoses() }
        .onChange(of: editProgress) { publishAvatarPoses() }
        .onChange(of: draft?.memberIDs) { publishAvatarPoses(animated: true) }
        .onChange(of: conversations.map(\.id)) { publishAvatarPoses(animated: true) }
        .onChange(of: search) { publishAvatarPoses() }
        .animation(spring, value: draft?.memberIDs)
        .animation(spring, value: composing)
        .onChange(of: cancelSignal) {
            returnTask?.cancel()
            withAnimation(spring) { liftedID = nil; hoveredID = nil; returning = false; moving = false; retiredTextFrames = [:] }
            publishAvatarPoses(animated: true)
        }
        .onChange(of: search) { if liftedID != nil { returnToOrigin(velocity: .zero) } }
        .onChange(of: reduceMotion, initial: true) { position.reduceMotion = reduceMotion }
        .sensoryFeedback(.impact(weight: .light), trigger: liftedID)
        .sensoryFeedback(.selection, trigger: hoveredID)
        .sensoryFeedback(.selection, trigger: draft?.members.count ?? 0)
        .sheet(item: $pickerSource) { source in
            NavigationStack {
                List(conversations.filter { candidate in
                    GroupDraft.merging(sourceID: source.id, targetID: candidate.id, conversations: conversations, current: draft) != nil
                }) { target in
                    Button(target.name) {
                        onBegin()
                        merge(source: source.id, target: target.id)
                        pickerSource = nil
                    }
                }
                .navigationTitle("Combine With").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pickerSource = nil } } }
            }
            .presentationDetents([.medium])
        }
        .onDisappear { returnTask?.cancel() }
    }

    @ViewBuilder private func listRow(_ item: Conversation) -> some View {
        if draft?.anchorID == item.id {
            decoratedRow(item)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("New Group")
                .accessibilityValue("\(item.members.count) people, group draft")
                .accessibilityIdentifier("conversation-\(item.id)")
                .accessibilityAction(named: Text("Create"), onCreate)
        } else {
            decoratedRow(item)
                .onTapGesture {
                    guard liftedID == nil else { return }
                    if composing && !item.isGroup { beginLift(item.id) }
                    else { onTap(item) }
                }
                .highPriorityGesture(holdGesture(item), including: item.isGroup ? .subviews : .all)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.name)
                .accessibilityValue(selected.contains(item.id) ? "Selected" : "")
                .accessibilityIdentifier("conversation-\(item.id)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTap(item) }
                .accessibilityActions {
                    if !item.isGroup { Button("Combine with another person") { pickerSource = item } }
                }
        }
    }

    private func decoratedRow(_ item: Conversation) -> some View {
        ConversationListRow(item: item, width: width, editProgress: composing ? 0 : editProgress,
                            selected: selected.contains(item.id), isDraft: draft?.anchorID == item.id,
                            hideMetadata: liftedID == item.id || hoveredID == item.id, createGroup: onCreate)
            .overlay {
                if hoveredID == item.id {
                    DropTargetOutline()
                        .padding(.horizontal, 8).allowsHitTesting(false)
                        .transition(.opacity.animation(.easeOut(duration: 0.04)))
                }
            }
            .transition(.opacity.animation(.easeOut(duration: 0.035)))
    }

    private func publishAvatarPoses(animated: Bool = false) {
        let poses = projectedAvatarPoses(displacement: position.sample(at: frameDate).value, at: frameDate)
        guard poses != presentedAvatars else { return }
        withAnimation(animated && !reduceMotion ? spring : nil) { presentedAvatars = poses }
    }

    private func projectedAvatarPoses(displacement: MotionVector, at date: Date) -> [Int: ListAvatarPose] {
        Dictionary(uniqueKeysWithValues: conversations.map { person in
            let frame = avatarFrame(person.id, displacement: displacement)
            let angle = person.id == liftedID && !reduceMotion && !moving && !returning
                ? sin(date.timeIntervalSince(liftedAt) * .pi * 8) * 0.8 : 0
            return (person.id, ListAvatarPose(frame: frame.offsetBy(dx: rootOrigin.x, dy: rootOrigin.y),
                                             angle: angle, raised: person.id == liftedID))
        })
    }

    private func avatarFrame(_ id: Int, displacement: MotionVector) -> CGRect {
        if id == liftedID {
            return CGRect(x: liftedFrame.minX + 16 + displacement.x,
                          y: liftedFrame.minY + 12 + displacement.y, width: 62, height: 62)
        }
        return GroupAvatarLayout.destination(personID: id, rowIDs: rows.map(\.id), draft: draft,
                                             editInset: composing ? 0 : 36 * editProgress, scrollOrigin: scrollOrigin)
    }

    private func textFrame(_ id: Int, displacement: MotionVector) -> CGRect {
        let isCarrier = draft?.textSourceID == id
        let rowID = isCarrier ? draft!.anchorID : id
        let inset = composing || isCarrier ? 0 : 36 * editProgress
        let textWidth = max(0, width - 120 - (isCarrier ? 78 : 52) - inset)
        if id == liftedID {
            return CGRect(x: liftedFrame.minX + 91 + displacement.x, y: liftedFrame.minY + 12 + displacement.y,
                          width: textWidth, height: 62)
        }
        // The dragged person's original title becomes the draft title at the same identity.
        if draft?.memberIDs.contains(id) == true && !isCarrier {
            return retiredTextFrames[id] ?? .zero
        }
        guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return .zero }
        return CGRect(x: 91 + inset, y: scrollOrigin + CGFloat(index) * 86.5 + 12, width: textWidth, height: 62)
    }

    private func liftedTextOverlapsTarget(displacement: MotionVector) -> Bool {
        guard let source = liftedID, moving, !returning else { return false }
        let sourceText = textFrame(source, displacement: displacement)
        return rows.contains { candidate in
            guard GroupDraft.merging(sourceID: source, targetID: candidate.id,
                                     conversations: conversations, current: draft) != nil else { return false }
            // An existing draft's visible text belongs to its original title carrier.
            let textID = draft?.anchorID == candidate.id ? draft!.textSourceID : candidate.id
            return sourceText.intersects(textFrame(textID, displacement: displacement))
        }
    }

    private func holdGesture(_ item: Conversation) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("grouping-list")))
            .onChanged { value in
                switch value {
                case .first: break
                case .second(true, let drag):
                    guard !item.isGroup else { return }
                    beginLift(item.id)
                    if let drag { updateDrag(drag) }
                default: break
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value, hypot(drag.translation.width, drag.translation.height) > 8 {
                    finishDrag(drag)
                }
            }
    }

    private func beginLift(_ id: Int) {
        guard liftedID == nil, draft?.memberIDs.contains(id) != true,
              let item = conversations.first(where: { $0.id == id }), !item.isGroup,
              let frame = frames[id] else { return }
        returnTask?.cancel()
        liftedFrame = frame
        liftedAt = .now
        moving = false
        returning = false
        position.reduceMotion = true
        position.move(to: .zero)
        position.reduceMotion = reduceMotion
        withAnimation(spring) { liftedID = id; onBegin() }
        publishAvatarPoses()
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard let source = liftedID else { return }
        if returning { returnTask?.cancel(); returning = false }
        moving = hypot(value.translation.width, value.translation.height) > 8
        withTransaction(Transaction(animation: nil)) { position.drag(by: value.translation) }
        hoveredID = frames.first { id, frame in
            frame.insetBy(dx: 0, dy: -4).contains(value.location) &&
            GroupDraft.merging(sourceID: source, targetID: id, conversations: conversations, current: draft) != nil
        }?.key
        publishAvatarPoses()
    }

    private func finishDrag(_ value: DragGesture.Value) {
        guard let source = liftedID else { return }
        updateDrag(value)
        if let target = hoveredID {
            merge(source: source, target: target)
        } else {
            returnToOrigin(velocity: value.velocity)
        }
    }

    private func merge(source: Int, target: Int) {
        guard let merged = GroupDraft.merging(sourceID: source, targetID: target, conversations: conversations, current: draft) else { return }
        returnTask?.cancel()
        let displacement = position.sample().value
        for id in merged.memberIDs where id != merged.textSourceID && retiredTextFrames[id] == nil {
            retiredTextFrames[id] = textFrame(id, displacement: displacement)
        }
        withAnimation(spring) {
            draft = merged
            liftedID = nil
            hoveredID = nil
            moving = false
        }
        publishAvatarPoses(animated: true)
    }

    private func returnToOrigin(velocity: CGSize) {
        guard liftedID != nil else { return }
        returnTask?.cancel()
        hoveredID = nil
        returning = true
        position.move(to: .zero, velocity: MotionVector(x: velocity.width, y: velocity.height))
        publishAvatarPoses()
        returnTask = Task { @MainActor in
            // Restore the source only after the live spring has actually settled.
            while !Task.isCancelled {
                let sample = position.sample()
                if hypot(sample.value.x, sample.value.y) < 0.25 && hypot(sample.velocity.x, sample.velocity.y) < 5 { break }
                try? await Task.sleep(for: .seconds(1.0 / 60))
            }
            guard !Task.isCancelled else { return }
            withAnimation(spring) { liftedID = nil; returning = false; moving = false }
            publishAvatarPoses()
        }
    }
}
