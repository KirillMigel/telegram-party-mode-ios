import SwiftUI

@main
struct LiquidChatsApp: App {
    var body: some Scene {
        WindowGroup { ChatsPrototype().preferredColorScheme(.light) }
    }
}

let appleBlue = Color(red: 0, green: 0.4784, blue: 1)
let telegramBlue = Color(red: 0, green: 0.62, blue: 0.96)

struct ChatsPrototype: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chatScrollEdge = ChatScrollEdgeLink()
    @State private var navigation = Motion(curveDuration: 0.48)
    @State private var navigationHeader = Motion(curveDuration: 0.48)
    @State private var headerPill = Motion(response: 0.58, dampingRatio: 0.64)
    @State private var nameEditingMotion = Motion(curveDuration: 0.46)
    @State private var nameTextMotion = Motion(curveDuration: 1.2, response: 0.22)
    @State private var profile = Motion()
    @State private var editMotion = Motion()
    @State private var conversations = Conversation.reference
    @State private var selectedChats: Set<Int> = []
    @State private var confirmDelete = false
    @State private var groupDraft: GroupDraft?
    @State private var composingGroup = false
    @State private var groupCancelSignal = 0
    @State private var conversation = Conversation.reference[0]
    @State private var chatIsOpen = false
    @State private var profileIsOpen = false
    @State private var profileControlFrames: [String: CGRect] = [:]
    @State private var search = ""
    @State private var draft = ""
    @State private var sentMessages: [String] = []
    @State private var partyGreetingCount = 0
    @State private var chatOpenedAt = Date.now
    @State private var muted = false
    @State private var largePhoto = false
    @State private var editing = false
    @State private var notice: String?
    @State private var namingGroup = false
    @State private var groupNameDraft = ""
    @State private var choosingGroupAvatar = false
    @State private var photoPickerMotion = Motion(response: 0.5, dampingRatio: 0.8)
    @State private var groupAvatars: [Int: Image] = [:]
    @State private var avatarReplacement: AvatarReplacement?
    @State private var avatarReplacementTask: Task<Void, Never>?
    @State private var avatarPoses: [Int: ListAvatarPose] = [:]
    @State private var groupButtonFrame = CGRect.zero
    @State private var avatarJourney: AvatarJourney?
    @State private var avatarTravel = Motion(curveDuration: 0.9)
    @State private var partyStarts: [Int: TimeInterval] = [:]
    @State private var partyLaunch: PartyLaunch?
    @State private var partyStartFrame = CGRect.zero
    @State private var welcomeStartedAt: TimeInterval?
    @State private var themeChoice = GroupThemeChoice()
    @State private var themeTransition: ThemeRippleTransition?
    @State private var orbitPhysics = PartyOrbitPhysics()
    @State private var stickerAttachments: [Int: PartyStickerAttachment] = [:]
    @State private var messageLayouts: [Int: PartyMessageLayout] = [:]
    @State private var speakingSince: [Int: TimeInterval] = [:]
    @State private var emojiBursts: [PartyEmojiBurst] = []
    @FocusState private var groupNameFocused: Bool
    @FocusState private var composerFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let top = proxy.safeAreaInsets.top
            let bottom = proxy.safeAreaInsets.bottom
            TimelineView(.animation(paused: emojiBursts.isEmpty && speakingSince.isEmpty && !navigation.isActive && !navigationHeader.isActive && !headerPill.isActive && !nameEditingMotion.isActive && !nameTextMotion.isActive && !photoPickerMotion.isActive && avatarReplacement == nil && !profile.isActive && !editMotion.isActive && !avatarTravel.isActive && !(chatIsOpen && !profileIsOpen && orbitPhysics.isActive) &&
                                    !avatarPoses.values.contains(where: { $0.raised }) &&
                                    !(avatarJourney != nil && chatIsOpen && !profileIsOpen && !reduceMotion))) { timeline in
                let chat = navigation.sample(at: timeline.date).value.progress.clamped
                let state = profile.sample(at: timeline.date).value
                let p = state.progress.clamped
                let partyEnabled = partyStarts[conversation.id] != nil
                #if DEBUG
                let partyTime = partyLaunch.map {
                    $0.startedAt + max(0, timeline.date.timeIntervalSinceReferenceDate-$0.startedAt) *
                        (ProcessInfo.processInfo.environment["LIQUID_PARTY_LAUNCH_SPEED"].flatMap(Double.init) ?? 1)
                } ?? timeline.date.timeIntervalSinceReferenceDate
                #else
                let partyTime = timeline.date.timeIntervalSinceReferenceDate
                #endif
                let launchAge = partyLaunch.map { max(0, partyTime-$0.startedAt) }
                let launchProgress = reduceMotion ? 1 : min(1, (launchAge ?? PartyLaunchMotion.duration)/PartyLaunchMotion.duration)
                let messageProgress = partyEnabled ? PartyLaunchMotion.messageProgress(time: launchAge, reduceMotion: reduceMotion) : 0
                let pickerProgress = photoPickerMotion.sample(at: timeline.date).value.progress
                let discoAge = partyStarts[conversation.id].map { max(0, timeline.date.timeIntervalSinceReferenceDate-$0) }
                let discoProgress = discoAge.map { reduceMotion ? 1 : ChatEasing.value(min(1, $0/0.6)) } ?? 0
                let card = groupButtonFrame.isEmpty
                    ? CGRect(x: (width-68)/2, y: top+92, width: 68, height: 68)
                    : groupButtonFrame.offsetBy(dx: reduceMotion ? 0 : -width*(1-chat), dy: 0)
                let launchPose = partyLaunch.map { PartyLaunchMotion.pose(time: launchAge ?? 0, source: $0.source, target: card, reduceMotion: reduceMotion) }
                let orbitTime = reduceMotion ? (avatarJourney?.startedAt ?? 0)+0.9 : timeline.date.timeIntervalSinceReferenceDate
                let stickerTime = max(0, partyTime-(welcomeStartedAt ?? 0))
                let avatarTargets: [PartyOrbitTarget] = avatarJourney.map { journey in
                    journey.members.indices.map { index in
                        let id = journey.members[index].id
                        let frame = journey.frame(for: index, progress: avatarTravel.sample(at: timeline.date).value.progress.clamped,
                                                  time: orbitTime, card: card, width: width)
                        let scale = PartyEmphasis.speakerScale(age: speakingSince[id].map { timeline.date.timeIntervalSinceReferenceDate-$0 }, reduceMotion: reduceMotion)
                        let size = frame.width * (1+(scale-1)*chat)
                        return PartyOrbitTarget(id: .avatar(id), frame: CGRect(x: frame.midX-size/2, y: frame.midY-size/2, width: size, height: size))
                    }
                } ?? []
                let stickerTargets: [PartyOrbitTarget] = partyEnabled ? (0..<WelcomeBurst.count).compactMap { index in
                    guard stickerAttachments[index] == nil else { return nil }
                    let pose = WelcomeBurst.sticker(index, time: reduceMotion ? 4 : stickerTime, card: card, width: width)
                    guard pose.opacity > 0 else { return nil }
                    let size = pose.size*1.25
                    return PartyOrbitTarget(id: .sticker(index), frame: CGRect(x: pose.center.x-size/2, y: pose.center.y-size/2, width: size, height: size))
                } : []
                let orbitTargets = avatarTargets+stickerTargets
                let orbitReady = chat > 0.99 && avatarTravel.sample(at: timeline.date).value.progress > 0.99
                let canDragOrbit = chatIsOpen && orbitReady && !profileIsOpen && !choosingGroupAvatar
                let avatarOrbitFrames = Dictionary(uniqueKeysWithValues: avatarTargets.compactMap { target -> (Int, CGRect)? in
                    guard case let .avatar(id) = target.id else { return nil }
                    return (id, orbitPhysics.frame(target, weight: CGFloat(chat*avatarTravel.sample(at: timeline.date).value.progress.clamped)))
                })
                let stickerOrbitFrames = Dictionary(uniqueKeysWithValues: stickerTargets.compactMap { target -> (Int, CGRect)? in
                    guard case let .sticker(id) = target.id else { return nil }
                    return (id, orbitPhysics.frame(target))
                })
                ZStack(alignment: .topLeading) {
                    chatList(width: width, top: top, bottom: bottom, editProgress: editMotion.sample(at: timeline.date).value.progress.clamped,
                             navigationProgress: chat, frameDate: timeline.date)
                        .offset(x: reduceMotion ? 0 : -width * 0.25 * chat)
                        .opacity(reduceMotion ? 1 - chat : 1)
                        .allowsHitTesting(!chatIsOpen)
                        .accessibilityHidden(chatIsOpen)

                    if chatIsOpen || chat > 0.001 {
                        chatScreen(top: top, bottom: bottom, width: width, height: height, partyEnabled: partyEnabled, launchProgress: launchProgress, messageProgress: messageProgress,
                                   bannerOffsetX: reduceMotion ? 0 : -(width/2-90)*(headerPill.sample(at: timeline.date).value.progress-chat),
                                   time: timeline.date.timeIntervalSinceReferenceDate,
                                   celebrate: { id in celebrate(id, avatarFrames: avatarOrbitFrames) })
                            .background {
                                ZStack {
                                    ChatPhotoBackdrop(conversation: conversation, theme: themeChoice.visible(groupID: conversation.id),
                                                      transition: themeTransition, time: timeline.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion)
                                        .layerEffect(ShaderLibrary.partyRipple(.float2(Float(card.midX), Float(card.midY)),
                                                                              .float2(Float(width), Float(height)),
                                                                              .float(Float(discoAge ?? 0))),
                                                     maxSampleOffset: CGSize(width: 8, height: 8),
                                                     isEnabled: discoAge != nil && !reduceMotion && !profileIsOpen)
                                    if discoAge != nil && !profileIsOpen {
                                        DiscoLights(time: discoAge ?? 0, center: launchPose?.center ?? CGPoint(x: card.midX, y: card.midY),
                                                    reduceMotion: reduceMotion).opacity(discoProgress*(1-p)*(launchPose?.iconReveal ?? 1))
                                    }

                                }
                            }
                            .overlay(alignment: .topLeading) {
                                Color.clear.frame(width: 24).contentShape(Rectangle())
                                    .gesture(chatBackGesture(width: width))
                                    .accessibilityHidden(true)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: reduceMotion ? 0 : 46, style: .continuous))
                            .offset(x: reduceMotion ? 0 : width * (1 - chat))
                            .opacity(reduceMotion ? chat : 1)
                            .allowsHitTesting(!profileIsOpen && !choosingGroupAvatar)
                            .accessibilityHidden(profileIsOpen || choosingGroupAvatar)

                        if profileIsOpen || p > 0.001 {
                            profileScene(width: width, height: height, top: top, bottom: bottom,
                                         state: state, progress: p)
                                .opacity(reduceMotion ? p : 1)
                                .allowsHitTesting(profileIsOpen)
                                .accessibilityHidden(!profileIsOpen)
                        }
                    }
                    if !conversation.members.isEmpty && partyEnabled && (chatIsOpen || chat > 0.001) {
                        GroupWelcomeStickers(time: stickerTime, card: card, width: width, height: height,
                                             reduceMotion: reduceMotion, frames: stickerOrbitFrames, attached: Set(stickerAttachments.keys), canDrag: canDragOrbit,
                                             moveSticker: { id, value in moveOrbitBody(.sticker(id), value: value, targets: orbitTargets, width: width, height: height) },
                                             releaseSticker: { id, value in releaseSticker(id, value: value, top: top, height: height, bottom: bottom) })
                            .id(conversation.id).opacity(chat*(1-p))
                    }
                    ChatAvatarLayer(poses: avatarPoses, conversations: conversations, journey: avatarJourney,
                                    travel: avatarTravel.sample(at: timeline.date).value.progress.clamped,
                                    navigation: chat, profile: p,
                                    card: card,
                                    time: reduceMotion ? (avatarJourney?.startedAt ?? 0) + 0.9 : timeline.date.timeIntervalSinceReferenceDate,
                                    width: width, height: height, composingMembers: groupDraft?.memberIDs ?? [],
                                    orbitFrames: avatarOrbitFrames, canDrag: canDragOrbit,
                                    moveAvatar: { id, value in moveOrbitBody(.avatar(id), value: value, targets: orbitTargets, width: width, height: height) },
                                    releaseAvatar: { id, value in orbitPhysics.release(.avatar(id), velocity: .init(dx: value.velocity.width, dy: value.velocity.height), reduceMotion: reduceMotion) })
                        .opacity(1-p)
                    if !conversation.members.isEmpty && (chatIsOpen || chat > 0.001) {
                        GroupWelcomeScene(time: max(0, partyTime - (welcomeStartedAt ?? avatarJourney?.startedAt ?? 0)),
                                          card: card, width: width, height: height, reduceMotion: reduceMotion,
                                          nameIsSet: conversation.groupNameSet,
                                          hasCustomAvatar: groupAvatars[conversation.id] != nil,
                                          partyIsStarted: partyEnabled,
                                          launchPose: launchPose,
                                          isLoadingAvatar: avatarReplacement != nil,
                                          photoPickerProgress: pickerProgress,
                                          discoTime: discoAge ?? 0, setName: advanceGroupOnboarding)
                            .id(conversation.id)
                            .offset(x: reduceMotion ? 0 : width*(1-chat))
                            .opacity(chat*(1-p))
                            .allowsHitTesting(chatIsOpen && !profileIsOpen && !choosingGroupAvatar)
                            .accessibilityHidden(!chatIsOpen || profileIsOpen || choosingGroupAvatar)
                    }
                    ChatScrollEdgeBar(link: chatScrollEdge, active: chat > 0.001 && !profileIsOpen,
                                      excludedHitRects: profileIsOpen ? Array(profileControlFrames.values) : []) {
                        sharedHeader(width: width, height: height, top: top, state: state, progress: p,
                                     navigationProgress: navigationHeader.sample(at: timeline.date).value.progress.clamped,
                                     pillProgress: headerPill.sample(at: timeline.date).value.progress,
                                     namingProgress: nameEditingMotion.sample(at: timeline.date).value.progress.clamped,
                                     nameTextProgress: nameTextMotion.sample(at: timeline.date).value.progress.clamped,
                                     avatarReplacementProgress: avatarReplacement?.progress(at: timeline.date) ?? 0,
                                     editProgress: editMotion.sample(at: timeline.date).value.progress.clamped)
                            .allowsHitTesting(!choosingGroupAvatar)
                            .accessibilityHidden(choosingGroupAvatar)
                    }
                    .frame(width: width, height: height, alignment: .topLeading)
                    if let selectedTheme = themeChoice.draft, chatIsOpen && !profileIsOpen {
                        PortalThemePicker(selected: selectedTheme,
                                          isTransitioning: (themeTransition?.age(at: timeline.date.timeIntervalSinceReferenceDate) ?? 2) < ThemeRippleTransition.revealDuration,
                                          choose: previewGroupTheme, save: saveGroupTheme,
                                          cancel: { themeChoice.cancel(); themeTransition = nil })
                            .frame(width: width)
                            .position(x: card.midX, y: top+196)
                            .frame(width: width, height: height, alignment: .topLeading)
                    }
                    if !conversation.members.isEmpty && conversation.groupNameSet && (chatIsOpen || chat > 0.001) {
                        PortalPhotoPicker(isPresented: choosingGroupAvatar,
                                          progress: pickerProgress, source: card, width: width, height: height,
                                          top: top, bottom: bottom, reduceMotion: reduceMotion, close: closeGroupPhotoPicker,
                                          select: { image in
                                              guard choosingGroupAvatar, chatIsOpen else { return }
                                              let groupID = conversation.id
                                              closeGroupPhotoPicker()
                                              replaceGroupAvatar(Image(uiImage: image), groupID: groupID)
                                          })
                    }
                    if let avatarReplacement, chatIsOpen, avatarReplacement.groupID == conversation.id {
                        AvatarReplacementLayer(replacement: avatarReplacement, date: timeline.date,
                                               source: card, target: CGRect(x: width-53, y: top+6, width: 40, height: 40),
                                               width: width, height: height)
                            .opacity(1-p)
                    }
                    if chatIsOpen && !emojiBursts.isEmpty {
                        PartyEmojiShower(bursts: emojiBursts, time: timeline.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion)
                            .frame(width: width, height: height)
                    }
                }
                .frame(width: width, height: height)
                .coordinateSpace(name: "chats-root")
                .clipped()
                .onPreferenceChange(PartyMessageLayoutKey.self) { messageLayouts = $0 }
                .onChange(of: timeline.date, initial: true) {
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    emojiBursts.removeAll { $0.age(at: now) >= PartyEmojiBurst.duration }
                    speakingSince = speakingSince.filter { now-$0.value < PartyEmphasis.speakingDuration }
                    guard orbitReady, !profileIsOpen else { return }
                    orbitPhysics.update(time: timeline.date.timeIntervalSinceReferenceDate, targets: orbitTargets,
                                        collisions: orbitPhysics.drag != nil && (!partyEnabled || stickerTime > 3), reduceMotion: reduceMotion)
                }
            }
            .ignoresSafeArea()
        }
        // Group controls share fixed coordinates; their raised composer already sits above the keyboard.
        .ignoresSafeArea(.keyboard, edges: conversation.members.isEmpty ? [] : .bottom)
        .onChange(of: reduceMotion, initial: true) {
            navigation.reduceMotion = reduceMotion
            navigationHeader.reduceMotion = reduceMotion
            headerPill.reduceMotion = reduceMotion
            nameEditingMotion.reduceMotion = reduceMotion
            nameTextMotion.reduceMotion = reduceMotion
            profile.reduceMotion = reduceMotion
            editMotion.reduceMotion = reduceMotion
            avatarTravel.reduceMotion = reduceMotion
            photoPickerMotion.reduceMotion = reduceMotion
            if reduceMotion { finishAvatarReplacement() }
        }
        .confirmationDialog("Delete selected chats?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { removeSelectedChats() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes them from the local prototype.") }
        .alert("Prototype", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .task(id: chatIsOpen ? conversation.id : nil) {
            guard chatIsOpen, !conversation.members.isEmpty else { return }
            let groupID = conversation.id
            for index in conversation.members.indices {
                speakingSince[conversation.members[index].id] = Date.now.timeIntervalSinceReferenceDate
                do { try await Task.sleep(for: .seconds(index == 0 ? 0.8 : 0.75)) }
                catch { return }
                guard !Task.isCancelled, chatIsOpen, conversation.id == groupID else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.24)) {
                    partyGreetingCount = index+1
                }
            }
        }
    }

    private func openGroupPhotoPicker() {
        guard avatarReplacement == nil else { return }
        composerFocused = false
        choosingGroupAvatar = true
        photoPickerMotion.move(to: MotionVector(progress: 1))
    }

    private func closeGroupPhotoPicker() {
        choosingGroupAvatar = false
        photoPickerMotion.move(to: .zero)
    }

    private func beginGroupNameEditing() {
        guard !namingGroup else { groupNameFocused = true; return }
        composerFocused = false
        groupNameDraft = conversation.groupNameSet ? conversation.name : ""
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.35, dampingFraction: 0.8)) {
            namingGroup = true
        }
        nameEditingMotion.move(to: MotionVector(progress: 1))
        nameTextMotion.move(to: MotionVector(progress: 1))
    }

    private func cancelGroupNameEditing() {
        groupNameFocused = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.35, dampingFraction: 0.8)) {
            namingGroup = false
        }
        groupNameDraft = ""
        nameEditingMotion.move(to: .zero)
        nameTextMotion.move(to: .zero, velocity: .zero)
    }

    private func saveGroupName() {
        let name = groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        conversation.name = name
        conversation.groupNameSet = true
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) { conversations[index] = conversation }
        groupNameFocused = false
        // Save places the entered title directly above the member count; only the controls morph back.
        nameTextMotion.reduceMotion = true
        nameTextMotion.move(to: .zero)
        nameTextMotion.reduceMotion = reduceMotion
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            namingGroup = false
            groupNameDraft = ""
        }
        nameEditingMotion.move(to: .zero)
    }

    private var conversationAvatar: Image {
        if !conversation.members.isEmpty, let image = groupAvatars[conversation.id] { return image }
        return Image(conversation.members.isEmpty ? conversation.avatar : "group-avatar")
    }

    private func replaceGroupAvatar(_ image: Image, groupID: Int) {
        finishAvatarReplacement()
        guard !reduceMotion, chatIsOpen, !profileIsOpen, conversation.id == groupID else {
            groupAvatars[groupID] = image
            return
        }
        let replacement = AvatarReplacement(groupID: groupID, image: image, startedAt: .now)
        avatarReplacement = replacement
        #if DEBUG
        if ProcessInfo.processInfo.environment["LIQUID_AVATAR_TRANSFER_FRAME"] != nil { return }
        #endif
        avatarReplacementTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AvatarTransferMotion.duration))
            guard !Task.isCancelled, avatarReplacement?.id == replacement.id else { return }
            finishAvatarReplacement()
        }
    }

    private func finishAvatarReplacement() {
        avatarReplacementTask?.cancel()
        avatarReplacementTask = nil
        guard let replacement = avatarReplacement else { return }
        groupAvatars[replacement.groupID] = replacement.image
        avatarReplacement = nil
    }

    private func startParty() {
        guard !conversation.members.isEmpty, partyStarts[conversation.id] == nil else { return }
        composerFocused = false
        let now = Date.now.timeIntervalSinceReferenceDate
        let source = partyStartFrame.isEmpty ? groupButtonFrame.offsetBy(dx: 80, dy: 400) : partyStartFrame
        partyLaunch = PartyLaunch(source: source, startedAt: now)
        partyStarts[conversation.id] = now
        welcomeStartedAt = now + (reduceMotion ? 0 : PartyLaunchMotion.duration) - PartyLaunchMotion.burstLead
    }

    private func openChat(_ item: Conversation) {
        themeChoice.cancel()
        themeTransition = nil
        orbitPhysics = PartyOrbitPhysics()
        stickerAttachments = [:]
        messageLayouts = [:]
        speakingSince = [:]
        emojiBursts = []
        finishAvatarReplacement()
        partyLaunch = nil
        partyStartFrame = .zero
        welcomeStartedAt = partyStarts[item.id].map { $0+PartyLaunchMotion.duration-PartyLaunchMotion.burstLead }
        if !item.members.isEmpty {
            var origins: [Int: CGRect] = [:]
            if groupDraft != nil {
                for member in item.members { origins[member.id] = avatarPoses[member.id]?.frame }
            } else if let groupFrame = avatarPoses[item.id]?.frame {
                for (index, slot) in GroupAvatarLayout.frames(count: item.members.count).enumerated() {
                    origins[item.members[index].id] = slot.offsetBy(dx: groupFrame.minX, dy: groupFrame.minY)
                }
            }
            avatarJourney = AvatarJourney(groupID: item.id, members: item.members, origins: origins,
                                          startedAt: Date.now.timeIntervalSinceReferenceDate)
            avatarTravel.reduceMotion = true
            avatarTravel.move(to: .zero)
            avatarTravel.reduceMotion = reduceMotion
            avatarTravel.move(to: MotionVector(progress: 1))
        } else { avatarJourney = nil }
        conversation = item
        searchFocused = false
        sentMessages = []
        partyGreetingCount = 0
        chatOpenedAt = .now
        chatIsOpen = true
        navigation.move(to: MotionVector(progress: 1))
        navigationHeader.move(to: MotionVector(progress: 1), delay: 0.12)
        headerPill.move(to: MotionVector(progress: 1), delay: 0.12)
    }

    private func advanceGroupOnboarding() {
        if !conversation.groupNameSet { beginGroupNameEditing() }
        else if groupAvatars[conversation.id] == nil { openGroupPhotoPicker() }
        else {
            composerFocused = false
            themeChoice.begin(groupID: conversation.id)
        }
    }

    private func moveOrbitBody(_ id: PartyBodyID, value: DragGesture.Value, targets: [PartyOrbitTarget], width: CGFloat, height: CGFloat) {
        guard let target = targets.first(where: { $0.id == id }) else { return }
        let location = CGPoint(x: min(width-12, max(12, value.location.x)), y: min(height-12, max(12, value.location.y)))
        orbitPhysics.move(id, target: target.frame, start: value.startLocation, location: location,
                          velocity: .init(dx: value.velocity.width, dy: value.velocity.height))
    }

    private func releaseSticker(_ id: Int, value: DragGesture.Value, top: CGFloat, height: CGFloat, bottom: CGFloat) {
        let center = orbitPhysics.drag?.center ?? value.location
        let messageBottom = height-ChatComposerLayout.bottomInset(height: height, safeBottom: bottom, group: true)-58
        if center.y > top+228, center.y < messageBottom,
           let attachment = PartyStickerAttachment.drop(at: center, messages: messageLayouts.mapValues(\.bubble)) {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.28)) { stickerAttachments[id] = attachment }
            orbitPhysics.release(.sticker(id), velocity: .zero, reduceMotion: true)
        } else {
            orbitPhysics.release(.sticker(id), velocity: .init(dx: value.velocity.width, dy: value.velocity.height), reduceMotion: reduceMotion)
        }
    }

    private func celebrate(_ id: Int, avatarFrames: [Int: CGRect]) {
        guard let rect = avatarFrames[id] ?? messageLayouts[id]?.avatar, !rect.isEmpty else { return }
        let now = Date.now.timeIntervalSinceReferenceDate
        speakingSince[id] = now
        emojiBursts = Array(emojiBursts.suffix(2)) + [PartyEmojiBurst(origin: CGPoint(x: rect.midX, y: rect.midY), startedAt: now)]
    }

    private func previewGroupTheme(_ theme: ChatTheme, origin: CGPoint) {
        let now = Date.now.timeIntervalSinceReferenceDate
        guard (themeTransition?.age(at: now) ?? 2) >= ThemeRippleTransition.revealDuration else { return }
        let old = themeChoice.visible(groupID: conversation.id)
        themeChoice.preview(theme)
        if old != theme {
            themeTransition = ThemeRippleTransition(from: old, to: theme, origin: origin, startedAt: now)
        }
    }

    private func saveGroupTheme() {
        _ = themeChoice.save(groupID: conversation.id)
    }

    private func closeChat() {
        themeChoice.cancel()
        themeTransition = nil
        closeGroupPhotoPicker()
        finishAvatarReplacement()
        if namingGroup { cancelGroupNameEditing() }
        composerFocused = false
        emojiBursts = []
        speakingSince = [:]
        chatIsOpen = false
        navigation.move(to: .zero)
        navigationHeader.move(to: .zero)
        headerPill.move(to: .zero)
        avatarTravel.move(to: .zero)
        finishAvatarReturn()
    }

    private func finishAvatarReturn() {
        Task { @MainActor in
            while !chatIsOpen && avatarTravel.sample().value.progress > 0.001 {
                try? await Task.sleep(for: .seconds(1.0/60))
            }
            if !chatIsOpen { avatarJourney = nil }
        }
    }

    private func openProfile() {
        finishAvatarReplacement()
        composerFocused = false
        largePhoto = false
        profileIsOpen = true
        profile.move(to: MotionVector(progress: 1))
    }

    private func closeProfile(velocity: CGSize? = nil) {
        profileIsOpen = false
        profile.move(to: .zero, velocity: velocity.map { MotionVector(x: $0.width, y: $0.height) })
    }

    private func setEditing(_ value: Bool) {
        searchFocused = false
        if value { selectedChats.removeAll() }
        if !value {
            withAnimation(.spring(response: 0.4, dampingFraction: 1)) { groupDraft = nil; composingGroup = false }
            groupCancelSignal += 1
        }
        editing = value
        editMotion.move(to: MotionVector(progress: value ? 1 : 0))
    }

    private func removeSelectedChats() {
        conversations.removeAll { selectedChats.contains($0.id) }
        setEditing(false)
    }

    private func readSelectedChats() {
        for index in conversations.indices where selectedChats.isEmpty || selectedChats.contains(conversations[index].id) {
            conversations[index].unread = 0
        }
        setEditing(false)
    }

    private func chatList(width: CGFloat, top: CGFloat, bottom: CGFloat, editProgress e: Double, navigationProgress chat: Double, frameDate: Date) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 44)
                .overlay {
                    HStack(spacing: 5) {
                        Text("Chats")
                        Image(systemName: "star.fill").foregroundStyle(telegramBlue).accessibilityHidden(true)
                    }
                    .font(.system(size: 17, weight: .semibold)).fixedSize()
                    .opacity(1 - stage(chat, from: 0.45, to: 0.75))
                    .accessibilityElement(children: .ignore).accessibilityLabel("Chats")
                }
                .padding(.top, top + 8).padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search", text: $search).autocorrectionDisabled().focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .font(.system(size: 17)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color(.sRGB, white: 0.94, opacity: 1), in: Capsule())
            .padding(.horizontal, 16).padding(.bottom, 12)

            GroupingChatList(conversations: $conversations, draft: $groupDraft, presentedAvatars: $avatarPoses, width: width, search: search,
                             rootOrigin: CGPoint(x: reduceMotion ? 0 : -width*0.25*chat, y: top+120),
                             frameDate: frameDate,
                             editProgress: e, composing: composingGroup, cancelSignal: groupCancelSignal,
                             selected: selectedChats, onTap: { item in
                if editing {
                    if selectedChats.contains(item.id) { selectedChats.remove(item.id) }
                    else { selectedChats.insert(item.id) }
                } else { openChat(item) }
            }, onBegin: {
                selectedChats.removeAll()
                composingGroup = true
                searchFocused = false
            }, onCreate: {
                guard let groupDraft else { return }
                let createdConversations = groupDraft.creating(in: conversations)
                guard let created = createdConversations.first(where: { $0.id == groupDraft.anchorID }) else { return }
                openChat(created)
                // Keep the outgoing composition intact until the new screen covers it.
                Task { @MainActor in
                    while chatIsOpen && navigation.sample().value.progress < 0.995 {
                        try? await Task.sleep(for: .seconds(1.0 / 60))
                    }
                    conversations = createdConversations
                    self.groupDraft = nil
                    setEditing(false)
                }
            })
            Color.clear.frame(height: max(12, bottom))
        }
        .background(.white)
        .overlay(alignment: .bottom) {
            if !composingGroup && (editing || e > 0.001) {
                editActions(bottom: bottom)
                    .opacity(e).offset(y: reduceMotion ? 0 : 80 * (1 - e))
                    .allowsHitTesting(editing).accessibilityHidden(!editing)
            }
        }
    }

    private func editActions(bottom: CGFloat) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(selectedChats.isEmpty ? "Read All" : "Read", action: readSelectedChats)
                    .padding(.horizontal, 18).frame(height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
                Button("Archive", action: removeSelectedChats)
                    .padding(.horizontal, 18).frame(height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .disabled(selectedChats.isEmpty)
                Button("Delete", role: .destructive) { confirmDelete = true }
                    .padding(.horizontal, 18).frame(height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .disabled(selectedChats.isEmpty)
            }
            .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16).padding(.bottom, max(bottom, 12))
    }

    private func chatScreen(top: CGFloat, bottom: CGFloat, width: CGFloat, height: CGFloat,
                            partyEnabled: Bool, launchProgress: Double, messageProgress: Double, bannerOffsetX: CGFloat,
                            time: TimeInterval, celebrate: @escaping (Int) -> Void) -> some View {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupMessages = !conversation.members.isEmpty
        let bannerVisible = messageProgress < 1
        return VStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 7) {
                        if conversation.members.isEmpty {
                        dateLabel("Yesterday").padding(.top, 150)
                        bubble("Did you see the new exhibition? 🖼️", time: "18:02")
                        bubble("Not yet! Is it worth it?", time: "18:03", outgoing: true)
                        bubble("Totally. The light installations are magic ✨", time: "18:04")
                        bubble("Let's go this weekend", time: "18:05", outgoing: true)
                        bubble("Deal 🤝", time: "18:11")
                        bubble("Hey! Are you free tonight? 🌇", time: "12:38")
                        bubble("Sunset spot at 7? I'll bring the camera", time: "12:41")
                        } else {
                            ForEach(Array(conversation.members.prefix(partyGreetingCount).enumerated()), id: \.element.id) { index, member in
                                PartyMessage(member: member, index: index, date: chatOpenedAt,
                                             speakerScale: PartyEmphasis.speakerScale(age: speakingSince[member.id].map { time-$0 }, reduceMotion: reduceMotion),
                                             attachments: stickerAttachments, celebrate: { celebrate(member.id) },
                                             returnSticker: { stickerAttachments[$0] = nil })
                                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                            }
                        }
                        ForEach(Array(sentMessages.enumerated()), id: \.offset) { index, message in
                            bubble(message, time: "now", outgoing: true).id(index)
                        }
                        Color.clear.frame(height: groupMessages ? 24-23*messageProgress : 1).id("bottom")
                    }
                    .padding(.horizontal, 10).padding(.bottom, groupMessages ? 16-12*messageProgress : 16)
                    .visualEffect { content, geometry in
                        content.layerEffect(ShaderLibrary.messageEdgeBlur(
                            .float(Float(top+158+62*messageProgress-geometry.frame(in: .named("chats-root")).minY))),
                                            maxSampleOffset: CGSize(width: 8, height: 8), isEnabled: groupMessages)
                    }
                    .background { ChatScrollEdgeRegistration(link: chatScrollEdge) }
                }
                .contentMargins(.top, conversation.members.isEmpty ? top+52 : 0, for: .scrollContent)
                .safeAreaBar(edge: .top, spacing: 0) {
                    if !conversation.members.isEmpty {
                        // The banner needs message space before Start; keep the orbit anchor fixed.
                        ZStack(alignment: .topLeading) {
                            GroupWelcomeAnchor(buttonFrame: $groupButtonFrame)
                                .id(conversation.id).padding(.top, top+88).padding(.bottom, 8)
                        }
                        .frame(width: width, height: top+186+60*messageProgress, alignment: .topLeading)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .defaultScrollAnchor(groupMessages ? .bottom : nil, for: .sizeChanges)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: sentMessages.count) {
                    withAnimation(.smooth) { reader.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: partyGreetingCount) {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                        reader.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            if groupMessages && bannerVisible {
                PartyBannerSpace(progress: messageProgress) {
                PartyStartBanner(startFrame: $partyStartFrame, start: startParty)
                    .offset(x: bannerOffsetX)
                    .padding(.horizontal, 12).padding(.bottom, 10)
                    .opacity(partyEnabled ? 1-ChatEasing.value(min(1, launchProgress*5)) : 1)
                    .scaleEffect(partyEnabled && !reduceMotion ? 1-0.06*min(1, launchProgress*5) : 1, anchor: .bottomTrailing)
                    .allowsHitTesting(!partyEnabled)
                    .accessibilityHidden(partyEnabled)
                }
            }

            HStack(spacing: 10) {
                glassButton("paperclip", label: "Attach file") {
                    notice = "Attachments aren't connected in this local prototype."
                }
                TextField("Message", text: $draft, axis: .vertical)
                    .focused($composerFocused).lineLimit(1...4)
                    .padding(.horizontal, 15).padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())
                    .accessibilityIdentifier("message-input")
                Button {
                    guard !message.isEmpty else {
                        notice = "Voice messages aren't connected in this local prototype."
                        return
                    }
                    sentMessages.append(message)
                    draft = ""
                } label: {
                    Group {
                        if message.isEmpty {
                            Image("composer-microphone").resizable().scaledToFit()
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up").font(.system(size: 19, weight: .semibold))
                        }
                    }
                    .frame(width: 40, height: 40).foregroundStyle(.primary)
                }
                .buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(message.isEmpty ? "Record voice message" : "Send message")
                .accessibilityIdentifier("composer-action")
            }
            .padding(.horizontal, 12).padding(.top, 8)
            .padding(.bottom, ChatComposerLayout.bottomInset(height: height, safeBottom: bottom, group: !conversation.members.isEmpty))
        }
    }

    private func profileScene(width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat,
                              state: MotionVector, progress p: Double) -> some View {
        let shrink = reduceMotion ? 1 : max(0.68, 1 - hypot(state.x, state.y) / 1400)
        let size = CGSize(width: mix(34, width, p) * shrink, height: mix(34, height, p) * shrink)
        let origin = CGPoint(x: mix(width - 50, 0, p) + (reduceMotion ? 0 : state.x),
                             y: mix(top + 9, 0, p) + (reduceMotion ? 0 : state.y))
        let radius = mix(17, min(48, hypot(state.x, state.y) * 0.4), p)
        return ZStack(alignment: .topLeading) {
            Color.clear
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            profileContent(width: width, top: top, bottom: bottom)
                .frame(width: width, height: height)
                .background { Wallpaper(purple: true) }
                .opacity(min(1, p * 2.5))
                .scaleEffect(x: size.width / width, y: size.height / height, anchor: .topLeading)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .offset(x: origin.x, y: origin.y)
        .gesture(profileDismissGesture)
        .accessibilityAction(.escape) { closeProfile() }
    }

    private func profileContent(width: CGFloat, top: CGFloat, bottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                glassButton("chevron.left", label: "Close profile") { closeProfile() }
                    .background { profileControlFrame("close") }
                Spacer()
                Button("Edit") { notice = "Profile editing isn't connected in this local prototype." }
                    .font(.system(size: 15)).padding(.horizontal, 15).frame(height: 36)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .background { profileControlFrame("edit") }
            }
            .padding(.horizontal, 14).frame(height: 48).padding(.top, top)
            Color.clear.frame(height: largePhoto ? (width - 32) * 0.85 + 65 : 108)
            Text("♫ Stayin' Alive · Bee Gees").font(.system(size: 11))
                .padding(.horizontal, 11).padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule()).padding(.top, 8)
            HStack(spacing: 26) {
                profileAction("phone.fill", "call") {
                    notice = "Calls aren't connected in this local prototype."
                }
                profileAction(muted ? "bell.slash.fill" : "bell.fill", muted ? "unmute" : "mute") { muted.toggle() }
                profileAction("magnifyingglass", "search") {
                    closeProfile(); notice = "Chat search isn't connected in this local prototype."
                }
                Menu {
                    Button("Close profile", systemImage: "xmark") { closeProfile() }
                    Button(largePhoto ? "Small photo" : "Large photo", systemImage: "photo") {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.94)) { largePhoto.toggle() }
                    }
                } label: { actionLabel("ellipsis", "more") }
            }
            .padding(.vertical, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if conversation.members.isEmpty {
                        infoRow("mobile", "+1 555 010 0123")
                        infoRow("username", "@" + String(conversation.name.split(separator: " ").first ?? "").lowercased())
                        infoRow("date of birth", "1 Jan 2000 (25 years old)")
                    } else {
                        ForEach(conversation.members) { member in infoRow("member", member.name) }
                    }
                }
                .padding(.horizontal, 16).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 16)
                Text("Swipe down or right to return to the chat.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).padding(.top, 24)
            }
            .padding(.bottom, bottom)
        }
        .foregroundStyle(.white)
    }

    private func profileControlFrame(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.onChange(of: proxy.frame(in: .named("chats-root")), initial: true) {
                let frame = proxy.frame(in: .named("chats-root"))
                if !frame.isEmpty && profileControlFrames[id] != frame { profileControlFrames[id] = frame }
            }
        }
    }

    private func sharedHeader(width: CGFloat, height: CGFloat, top: CGFloat, state: MotionVector, progress p: Double,
                              navigationProgress chat: Double, pillProgress pillMorph: Double,
                              namingProgress nameMorph: Double, nameTextProgress sampledTextMorph: Double,
                              avatarReplacementProgress replacementProgress: Double,
                              editProgress e: Double) -> some View {
        #if DEBUG
        let textMorph = ProcessInfo.processInfo.environment["LIQUID_HEADER_TEXT_FRAME"].flatMap(Double.init)?.clamped ?? sampledTextMorph
        #else
        let textMorph = sampledTextMorph
        #endif
        let avatarMorph = chat
        let titleReveal = stage(chat, from: 0.78, to: 1)
        let iconFade = stage(chat, from: 0.05, to: 0.45)
        let backReveal = stage(chat, from: 0.7, to: 0.98)
        let shrink = reduceMotion ? 1 : max(0.68, 1 - hypot(state.x, state.y) / 1400)
        let originX = mix(width - 50, 0, p) + (reduceMotion ? 0 : state.x)
        let originY = mix(top + 9, 0, p) + (reduceMotion ? 0 : state.y)
        let scaleX = mix(34 / width, 1, p) * shrink
        let scaleY = mix(34 / height, 1, p) * shrink
        let chatAvatarDiameter: CGFloat = conversation.members.isEmpty ? 38 : 40
        let avatarSize = mix(mix(mix(44, chatAvatarDiameter, avatarMorph), largePhoto ? width - 32 : 82, p) * shrink, 44, nameMorph)
        let avatarButtonSize = mix(44, avatarSize, p)
        let avatarX = mix(mix(width - 38, width - 33, avatarMorph), originX + width / 2 * scaleX, p)
        let photoHeight = (width - 32) * 0.85
        let avatarY = mix(mix(top + 30, top + 26, avatarMorph), originY + (top + (largePhoto ? 56 + photoHeight / 2 : 66)) * scaleY, p)
        let titleX = mix(mix(width - 90, width / 2, pillMorph), originX + width / 2 * scaleX, p)
        let titleY = mix(mix(top + 30, top + 25, pillMorph), originY + (top + (largePhoto ? 88 + photoHeight : 133)) * scaleY, p)
        let headerName = conversation.name + (conversation.avatar == "alicia" && conversation.members.isEmpty ? " 🏅" : "")
        let titleFont = UIFont.systemFont(ofSize: conversation.members.isEmpty ? 14 : 15, weight: .semibold)
        let titleWidth = min(width - 132, max(128, (headerName as NSString).size(withAttributes: [.font: titleFont]).width + 32))
        let pillWidth = mix(mix(44, titleWidth, pillMorph), width-28, p)
        let fieldReveal = stage(textMorph, from: 0.68, to: 0.96)
        let controlsVisible = editing && !chatIsOpen ? 0.0 : 1.0
        let doneProgress = composingGroup ? 1 : e
        return ZStack(alignment: .topLeading) {
            Button {
                if namingGroup { cancelGroupNameEditing() }
                else if chatIsOpen { closeChat() }
                else if composingGroup { setEditing(false) }
                else { setEditing(!editing) }
            } label: {
                ZStack {
                    Text("Edit").opacity((1-doneProgress) * (1-stage(chat, from: 0.05, to: 0.35)))
                    Text("Done").opacity(doneProgress * (1-stage(chat, from: 0.05, to: 0.35)))
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium)).opacity(backReveal*(1-nameMorph))
                        .blur(radius: reduceMotion ? 0 : 4 * (1-backReveal) + 6*nameMorph)
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium))
                        .opacity(nameMorph).blur(radius: reduceMotion ? 0 : 6*(1-nameMorph))
                }
                .animation(.easeOut(duration: 0.16), value: composingGroup)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                .frame(width: mix(68, 44, chat), height: 44)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .buttonStyle(ElasticPressStyle()).modifier(LiquidButtonMotion())
            .position(x: mix(50, 36, chat), y: mix(top + 30, top + 26, chat))
            .opacity(1-p).allowsHitTesting(!profileIsOpen)
            .accessibilityLabel(namingGroup ? "Cancel group name" : chatIsOpen ? "Back to chats" : editing || composingGroup ? "Done" : "Edit")
            .accessibilityIdentifier(namingGroup ? "cancel-group-name" : chatIsOpen ? "back-to-chats" : "edit-chats")
            .accessibilityHidden(profileIsOpen)

            Button {
                if namingGroup { saveGroupName() }
                else if !chatIsOpen { openChat(.reference[0]) }
                else if profileIsOpen && conversation.members.isEmpty {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.94)) { largePhoto.toggle() }
                } else { openProfile() }
            } label: {
                ZStack {
                    Circle().fill(appleBlue).frame(width: avatarSize, height: avatarSize).opacity(1-stage(chat, from: 0.65, to: 0.98))
                    Image(systemName: "square.and.pencil").font(.system(size: 21)).foregroundStyle(.white)
                        .scaleEffect(mix(1, 0.3, iconFade)).opacity(1-iconFade)
                        .blur(radius: reduceMotion ? 0 : 5 * iconFade)
                    conversationAvatar.resizable().scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .offset(x: -avatarSize * AvatarTransferMotion.replacementProgress(replacementProgress))
                        .scaleEffect(mix(0.18, 1, avatarMorph) * (reduceMotion ? 1 : mix(1, 0.18, stage(nameMorph, from: 0, to: 0.65))))
                        .blur(radius: reduceMotion ? 0 : 5*stage(nameMorph, from: 0, to: 0.65))
                        .opacity((largePhoto && conversation.avatar == "alicia" && conversation.members.isEmpty ? iconFade * (1-p) : iconFade) * (1-stage(nameMorph, from: 0.2, to: 0.65)))
                    if conversation.avatar == "alicia" && conversation.members.isEmpty {
                        Image("alicia-photo").resizable().scaledToFill().opacity(largePhoto ? p : 0)
                    }
                    Circle().fill(appleBlue)
                        .scaleEffect(reduceMotion ? 1 : mix(0.18, 1, stage(nameMorph, from: 0.1, to: 0.7)))
                        .opacity(stage(nameMorph, from: 0.1, to: 0.6))
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        .scaleEffect(reduceMotion ? 1 : mix(0.18, 1, stage(nameMorph, from: 0.45, to: 1)))
                        .blur(radius: reduceMotion ? 0 : 5*(1-stage(nameMorph, from: 0.45, to: 1)))
                        .opacity(stage(nameMorph, from: 0.45, to: 1))
                }
                .frame(width: avatarSize, height: avatarSize * mix(1, largePhoto ? 0.85 : 1, p))
                .clipShape(RoundedRectangle(cornerRadius: mix(avatarSize / 2, largePhoto ? 25 : avatarSize / 2, p), style: .continuous))
                .overlay { Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.2).opacity(chat * (1-p)) }
                .frame(width: avatarButtonSize, height: mix(44, avatarSize * (largePhoto ? 0.85 : 1), p))
                .background {
                    Circle().fill(.clear).glassEffect(.regular.interactive(), in: Circle()).opacity(chat * (1-p))
                }
            }
            .disabled(namingGroup && groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(GelatinActionStyle()).position(x: avatarX, y: avatarY)
            .opacity(controlsVisible)
            .allowsHitTesting(controlsVisible != 0 && avatarReplacement == nil)
            .animation(.easeOut(duration: 0.12), value: controlsVisible)
            .accessibilityLabel(namingGroup ? "Save group name" : !chatIsOpen ? "New message" : profileIsOpen ? (largePhoto ? "Collapse profile photo" : "Expand profile photo") : "Open profile")
            .accessibilityIdentifier(namingGroup ? "save-group-name" : "profile-avatar")
            .accessibilityHidden(controlsVisible == 0)
            .simultaneousGesture(profileIsOpen ? profileDismissGesture : nil)

            ZStack {
                Button {
                if chatIsOpen { if !profileIsOpen && !namingGroup { openProfile() } }
                else { notice = "This prototype uses the conversations from your reference." }
            } label: {
                ZStack {
                    Image(systemName: "plus.circle").font(.system(size: 21)).foregroundStyle(.black)
                        .opacity(1-iconFade).scaleEffect(mix(1, 0.6, iconFade))
                        .blur(radius: reduceMotion ? 0 : 5*iconFade)
                    VStack(spacing: 2) {
                        Text(headerName)
                            .font(.system(size: mix(conversation.members.isEmpty ? 14 : 15, 21, p), weight: .semibold)).lineLimit(1)
                        Text(conversation.members.isEmpty ? "last seen just now" : "\(conversation.members.count) members")
                            .font(.system(size: mix(10, 11, p))).opacity(mix(0.48, 0.7, p))
                    }
                    .foregroundStyle(Color(white: p))
                    .opacity(titleReveal).blur(radius: reduceMotion ? 0 : 5*(1-titleReveal))
                    .offset(y: reduceMotion ? 0 : 3*(1-titleReveal))
                    .padding(.horizontal, 12)
                    .frame(width: pillWidth, height: mix(44, 60, p))
                    .compositingGroup()
                    .modifier(TextGenie(progress: textMorph, target: CGPoint(x: pillWidth/2, y: 22),
                                        enabled: !reduceMotion, intoHeader: true))
                }
                .frame(width: mix(mix(44, titleWidth, pillMorph), width-28, p), height: mix(44, 60, p))

            }
                .buttonStyle(.plain)
                .allowsHitTesting(!namingGroup)
                .accessibilityLabel(chatIsOpen ? "Profile of " + conversation.name : "Add contact")
                .accessibilityIdentifier("profile-title")
                .accessibilityHidden(namingGroup || controlsVisible == 0)
                if namingGroup {
                    TextField("", text: $groupNameDraft)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center).textInputAutocapitalization(.words)
                        .focused($groupNameFocused).submitLabel(.done)
                        .onSubmit { saveGroupName() }
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier("group-name-input")
                        .accessibilityLabel("Group name")
                        .onAppear { groupNameFocused = true }
                        .opacity(fieldReveal)
                        .blur(radius: reduceMotion ? 0 : 5*(1-fieldReveal))
                        .transition(.identity)
                }
            }
            .frame(width: mix(mix(44, titleWidth, pillMorph), width-28, p), height: mix(44, 60, p))
            .background { Color.clear.glassEffect(.regular.interactive(), in: Capsule()).opacity(1-p) }
            .position(x: titleX, y: titleY)
            .opacity(controlsVisible).animation(.easeOut(duration: 0.12), value: controlsVisible)
            .allowsHitTesting(controlsVisible != 0)
            .simultaneousGesture(profileIsOpen ? profileDismissGesture : nil)
        }
        .frame(width: width, height: max(top+60, max(titleY+36, avatarY+avatarSize/2+12)), alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private var profileDismissGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                profile.dragProfile(x: value.translation.width, y: value.translation.height)
            }
            .onEnded { value in
                if shouldDismissProfile(translation: value.translation, predicted: value.predictedEndTranslation) {
                    closeProfile(velocity: value.velocity)
                } else {
                    profile.move(to: MotionVector(progress: 1),
                                 velocity: MotionVector(x: value.velocity.width, y: value.velocity.height))
                }
            }
    }

    private func chatBackGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !namingGroup else { return }
                navigation.dragChat(distance: max(0, value.translation.width), width: width)
                navigationHeader.dragChat(distance: max(0, value.translation.width), width: width)
                headerPill.dragChat(distance: max(0, value.translation.width), width: width)
                if avatarJourney != nil { avatarTravel.dragChat(distance: max(0, value.translation.width), width: width) }
            }
            .onEnded { value in
                if namingGroup { cancelGroupNameEditing(); return }
                let close = value.predictedEndTranslation.width > width * 0.4 && value.velocity.width > -100
                chatIsOpen = !close
                navigation.move(to: MotionVector(progress: close ? 0 : 1),
                                velocity: MotionVector(progress: -value.velocity.width / width))
                navigationHeader.move(to: MotionVector(progress: close ? 0 : 1),
                                      velocity: MotionVector(progress: -value.velocity.width / width))
                headerPill.move(to: MotionVector(progress: close ? 0 : 1),
                                velocity: MotionVector(progress: -value.velocity.width / width))
                if avatarJourney != nil {
                    avatarTravel.move(to: MotionVector(progress: close ? 0 : 1),
                                      velocity: MotionVector(progress: -value.velocity.width / width))
                    if close { finishAvatarReturn() }
                }
            }
    }

    private func glassButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).frame(width: 40, height: 40)
        }
        .buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }

    private func actionLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 18)).frame(width: 42, height: 42)
                .glassEffect(.regular.interactive(), in: Circle())
            Text(title).font(.system(size: 11))
        }
    }

    private func profileAction(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(icon, title) }.buttonStyle(.plain)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: 16)).textSelection(.enabled)
        }
        .padding(.vertical, 13).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(.black.opacity(0.15), in: Capsule()).frame(maxWidth: .infinity)
    }

    private func bubble(_ text: String, time: String, outgoing: Bool = false) -> some View {
        HStack {
            if outgoing { Spacer(minLength: 45) }
            VStack(alignment: .trailing, spacing: 3) {
                Text(text).font(.system(size: 16)).multilineTextAlignment(.leading)
                Text(time + (outgoing ? " ✓✓" : "")).font(.system(size: 9))
                    .foregroundStyle(outgoing ? Color.green.opacity(0.65) : Color.gray)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .fixedSize(horizontal: false, vertical: true)
            .background(outgoing ? Color(red: 0.87, green: 0.99, blue: 0.75) : .white,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !outgoing { Spacer(minLength: 45) }
        }
    }
}

private struct Wallpaper: View {
    let purple: Bool
    var body: some View {
        GeometryReader { proxy in
            if !purple {
                Image("chat-wallpaper").resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped().accessibilityHidden(true)
            } else {
        LinearGradient(colors: purple
                       ? [Color(red: 0.76, green: 0.25, blue: 0.86), Color(red: 0.35, green: 0.12, blue: 0.72)]
                       : [Color(red: 0.83, green: 0.88, blue: 0.43), Color(red: 0.33, green: 0.78, blue: 0.47)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay {
            Canvas { context, size in
                let symbols = ["♧", "♡", "✧", "❀"].map {
                    context.resolve(Text($0).font(.system(size: 16)).foregroundStyle(.black.opacity(0.065)))
                }
                for row in 0..<18 {
                    for column in 0..<9 {
                        context.draw(symbols[(row + column) % 4], at: CGPoint(x: CGFloat(column) * 54 + (row % 2 == 0 ? 0 : 25), y: CGFloat(row) * 57))
                    }
                }
            }
        }
            }
        }
        .accessibilityHidden(true)
    }
}

private func mix(_ start: Double, _ end: Double, _ progress: Double) -> Double {
    start + (end - start) * progress
}

private extension Double {
    var clamped: Double { min(1, max(0, self)) }
}

private func stage(_ value: Double, from start: Double, to end: Double) -> Double {
    min(1, max(0, (value-start) / (end-start)))
}
