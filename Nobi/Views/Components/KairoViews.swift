import SwiftUI

// MARK: - OLED eyes

/// One mark drawn on the 128×64 OLED.
private struct EyeMark {
    var path: Path
    /// nil = filled; otherwise stroke width in OLED pixels.
    var stroke: CGFloat? = nil
    var opacity: Double = 1
}

/// Draws Kairo's 16 firmware emotions as glowing screen eyes, in 128×64 OLED space.
private enum OLEDEyes {
    static let left = CGPoint(x: 42, y: 30)
    static let right = CGPoint(x: 86, y: 30)

    static func blinkAmount(_ t: Double) -> CGFloat {
        let period = 4.3
        let phase = t.truncatingRemainder(dividingBy: period)
        guard phase < 0.16 else { return 0 }
        return CGFloat(sin(Double.pi * phase / 0.16))
    }

    static func square(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat, blink: CGFloat = 0) -> Path {
        let hh = max(2.5, h * (1 - 0.88 * blink))
        let rect = CGRect(x: c.x - w / 2, y: c.y - hh / 2, width: w, height: hh)
        return Path(roundedRect: rect, cornerRadius: min(6, hh / 2))
    }

    static func arc(_ c: CGPoint, width: CGFloat = 22, lift: CGFloat = 14, down: Bool = false) -> Path {
        var p = Path()
        let dy: CGFloat = down ? -6 : 6
        p.move(to: CGPoint(x: c.x - width / 2, y: c.y + dy))
        p.addQuadCurve(to: CGPoint(x: c.x + width / 2, y: c.y + dy),
                       control: CGPoint(x: c.x, y: c.y + (down ? lift : -lift)))
        return p
    }

