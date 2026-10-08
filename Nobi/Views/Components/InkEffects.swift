import SwiftUI

// MARK: - Backgrounds

/// Quiet rice paper by day; deep indigo with a few still stars by night.
struct PaperBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            NobiTheme.paper
            if scheme == .dark {
                LinearGradient(
                    colors: [Color(UIColor(hex: 0x191B40)), Color(UIColor(hex: 0x13152F))],
                    startPoint: .top, endPoint: .bottom
                )
                NightSky()
            } else {
                texture("PaperTexture")
                    .opacity(0.45)
                texture("ToothTexture")
                    .blendMode(.multiply)
                    .opacity(0.12)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// A full-bleed texture that never changes the layout size.
    private func texture(_ name: String) -> some View {
        Color.clear
            .overlay {
                Image(name)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}

/// A few faint, still stars.
struct NightSky: View {
    var body: some View {
        Canvas { gc, size in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<28 {
                let x = rng.next() * size.width
                let y = rng.next() * size.height * 0.6
                let r = 0.5 + rng.next() * 0.9
                let a = 0.15 + rng.next() * 0.3
                gc.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(Color(UIColor(hex: 0xFFF6E6)).opacity(a)))
            }
        }
    }
}

/// Tiny deterministic RNG so decorative scatter stays put between frames.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

// MARK: - Boil (the films' 12 fps hand-drawn wobble)

struct BoilModifier: ViewModifier {
    var amount: CGFloat = 1
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let offsets: [CGSize] = [CGSize(width: 0, height: 0), CGSize(width: 0.6, height: -0.4), CGSize(width: -0.4, height: 0.5)]
    private static let angles: [Double] = [0, 0.35, -0.3]

    @ViewBuilder
    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { ctx in
                let f = Int(ctx.date.timeIntervalSinceReferenceDate * 12) % 3
                content
                    .offset(x: Self.offsets[f].width * amount, y: Self.offsets[f].height * amount)
                    .rotationEffect(.degrees(Self.angles[f] * Double(amount)))
            }
        } else {
            content
        }
    }
}

extension View {
    func boil(_ amount: CGFloat = 1, active: Bool = true) -> some View {
        modifier(BoilModifier(amount: amount, active: active))
    }
}

/// Plays hand-drawn boil frames (`<prefix>0`, `<prefix>1`, `<prefix>2`) at 12 fps.
struct BoilingArt: View {
    var prefix: String
    var frames: Int = 3
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if active && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { ctx in
                let f = Int(ctx.date.timeIntervalSinceReferenceDate * 12) % max(1, frames)
                Image("\(prefix)\(f)")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        } else {
            Image("\(prefix)0")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
    }
}

// MARK: - Ink reveal transition (the website's intro "ink-in")

struct InkRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var anchor: UnitPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { geo in
                    let r = hypot(geo.size.width, geo.size.height) * max(0.001, progress) * 1.05
                    Circle()
                        .frame(width: r * 2, height: r * 2)
                        .position(x: geo.size.width * anchor.x, y: geo.size.height * anchor.y)
                }
            }
            .blur(radius: (1 - progress) * 6)
            .opacity(0.2 + 0.8 * Double(min(1, progress * 1.6)))
    }
}

extension AnyTransition {
    /// An ink blot that spreads from `anchor` to reveal the view.
    static func inkReveal(from anchor: UnitPoint = UnitPoint(x: 0.22, y: 0.5)) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: InkRevealModifier(progress: 0, anchor: anchor),
                identity: InkRevealModifier(progress: 1, anchor: anchor)
            ),
            removal: .opacity
        )
    }
}

// MARK: - Brush ring (the logo's ensō)

/// A dry-brush circle. `progress` draws it around (0...1); `rotation` spins it.
struct BrushRing: View, Animatable {
    var progress: Double = 1
    var lineWidth: CGFloat = 10
    var color: Color = NobiTheme.ink
    var seed: UInt64 = 3

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { gc, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - lineWidth
            let total = max(0, min(1, progress))
            guard total > 0.001 else { return }
            let steps = Int(180 * total) + 2
            var rng = SeededRandom(seed: seed)
            // Three passes: a heavy core and two dry, broken strokes.
            for pass in 0..<3 {
                let rOff = CGFloat(pass == 0 ? 0 : (pass == 1 ? -lineWidth * 0.45 : lineWidth * 0.4))
                let widthScale: CGFloat = pass == 0 ? 1 : 0.28
                var prev: CGPoint?
                for i in 0...steps {
                    let t = Double(i) / Double(steps) * total
                    let a = -Double.pi / 2 + t * 2 * Double.pi
                    let wob = CGFloat(sin(t * 23 + Double(pass)) * 0.8)
                    let rr = radius + rOff + wob
                    let p = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
                    if let q = prev {
                        // taper at the start and end, and skip some dabs in the dry passes
                        let taper = CGFloat(min(1, min(t / 0.06, (total - t) / 0.08 + 0.25)))
                        let skip = pass > 0 && rng.next() < 0.35
                        if !skip {
                            var seg = Path()
                            seg.move(to: q)
                            seg.addLine(to: p)
                            let w = lineWidth * widthScale * max(0.25, taper) * CGFloat(0.8 + 0.4 * rng.next())
                            gc.stroke(seg, with: .color(color.opacity(pass == 0 ? 0.95 : 0.6)),
                                      style: StrokeStyle(lineWidth: w, lineCap: .round))
                        }
                    }
                    prev = p
                }
            }
        }
    }
}

/// A brush-stroke underline under a headline word.
struct BrushUnderline: View {
    var color: Color = NobiTheme.red
    var body: some View {
        Canvas { gc, size in
            var p = Path()
            p.move(to: CGPoint(x: 2, y: size.height * 0.6))
            p.addQuadCurve(to: CGPoint(x: size.width - 2, y: size.height * 0.45),
                           control: CGPoint(x: size.width * 0.5, y: size.height * 0.95))
            gc.stroke(p, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: size.height * 0.45, lineCap: .round))
        }
        .frame(height: 8)
    }
}

// MARK: - Floating hearts (petting feedback)

struct FloatingHeart: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
}

struct FloatingHeartsLayer: View {
    var hearts: [FloatingHeart]
    var body: some View {
        ZStack {
            ForEach(hearts) { h in
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(NobiTheme.red)
                    .scaleEffect(h.scale)
                    .rotationEffect(.degrees(h.rotation))
                    .opacity(h.opacity)
                    .offset(x: h.x, y: h.y)
            }
        }
        .allowsHitTesting(false)
    }
}
