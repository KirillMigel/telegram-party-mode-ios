import SwiftUI

/// The glass portal stays above the orbit and keeps its action without visible captions.
struct GroupWelcomeScene: View {
    let time: Double
    let card: CGRect
    let width: CGFloat
    let height: CGFloat
    let reduceMotion: Bool
    let nameIsSet: Bool
    let hasCustomAvatar: Bool
    let partyIsStarted: Bool
    let launchPose: PartyPortalPose?
    let isLoadingAvatar: Bool
    let photoPickerProgress: Double
    let discoTime: Double
    let setName: () -> Void

    var body: some View {
        let center = launchPose?.center ?? CGPoint(x: card.midX, y: card.midY)
        let reveal = partyIsStarted ? 1.0 : 0.0
        let iconReveal = launchPose?.iconReveal ?? 1
        let radius: CGFloat = 34
        let caption = !nameIsSet ? "Set group name" : hasCustomAvatar ? "Change theme" : "Change avatar"
        ZStack(alignment: .topLeading) {
            if partyIsStarted {
            PartyMusicIcon(time: discoTime, card: card, width: width, reduceMotion: reduceMotion)
                .opacity(iconReveal)
            Button(action: setName) {
                ZStack {
                    Circle().fill(.clear).glassEffect(.clear.interactive(), in: Circle())
                    Circle().strokeBorder(.linearGradient(colors: [.white.opacity(0.95), .gray.opacity(0.16), .white.opacity(0.7)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    Capsule().fill(appleBlue).opacity(1-iconReveal)
                    Text("Start").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .opacity(1-iconReveal).blur(radius: reduceMotion ? 0 : 5*iconReveal)
                    PortalDiscoBall(time: discoTime, reduceMotion: reduceMotion)
                        .frame(width: 68, height: 68)
                        .opacity(iconReveal).blur(radius: reduceMotion ? 0 : 6*(1-iconReveal))
                        .scaleEffect(0.86+0.14*iconReveal)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                .frame(width: radius*2, height: radius*2)
                .scaleEffect(PartyEmphasis.discoScale(time: discoTime, reduceMotion: reduceMotion))
                .shadow(color: .black.opacity(0.09), radius: 10, y: 5)
                .contentShape(Circle())
            }
            .buttonStyle(GlassPortalButtonStyle())
            .accessibilityLabel(caption)
            .accessibilityIdentifier("group-onboarding-action")
            .scaleEffect(x: launchPose?.scaleX ?? 1, y: launchPose?.scaleY ?? 1)
            .opacity(min(1, max(0, reveal)) * (1-min(1, max(0, photoPickerProgress)*8)))
            .position(center)
            .allowsHitTesting(partyIsStarted && iconReveal == 1 && time >= PartyLaunchMotion.burstLead)
            .accessibilityHidden(!partyIsStarted || time < PartyLaunchMotion.burstLead)
            .disabled(isLoadingAvatar || time < PartyLaunchMotion.burstLead)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

private struct PartyMusicIcon: View {
    @Namespace private var musicGlass
    let time: Double
    let card: CGRect
    let width: CGFloat
    let reduceMotion: Bool

    var body: some View {
        let phase = (reduceMotion ? 0 : time)*2*Double.pi/12
        let radius = min(width/2-44, 105)
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 3) {
                ForEach([18.0, 12.0, 6.0], id: \.self) { height in
                    Capsule().fill(.white).frame(width: 3, height: height)
                }
            }
            .frame(width: 52, height: 34)
            .glassEffect(.clear.tint(.white.opacity(0.14)), in: Capsule())
            .glassEffectID("party-music", in: musicGlass)
        }
        .frame(width: 52, height: 34).fixedSize()
        .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
        .offset(x: card.midX+cos(phase)*radius-26, y: card.midY-18+sin(phase)*36-17)
        .transaction { $0.animation = nil }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Bare stickers stay above the scroll edge until they are attached to a message.
struct GroupWelcomeStickers: View {
    let time: Double
    let card: CGRect
    let width: CGFloat
    let height: CGFloat
    let reduceMotion: Bool
    let frames: [Int: CGRect]
    let attached: Set<Int>
    let canDrag: Bool
    let moveSticker: (Int, DragGesture.Value) -> Void
    let releaseSticker: (Int, DragGesture.Value) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach((0..<WelcomeBurst.count).filter { !attached.contains($0) }, id: \.self) { index in
                let pose = WelcomeBurst.sticker(index, time: reduceMotion ? 4 : time, card: card, width: width)
                let size = pose.size*1.25
                let frame = frames[index] ?? CGRect(x: pose.center.x-size/2, y: pose.center.y-size/2, width: size, height: size)
                Image("party-sticker-\(index % 10)").resizable().scaledToFit()
                    .frame(width: frame.width, height: frame.width)
                    .rotationEffect(.degrees(pose.rotation))
                    .contentShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    .gesture(canDrag ? DragGesture(minimumDistance: 0, coordinateSpace: .named("chats-root"))
                        .onChanged { moveSticker(index, $0) }.onEnded { releaseSticker(index, $0) } : nil)
                    .position(x: frame.midX, y: frame.midY).opacity(pose.opacity)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(canDrag).accessibilityHidden(true)
    }
}

/// The app's PhotoKit grid shares the compact glass portal, without embedded picker onboarding.
struct PortalPhotoPicker: View {
    let isPresented: Bool
    let progress: Double
    let source: CGRect
    let width: CGFloat
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    let reduceMotion: Bool
    let close: () -> Void
    let select: (UIImage) -> Void

    var body: some View {
        let target = PhotoPickerMorph.destination(source: source, width: width, height: height, top: top, bottom: bottom)
        let p = max(0, progress)
        let frame = reduceMotion ? target : PhotoPickerMorph.frame(source: source, target: target, progress: p)
        let inflation = min(1, p)
        let radius = reduceMotion ? 28 : min(frame.width, frame.height)/2 * (1-inflation) + 28*inflation
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .topLeading) {
            Button(action: close) { Color.black.opacity(0.12*min(1, p)).contentShape(Rectangle()) }
                .buttonStyle(.plain).frame(width: width, height: height)
                .accessibilityLabel("Close photo picker")
            shape.fill(.clear).glassEffect(.clear, in: shape)
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.linearGradient(colors: [.white.opacity(0.9), .white.opacity(0.12), .white.opacity(0.65)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.16*min(1, p)), radius: 24, y: 12)
            .opacity(min(1, p*8))
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)

            if isPresented && (reduceMotion || p >= 0.96) {
                AvatarPhotoGrid(select: select)
                    .frame(width: target.width-12, height: target.height-12)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .position(x: target.midX, y: target.midY)
                    .transaction { $0.animation = nil }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(isPresented)
        .accessibilityElement(children: .contain)
        .accessibilityHidden(!isPresented)
        .accessibilityAction(.escape, close)
    }
}

/// One recognizer owns both tap activation and elastic dragging, so release cannot fire both.
private struct GlassPortalButtonStyle: PrimitiveButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGSize = .zero
    @State private var pressed = false
    @State private var touching = false
    @State private var moved = false
    @State private var pressedAt = Date.distantPast
    @State private var releaseTask: Task<Void, Never>?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(offset)
            .scaleEffect(x: reduceMotion ? 1 : (pressed ? 1.1 : 1) + abs(offset.width)/80*0.12,
                         y: reduceMotion ? 1 : (pressed ? 1.1 : 1) + abs(offset.height)/80*0.12)
            .opacity(reduceMotion && pressed ? 0.8 : 1)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !touching {
                        releaseTask?.cancel()
                        pressedAt = .now
                        touching = true
                        moved = false
                    }
                    if hypot(value.translation.width, value.translation.height) > 8 { moved = true }
                    let motionReduced = reduceMotion
                    func eased(_ value: CGFloat) -> CGFloat {
                        motionReduced ? 0 : (value < 0 ? -1 : 1) * pow(abs(value), 1.0/3)
                    }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.12)) {
                        pressed = true
                        offset = CGSize(width: eased(value.translation.width), height: eased(value.translation.height))
                    }
                }
                .onEnded { value in
                    let activate = !moved && hypot(value.translation.width, value.translation.height) <= 8
                    touching = false
                    releasePress()
                    if activate { configuration.trigger() }
                })
            .accessibilityAction {
                releaseTask?.cancel()
                pressedAt = .now
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.12)) { pressed = true }
                releasePress()
                configuration.trigger()
            }
            .onDisappear { releaseTask?.cancel() }
    }

    private func releasePress() {
        // A quick tap must reach the expanded state before its return spring starts.
        let delay = reduceMotion ? 0 : max(0, 0.14 - Date.now.timeIntervalSince(pressedAt))
        releaseTask?.cancel()
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.3)) {
                pressed = false
                offset = .zero
            }
        }
    }
}