    static func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    static func heart(_ c: CGPoint, _ s: CGFloat) -> Path {
        var p = Path()
        let bottom = CGPoint(x: c.x, y: c.y + s * 0.4)
        p.move(to: bottom)
        p.addCurve(to: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.1),
                   control1: CGPoint(x: c.x - s * 0.1, y: c.y + s * 0.3),
                   control2: CGPoint(x: c.x - s * 0.5, y: c.y + s * 0.15))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - s * 0.2),
                   control1: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.45),
                   control2: CGPoint(x: c.x - s * 0.05, y: c.y - s * 0.45))
        p.addCurve(to: CGPoint(x: c.x + s * 0.5, y: c.y - s * 0.1),
                   control1: CGPoint(x: c.x + s * 0.05, y: c.y - s * 0.45),
                   control2: CGPoint(x: c.x + s * 0.5, y: c.y - s * 0.45))
        p.addCurve(to: bottom,
                   control1: CGPoint(x: c.x + s * 0.5, y: c.y + s * 0.15),
                   control2: CGPoint(x: c.x + s * 0.1, y: c.y + s * 0.3))
        p.closeSubpath()
        return p
    }

    static func star(_ c: CGPoint, _ r: CGFloat, rotation: Double) -> Path {
        var pts: [CGPoint] = []
        for i in 0..<8 {
            let a = rotation + Double(i) * Double.pi / 4 - Double.pi / 2
            let rr = i % 2 == 0 ? r : r * 0.32
            pts.append(CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr))
        }
        return poly(pts)
    }

    static func spiral(_ c: CGPoint, rotation: Double) -> Path {
        var p = Path()
        let steps = 60
        for i in 0...steps {
            let th = Double(i) / Double(steps) * 4 * Double.pi
            let r = 1.5 + th * 0.85
            let pt = CGPoint(x: c.x + CGFloat(cos(th + rotation) * r), y: c.y + CGFloat(sin(th + rotation) * r))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    static func zee(_ o: CGPoint, _ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: o)
        p.addLine(to: CGPoint(x: o.x + s, y: o.y))
        p.addLine(to: CGPoint(x: o.x, y: o.y + s))
        p.addLine(to: CGPoint(x: o.x + s, y: o.y + s))
        return p
    }

    static func marks(for emotion: NobiEmotion, t: Double, live: Bool) -> [EyeMark] {
        let b = live ? blinkAmount(t) : 0
        let look = live ? CGPoint(x: CGFloat(sin(t * 0.45) * 2.5), y: CGFloat(cos(t * 0.33) * 1.2)) : .zero
        let L = CGPoint(x: left.x + look.x, y: left.y + look.y)
        let R = CGPoint(x: right.x + look.x, y: right.y + look.y)

        switch emotion {
        case .normal:
            return [EyeMark(path: square(L, 24, 24, blink: b)), EyeMark(path: square(R, 24, 24, blink: b))]
        case .happy:
            return [EyeMark(path: arc(L), stroke: 6), EyeMark(path: arc(R), stroke: 6)]
        case .angry:
            let l = left, r = right
            return [
                EyeMark(path: poly([CGPoint(x: l.x - 12, y: l.y - 9), CGPoint(x: l.x + 12, y: l.y + 2),
                                    CGPoint(x: l.x + 12, y: l.y + 12), CGPoint(x: l.x - 12, y: l.y + 12)])),
                EyeMark(path: poly([CGPoint(x: r.x - 12, y: r.y + 2), CGPoint(x: r.x + 12, y: r.y - 9),
                                    CGPoint(x: r.x + 12, y: r.y + 12), CGPoint(x: r.x - 12, y: r.y + 12)])),
            ]
        case .sad:
            let l = left, r = right
            let drop = CGFloat(live ? (t * 14).truncatingRemainder(dividingBy: 16) : 4)
            var tear = Path(ellipseIn: CGRect(x: l.x - 11, y: l.y + 16 + drop, width: 5, height: 6))
            tear.addLines([CGPoint(x: l.x - 11, y: l.y + 18 + drop), CGPoint(x: l.x - 8.5, y: l.y + 12 + drop),
                           CGPoint(x: l.x - 6, y: l.y + 18 + drop)])
            return [
                EyeMark(path: poly([CGPoint(x: l.x - 12, y: l.y + 1), CGPoint(x: l.x + 12, y: l.y - 10),
                                    CGPoint(x: l.x + 12, y: l.y + 12), CGPoint(x: l.x - 12, y: l.y + 12)])),
                EyeMark(path: poly([CGPoint(x: r.x - 12, y: r.y - 10), CGPoint(x: r.x + 12, y: r.y + 1),
                                    CGPoint(x: r.x + 12, y: r.y + 12), CGPoint(x: r.x - 12, y: r.y + 12)])),
                EyeMark(path: tear, opacity: Double(1 - drop / 18)),
            ]
        case .tired:
            return [EyeMark(path: square(CGPoint(x: L.x, y: L.y + 6), 24, 10)),
                    EyeMark(path: square(CGPoint(x: R.x, y: R.y + 6), 24, 10))]
        case .curious:
            return [EyeMark(path: square(CGPoint(x: L.x, y: L.y + 2), 19, 19, blink: b)),
                    EyeMark(path: square(CGPoint(x: R.x, y: R.y - 2), 29, 29, blink: b))]
        case .surprised:
            return [
                EyeMark(path: Path(ellipseIn: CGRect(x: left.x - 13, y: left.y - 13, width: 26, height: 26)), stroke: 5),
                EyeMark(path: Path(ellipseIn: CGRect(x: right.x - 13, y: right.y - 13, width: 26, height: 26)), stroke: 5),
                EyeMark(path: Path(ellipseIn: CGRect(x: left.x - 3.5, y: left.y - 3.5, width: 7, height: 7))),
                EyeMark(path: Path(ellipseIn: CGRect(x: right.x - 3.5, y: right.y - 3.5, width: 7, height: 7))),
            ]
        case .love:
            let s = 30 * CGFloat(1 + (live ? 0.08 * sin(t * 6) : 0))
            return [EyeMark(path: heart(L, s)), EyeMark(path: heart(R, s))]
        case .sleepy:
            var marks = [
                EyeMark(path: arc(CGPoint(x: left.x, y: left.y + 4), width: 22, lift: 8, down: true), stroke: 4),
                EyeMark(path: arc(CGPoint(x: right.x, y: right.y + 4), width: 22, lift: 8, down: true), stroke: 4),
            ]
            for i in 0..<2 {
                let ph = live ? (t * 0.45 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1) : 0.3 + Double(i) * 0.4
                let s = CGFloat(5 + ph * 4)
                let o = CGPoint(x: 104 + CGFloat(ph) * 10, y: 20 - CGFloat(ph) * 16)
                marks.append(EyeMark(path: zee(o, s), stroke: 2, opacity: 1 - ph * 0.8))
            }
            return marks
        case .excited:
            let rot = live ? t * 1.4 : 0
            return [EyeMark(path: star(L, 16, rotation: rot)), EyeMark(path: star(R, 16, rotation: -rot))]
        case .confused:
            let rot = live ? t * 2.5 : 0
            return [EyeMark(path: square(L, 22, 22, blink: b)),
                    EyeMark(path: spiral(CGPoint(x: right.x, y: right.y - 1), rotation: rot), stroke: 3)]
        case .wink:
            return [EyeMark(path: square(L, 24, 24, blink: b)), EyeMark(path: arc(R), stroke: 6)]
        case .suspicious:
            let dx: CGFloat = live ? CGFloat(4 + 3 * sin(t * 0.8)) : 5
            return [EyeMark(path: square(CGPoint(x: left.x + dx, y: left.y + 4), 26, 9)),
                    EyeMark(path: square(CGPoint(x: right.x + dx, y: right.y + 4), 26, 9))]
        case .scared:
            let j = live ? CGFloat(sin(t * 38) * 1.3) : 0
            return [EyeMark(path: square(CGPoint(x: left.x + j, y: left.y), 14, 14)),
                    EyeMark(path: square(CGPoint(x: right.x + j, y: right.y), 14, 14))]
        case .bored:
            return [EyeMark(path: square(CGPoint(x: left.x - 5, y: left.y + 7), 26, 11)),
                    EyeMark(path: square(CGPoint(x: right.x - 5, y: right.y + 7), 26, 11))]
        case .smug:
            let l = left
            return [
                EyeMark(path: poly([CGPoint(x: l.x - 12, y: l.y), CGPoint(x: l.x + 12, y: l.y + 3),
                                    CGPoint(x: l.x + 12, y: l.y + 12), CGPoint(x: l.x - 12, y: l.y + 12)])),
                EyeMark(path: arc(CGPoint(x: right.x, y: right.y + 4), width: 22, lift: 10), stroke: 6),
            ]
        }
    }
}

