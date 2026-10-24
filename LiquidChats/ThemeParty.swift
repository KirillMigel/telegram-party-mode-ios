import SwiftUI
import RealityKit

extension ChatTheme {
    var colors: [Color] {
        switch self {
        case .meadow: [Color(red: 0.78, green: 0.87, blue: 0.56), Color(red: 0.4, green: 0.7, blue: 0.56)]
        case .peach: [Color(red: 1, green: 0.87, blue: 0.7), Color(red: 0.94, green: 0.65, blue: 0.64)]
        case .sand: [Color(red: 1, green: 0.93, blue: 0.76), Color(red: 0.86, green: 0.8, blue: 0.63)]
        case .mint: [Color(red: 0.84, green: 0.94, blue: 0.77), Color(red: 0.63, green: 0.85, blue: 0.74)]
        case .lagoon: [Color(red: 0.66, green: 0.94, blue: 0.91), Color(red: 0.62, green: 0.77, blue: 0.98)]
        case .lavender: [Color(red: 0.84, green: 0.86, blue: 1), Color(red: 0.85, green: 0.7, blue: 0.91)]
        case .newYear: [Color(red: 1, green: 0.43, blue: 0.42), Color(red: 0.78, green: 0.68, blue: 0.84), Color(red: 1, green: 0.32, blue: 0.39)]
        }
    }
}

struct ThemeWallpaper: View {
    let theme: ChatTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                if theme == .meadow {
                    Image("chat-wallpaper").resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else if theme == .newYear {
                    Image("new-year-wallpaper").resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else {
                    Image("chat-wallpaper").resizable().scaledToFill().saturation(0)
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        .blendMode(.multiply).opacity(0.25)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct PortalThemePicker: View {
    let selected: ChatTheme
    let isTransitioning: Bool
    let choose: (ChatTheme, CGPoint) -> Void
    let save: () -> Void
    let cancel: () -> Void
    @State private var frames: [ChatTheme: CGRect] = [:]

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(ChatTheme.allCases, id: \.self) { theme in
                        Button { choose(theme, CGPoint(x: frames[theme]?.midX ?? 200, y: frames[theme]?.midY ?? 300)) } label: {
                            Circle().fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay {
                                    if theme == .newYear { Image(systemName: "snowflake").font(.system(size: 21)).foregroundStyle(.white) }
                                }
                                .frame(width: 36, height: 36).padding(4)
                                .overlay { Circle().strokeBorder(.white, lineWidth: selected == theme ? 2.5 : 0) }
                        }
                        .buttonStyle(.plain)
                        .disabled(isTransitioning)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.onChange(of: proxy.frame(in: .named("chats-root")), initial: true) {
                                    frames[theme] = proxy.frame(in: .named("chats-root"))
                                }
                            }
                        }
                        .accessibilityLabel(theme.name + " theme")
                        .accessibilityAddTraits(selected == theme ? .isSelected : [])
                        .accessibilityIdentifier("theme-"+theme.rawValue)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: 46)
            Button(action: save) {
                Image(systemName: "checkmark").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white).frame(width: 46, height: 46)
                    .background(appleBlue.gradient, in: Circle())
            }
            .buttonStyle(.plain).glassEffect(.regular.tint(appleBlue.opacity(0.12)).interactive(), in: Circle())
            .accessibilityLabel("Save theme").accessibilityIdentifier("save-group-theme")
        }
        .padding(.horizontal, 12).frame(height: 54)
        .accessibilityAction(.escape, cancel)
    }
}

struct PortalDiscoBall: View {
    let time: Double
    let reduceMotion: Bool
    @State private var ball: Entity?
    @State private var failed = false

    var body: some View {
        ZStack {
            RealityView { content in
                let root = Entity()
                let camera = Entity()
                var lens = PerspectiveCameraComponent()
                lens.fieldOfViewInDegrees = 45
                camera.components.set(lens)
                camera.position = [0, 0, 0.72]
                root.addChild(camera)
                do {
                    let sphere = try DiscoBallBuilder.makeDiscoBall(params: .init(radius: 0.25, tileArc: 0.038,
                                                                                 tileGap: 0.002, jitterAmount: 0.006,
                                                                                 jitterSeed: 1337, lowQuality: false),
                                                                  mirrorRoughness: 0.09)
                    root.addChild(sphere)
                    ball = sphere
                } catch { failed = true }
                for (color, position, intensity) in [
                    (UIColor(white: 1, alpha: 1), SIMD3<Float>(0.8, 1, 1), Float(120000)),
                    (UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1), SIMD3<Float>(-0.9, 0.4, 0.9), Float(70000)),
                    (UIColor(red: 1, green: 0.4, blue: 0.75, alpha: 1), SIMD3<Float>(0.6, -0.5, 0.6), Float(90000))
                ] {
                    let light = DirectionalLight()
                    light.light.color = color
                    light.light.intensity = intensity
                    light.look(at: .zero, from: position, relativeTo: nil)
                    root.addChild(light)
                }
                content.add(root)
            } update: { _ in
                ball?.orientation = simd_quatf(angle: reduceMotion ? 0.3 : Float(time)*0.48, axis: [0, 1, 0]) *
                    simd_quatf(angle: -0.18, axis: [0, 0, 1])
            }
            if failed { Text("🪩").font(.system(size: 50)) }
        }
    }
}

struct DiscoLights: View {
    let time: Double
    let center: CGPoint
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            let t = reduceMotion ? 0 : time
            let colors: [Color] = [.cyan, .pink, .yellow, .mint, .purple, .white]
            for index in 0..<18 {
                let angle = Double(index)*2*Double.pi/18+t*0.18+sin(t*0.45+Double(index))*0.07
                let length = hypot(size.width, size.height)
                let end = CGPoint(x: center.x+cos(angle)*length, y: center.y+sin(angle)*length)
                let spread = length*(0.025+Double(index%3)*0.012)
                let perpendicular = CGPoint(x: -sin(angle)*spread, y: cos(angle)*spread)
                var ray = Path()
                ray.move(to: center)
                ray.addLine(to: CGPoint(x: end.x+perpendicular.x, y: end.y+perpendicular.y))
                ray.addLine(to: CGPoint(x: end.x-perpendicular.x, y: end.y-perpendicular.y))
                ray.closeSubpath()
                context.fill(ray, with: .linearGradient(Gradient(colors: [colors[index % colors.count].opacity(0.26), .clear]),
                                                       startPoint: center, endPoint: end))
            }
            for index in 0..<22 {
                let x = (sin(Double(index)*2.399+t*0.18)+1)*size.width/2
                let y = center.y + cos(Double(index)*1.37+t*0.24)*size.height*0.45
                let r = 3.0+Double(index % 3)*2
                let glow = CGRect(x: x-r, y: y-r, width: r*2, height: r*2)
                context.fill(Path(ellipseIn: glow), with: .color(colors[index % colors.count].opacity(0.2)))
            }
        }
        .blur(radius: 4).allowsHitTesting(false).accessibilityHidden(true)
    }
}
