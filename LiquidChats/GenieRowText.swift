import SwiftUI

nonisolated struct TextGenie: ViewModifier, Animatable {
    var progress: CGFloat
    let target: CGPoint
    let enabled: Bool
    var intoHeader = false
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let shader = intoHeader
            ? ShaderLibrary.headerNameGenie(.boundingRect, .float(Float(progress)), .float2(Float(target.x), Float(target.y)))
            : ShaderLibrary.avatarGenie(.boundingRect, .float(Float(progress)), .float2(Float(target.x), Float(target.y)))
        content.distortionEffect(shader,
            maxSampleOffset: CGSize(width: 400, height: 100), isEnabled: enabled
        )
        .opacity(enabled ? 1 - max(0, (progress - 0.88) / 0.12) : 1 - progress)
    }
}

/// Keeps the existing text view alive while its pixels funnel into the avatar.
struct GenieRowText<Content: View>: View {
    let width: CGFloat
    let target: CGPoint
    let collapsed: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    init(width: CGFloat, target: CGPoint, collapsed: Bool, @ViewBuilder content: () -> Content) {
        self.width = width
        self.target = target
        self.collapsed = collapsed
        self.content = content()
    }

    var body: some View {
        content.padding(.leading, 91).padding(.top, 12)
            .frame(width: width + 91, height: 86, alignment: .topLeading)
            .compositingGroup()
            .modifier(TextGenie(progress: progress, target: target, enabled: !reduceMotion))
            .onChange(of: collapsed, initial: true) {
                withAnimation(reduceMotion ? .linear(duration: 0.08) :
                    .timingCurve(0.66, 0, 0.34, 1, duration: collapsed ? 1.2 : 0.22)) {
                    progress = collapsed ? 1 : 0
                }
            }
    }
}