/// Kairo's screen: glowing eyes for an emotion, drawn live.
struct OLEDFaceView: View {
    var emotion: NobiEmotion
    var color: Color = NobiTheme.cyan
    var live: Bool = true
    /// Draw the dark screen behind the eyes (for standalone use).
    var showScreen: Bool = false
    var glow: Bool = true
    /// Mirrors Kairo's "invert colours": dark eyes on a lit screen.
    var inverted: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !live)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                if showScreen || inverted {
                    gc.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: min(size.width, size.height) * 0.12),
                            with: .color(inverted ? color : NobiTheme.screenBlack))
                }
                let k = min(size.width / 128, size.height / 64)
                var g = gc
                g.translateBy(x: (size.width - 128 * k) / 2, y: (size.height - 64 * k) / 2)
                g.scaleBy(x: k, y: k)
                let marks = OLEDEyes.marks(for: emotion, t: t, live: live)
                if glow && !inverted {
                    var glowCtx = g
                    glowCtx.addFilter(.blur(radius: 6 * k))
                    for m in marks { draw(m, in: &glowCtx, alpha: 0.6) }
                }
                for m in marks { draw(m, in: &g, alpha: 1) }
            }
        }
        .accessibilityLabel("\(emotion.displayName) face")
    }

    private func draw(_ m: EyeMark, in gc: inout GraphicsContext, alpha: Double) {
        let c = (inverted ? NobiTheme.screenBlack : color).opacity(m.opacity * alpha)
        if let w = m.stroke {
            gc.stroke(m.path, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        } else {
            gc.fill(m.path, with: .color(c))
        }
    }
}

// MARK: - Kairo, hand-drawn

/// The hand-drawn Kairo (from the animation kit) with a live OLED face on its screen.
/// Tap to pet, drag across to stroke.
struct KairoView: View {
    var plate: FacePlate = .yellow
    var emotion: NobiEmotion = .happy
    var live: Bool = true
    var inverted: Bool = false
    var onTap: (() -> Void)? = nil
    var onStroke: (() -> Void)? = nil

    /// Art is 879×1027; the screen sits at this normalized rect.
    static let aspect: CGFloat = 879.0 / 1027.0
    private static let screen = CGRect(x: 0.3356, y: 0.3038, width: 0.3276, height: 0.148)

