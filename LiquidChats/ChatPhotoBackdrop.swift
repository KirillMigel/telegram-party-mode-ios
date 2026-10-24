import SwiftUI

struct ChatPhotoBackdrop: View {
    let conversation: Conversation
    var theme: ChatTheme = .meadow
    var transition: ThemeRippleTransition?
    var time: TimeInterval = 0
    var reduceMotion = false

    var body: some View {
        GeometryReader { proxy in
            let headerHeight: CGFloat = 350
            ZStack(alignment: .top) {
                ZStack {
                    if let transition, transition.to == theme, transition.age(at: time) < ThemeRippleTransition.duration, !reduceMotion {
                        ThemeWallpaper(theme: transition.from)
                        ThemeWallpaper(theme: transition.to)
                            .colorEffect(ShaderLibrary.themeReveal(
                                .float2(Float(transition.origin.x), Float(transition.origin.y)),
                                .float(Float(transition.age(at: time))), .float(Float(ThemeRippleTransition.revealDuration)),
                                .float(Float(transition.maxRadius(size: proxy.size))), .float(100)))
                    } else { ThemeWallpaper(theme: theme) }
                }
                .layerEffect(ShaderLibrary.themeRipple(
                    .float2(Float(transition?.origin.x ?? 0), Float(transition?.origin.y ?? 0)),
                    .float(Float(transition?.age(at: time) ?? 0)), .float(25), .float(20), .float(3.5), .float(1200)),
                             maxSampleOffset: CGSize(width: 25, height: 25),
                             isEnabled: !reduceMotion && transition?.to == theme && (transition?.age(at: time) ?? 2) < 2)
                if conversation.members.isEmpty {
                ZStack {
                    cover(width: proxy.size.width, height: headerHeight)
                        .mask(LinearGradient(stops: [.init(color: .white, location: 0),
                                                     .init(color: .white, location: 0.65),
                                                     .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    cover(width: proxy.size.width, height: headerHeight).blur(radius: 24)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                                     .init(color: .white, location: 0.82),
                                                     .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                }
                .frame(height: headerHeight).clipped()
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cover(width: CGFloat, height: CGFloat) -> some View {
            Image(conversation.avatar == "alicia" ? "alicia-photo" : conversation.avatar)
                .resizable().scaledToFill().frame(width: width, height: height).clipped()
    }
}

/// Links the real message scroll view to the floating app-bar controls.
@MainActor final class ChatScrollEdgeLink {
    private weak var scrollView: UIScrollView?
    private weak var barView: UIView?
    private let interaction = UIScrollEdgeElementContainerInteraction()
    private var active = false

    func connect(scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        self.scrollView = scrollView
        scrollView.topEdgeEffect.style = .soft
        interaction.scrollView = active ? scrollView : nil
    }

    func connect(barView: UIView, active: Bool) {
        if self.barView !== barView {
            self.barView?.removeInteraction(interaction)
            self.barView = barView
            interaction.edge = .top
            barView.addInteraction(interaction)
        }
        self.active = active
        interaction.scrollView = active ? scrollView : nil
    }

    func disconnect(barView: UIView) {
        guard self.barView === barView else { return }
        barView.removeInteraction(interaction)
        interaction.scrollView = nil
        self.barView = nil
    }
}

struct ChatScrollEdgeRegistration: UIViewRepresentable {
    let link: ChatScrollEdgeLink

    func makeUIView(context: Context) -> Probe { Probe(link: link) }
    func updateUIView(_ uiView: Probe, context: Context) { uiView.connect() }

    final class Probe: UIView {
        let link: ChatScrollEdgeLink
        init(link: ChatScrollEdgeLink) {
            self.link = link
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() { super.didMoveToWindow(); connect() }
        override func layoutSubviews() { super.layoutSubviews(); connect() }
        func connect() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { link.connect(scrollView: scroll); return }
                ancestor = view.superview
            }
        }
    }
}

/// A UIKit container lets iOS shape its native scroll-edge blur around the actual controls.
struct ChatScrollEdgeBar<Content: View>: UIViewControllerRepresentable {
    let link: ChatScrollEdgeLink
    let active: Bool
    var excludedHitRects: [CGRect] = []
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> ChatScrollEdgeLink { link }

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(content: AnyView(content()))
        (controller.view as? PassthroughView)?.excludedHitRects = excludedHitRects
        link.connect(barView: controller.view, active: active)
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.host.rootView = AnyView(content())
        (controller.view as? PassthroughView)?.excludedHitRects = excludedHitRects
        controller.view.setNeedsLayout()
        link.connect(barView: controller.view, active: active)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ChatScrollEdgeLink) {
        coordinator.disconnect(barView: controller.view)
    }

    final class Controller: UIViewController {
        let host: UIHostingController<AnyView>

        init(content: AnyView) {
            host = UIHostingController(rootView: content)
            host.safeAreaRegions = []
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func loadView() { view = PassthroughView() }
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            host.view.backgroundColor = .clear
            addChild(host)
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let fit = host.sizeThatFits(in: view.bounds.size)
            host.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: min(view.bounds.height, fit.height))
        }
    }

    /// The edge container spans the canvas; only its actual header child receives touches.
    final class PassthroughView: UIView {
        var excludedHitRects: [CGRect] = []
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if excludedHitRects.contains(where: { $0.contains(point) }) { return nil }
            let hit = super.hitTest(point, with: event)
            return hit === self ? nil : hit
        }
    }
}
