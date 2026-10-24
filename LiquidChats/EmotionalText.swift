import SwiftUI

private struct CharacterIndex: TextAttribute { let index: Int }

private struct EmotionalRenderer: TextRenderer {
    let elapsed: Double
    let firstCharacter: Int
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                let index = run[CharacterIndex.self]?.index ?? 0
                let local = elapsed - Double(index-firstCharacter+1)*0.025
                let p = index < firstCharacter ? 0 : SeregaSelector.strength(at: local)
                var glyph = context
                let bounds = run.typographicBounds.rect
                glyph.opacity = min(1, max(0, 1-p))
                glyph.translateBy(x: bounds.midX, y: bounds.midY + 32*p)
                glyph.scaleBy(x: 1, y: 1-0.22*p)
                glyph.rotate(by: .degrees(12*p))
                glyph.translateBy(x: -bounds.midX, y: -bounds.midY)
                if p > 0 { glyph.addFilter(.blur(radius: 10*p)) }
                glyph.draw(run)
            }
        }
    }
}

struct EmotionalText: View {
    let text: String
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    @State private var firstCharacter = 0
    @State private var active = false
    @State private var settleTask: Task<Void, Never>?

    private var attributedText: Text {
        text.enumerated().reduce(Text("")) { result, character in
            result + Text(String(character.element)).customAttribute(CharacterIndex(index: character.offset))
        }
    }

    var body: some View {
        TimelineView(.animation(paused: !active)) { timeline in
            attributedText.textRenderer(EmotionalRenderer(elapsed: active && !reduceMotion ? timeline.date.timeIntervalSince(startedAt) : 1000,
                                                          firstCharacter: firstCharacter))
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(text)
        .onChange(of: text) { old, new in replay(old: old, new: new) }
        .onChange(of: enabled) { _, value in if value { replay(old: "", new: text) } }
        .onChange(of: reduceMotion) { if reduceMotion { settleTask?.cancel(); active = false } }
        .onDisappear { settleTask?.cancel() }
    }

    private func replay(old: String, new: String) {
        settleTask?.cancel()
        guard enabled && !reduceMotion else { active = false; return }
        firstCharacter = SeregaSelector.newCharacterOffset(old: old, new: new)
        startedAt = .now
        active = true
        let duration = 0.68 + Double(new.count-firstCharacter)*0.025
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            active = false
        }
    }
}