    @State private var hearts: [FloatingHeart] = []
    @State private var squash = false
    @State private var strokeDistance: CGFloat = 0
    @State private var lastDrag: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                BoilingArt(prefix: plate.artPrefix, active: live)
                    .frame(width: w, height: h)
                OLEDFaceView(emotion: emotion, color: NobiTheme.eyeColor(plate), live: live, inverted: inverted)
                    .frame(width: w * Self.screen.width * 0.94, height: h * Self.screen.height * 0.9)
                    .position(x: w * Self.screen.midX, y: h * Self.screen.midY)
                FloatingHeartsLayer(hearts: hearts)
                    .position(x: w * 0.5, y: h * 0.3)
            }
            .scaleEffect(x: squash ? 1.05 : 1, y: squash ? 0.94 : 1, anchor: .bottom)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let onTap else { return }
                bounce()
                spawnHeart()
                onTap()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in
                        guard onStroke != nil else { return }
                        if let last = lastDrag {
                            strokeDistance += hypot(v.location.x - last.x, v.location.y - last.y)
                        }
                        lastDrag = v.location
                        if strokeDistance > 70 {
                            strokeDistance = 0
                            spawnHeart()
                            onStroke?()
                        }
                    }
                    .onEnded { _ in
                        lastDrag = nil
                        strokeDistance = 0
                    }
            )
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kairo looking \(emotion.feeling)")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    private func bounce() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { squash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { squash = false }
        }
    }

    private func spawnHeart() {
        let heart = FloatingHeart(
            x: CGFloat.random(in: -50...50), y: 0,
            scale: CGFloat.random(in: 0.8...1.3), opacity: 1,
            rotation: Double.random(in: -20...20)
        )
        hearts.append(heart)
        let id = heart.id
        withAnimation(.easeOut(duration: 1.2)) {
            if let i = hearts.firstIndex(where: { $0.id == id }) {
                hearts[i].y = -90
                hearts[i].opacity = 0
                hearts[i].scale *= 1.3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            hearts.removeAll { $0.id == id }
        }
    }
}

// MARK: - Robot avatar (vector, for lists and chips)

/// A small panda-robot face: black body, round ears, face plate and a live screen.
struct RobotAvatar: View {
    var plate: FacePlate = .yellow
    var emotion: NobiEmotion = .happy
    var size: CGFloat = 44
    var live: Bool = false
    var dimmed: Bool = false

    var body: some View {
        let s = size
        ZStack {
            // ears
            HStack(spacing: s * 0.34) {
                Circle().fill(NobiTheme.robotBody).overlay(Circle().strokeBorder(NobiTheme.inkLine, lineWidth: max(1, s * 0.035)))
                    .frame(width: s * 0.34, height: s * 0.34)
                Circle().fill(NobiTheme.robotBody).overlay(Circle().strokeBorder(NobiTheme.inkLine, lineWidth: max(1, s * 0.035)))
                    .frame(width: s * 0.34, height: s * 0.34)
            }
            .offset(y: -s * 0.33)
            // head
            RoundedRectangle(cornerRadius: s * 0.3, style: .continuous)
                .fill(NobiTheme.robotBody)
                .overlay(RoundedRectangle(cornerRadius: s * 0.3, style: .continuous).strokeBorder(NobiTheme.inkLine, lineWidth: max(1, s * 0.04)))
                .frame(width: s * 0.92, height: s * 0.8)
                .offset(y: s * 0.06)
            // plate + screen
            RoundedRectangle(cornerRadius: s * 0.12, style: .continuous)
                .fill(NobiTheme.plateColor(plate))
                .overlay(RoundedRectangle(cornerRadius: s * 0.12, style: .continuous).strokeBorder(NobiTheme.robotBody.opacity(0.8), lineWidth: max(0.8, s * 0.025)))
                .frame(width: s * 0.66, height: s * 0.48)
                .offset(y: s * 0.04)
            OLEDFaceView(emotion: emotion, color: NobiTheme.eyeColor(plate), live: live, showScreen: true, glow: s > 60)
                .frame(width: s * 0.5, height: s * 0.28)
                .offset(y: s * 0.03)
        }
        .frame(width: s, height: s)
        .saturation(dimmed ? 0.2 : 1)
        .opacity(dimmed ? 0.7 : 1)
        .accessibilityHidden(true)
    }
}
