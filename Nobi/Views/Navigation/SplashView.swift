import SwiftUI

/// Launch animation, same beats as the website intro and the films' end card:
/// brush ring sweeps → panda mark inks in → wordmark wipes on → tagline rises.
struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ring: Double = 0
    @State private var markIn: CGFloat = 0
    @State private var wordIn: CGFloat = 0
    @State private var tagline = false

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 22) {
                ZStack {
                    BrushRing(progress: ring, lineWidth: 6, color: NobiTheme.ink.opacity(scheme == .dark ? 0.6 : 0.5), seed: 11)
                        .frame(width: 236, height: 236)
                    Image(scheme == .dark ? "NobiMarkSticker" : "NobiMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .modifier(InkRevealModifier(progress: markIn, anchor: UnitPoint(x: 0.3, y: 0.55)))
                        .scaleEffect(0.9 + 0.1 * markIn)
                }

                Image("NobiWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: 210 * wordIn)
                    }

                VStack(spacing: 6) {
                    (Text("Little robots. ").font(NobiFont.display(26))
                        + Text("Big hearts.").font(NobiFont.displayItalic(26)))
                        .foregroundStyle(NobiTheme.ink)
                }
                .opacity(tagline ? 1 : 0)
                .offset(y: tagline ? 0 : 14)
            }
        }
        .onAppear(perform: run)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nobi Robotics. Little robots. Big hearts.")
    }

    private func run() {
        if reduceMotion {
            ring = 1; markIn = 1; wordIn = 1; tagline = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: onFinished)
            return
        }
        withAnimation(.easeInOut(duration: 0.8)) { ring = 1 }
        withAnimation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.9).delay(0.35)) { markIn = 1 }
        withAnimation(.easeOut(duration: 0.55).delay(0.95)) { wordIn = 1 }
        withAnimation(.easeOut(duration: 0.6).delay(1.5)) { tagline = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: onFinished)
    }
}
