import SwiftUI

/// A 128×64 preview drawn exactly like Kairo's face plate: plate → mint bezel → dark screen (Spec §12, §18).
struct OLEDPreviewView: View {
    enum ContentType {
        case text(message: String, size: NobiTextSize)
        case image(uiImage: UIImage, scale: Int)
        case notification(app: String, title: String, message: String, size: NobiTextSize)
        case face(NobiEmotion)
    }

    var content: ContentType
    var plate: FacePlate = .yellow
    var showCaption: Bool = false
    /// Mirrors Kairo's "invert colours" setting.
    var inverted: Bool = false

    private var litColor: Color { NobiTheme.eyeColor(plate) }
    /// Colour of pixels that are "on".
    private var glowColor: Color { inverted ? NobiTheme.screenBlack : litColor }
    /// Screen background.
    private var screenColor: Color { inverted ? litColor : NobiTheme.screenBlack }
    /// Brightest text (notification title).
    private var titleColor: Color { inverted ? NobiTheme.screenBlack : Color.white }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Face plate
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NobiTheme.plateColor(plate))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color(UIColor(hex: 0x1F1D1B)), lineWidth: 2.5))
                // Bolts
                GeometryReader { g in
                    let r: CGFloat = 5
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(NobiTheme.robotBody)
                            .frame(width: r * 2, height: r * 2)
                            .position(x: i % 2 == 0 ? 16 : g.size.width - 16, y: i < 2 ? 16 : g.size.height - 16)
                    }
                }
                // Bezel + screen
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NobiTheme.screenMint)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(UIColor(hex: 0x1F1D1B)), lineWidth: 2))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 22)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(screenColor)
                    .overlay(screenContent.padding(8))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .aspectRatio(2, contentMode: .fit)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
            }
            .aspectRatio(1.72, contentMode: .fit)
            .frame(maxWidth: 330)
            .shadow(color: NobiTheme.softShadow, radius: 18, y: 8)
            .frame(maxWidth: .infinity)

            if showCaption {
                indicatorLabel
                    .font(NobiFont.body(13, .medium))
                    .foregroundStyle(NobiTheme.ink3)
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch content {
        case .face(let emotion):
            OLEDFaceView(emotion: emotion, color: litColor, live: true, inverted: inverted)

        case .text(let message, let size):
            if message.isEmpty {
                Text("type something…")
                    .font(.system(size: size.previewFontSize * 0.75, weight: .medium, design: .monospaced))
                    .foregroundStyle(titleColor.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text(message)
                    .font(.system(size: size.previewFontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(glowColor)
                    .shadow(color: inverted ? .clear : glowColor.opacity(0.55), radius: 3)
                    .lineLimit(size == .large ? 1 : (size == .medium ? 2 : 4))
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

        case .image(let uiImage, let scale):
            GeometryReader { geo in
                let s = CGFloat(scale) / 100.0
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(2, contentMode: .fit)
                    .frame(width: geo.size.width * s, height: geo.size.height * s)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .modifier(PixelTint(inverted: inverted, lit: litColor))
            }
            .padding(-8)

        case .notification(let app, let title, let message, let size):
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(app.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                    Spacer()
                    Circle().fill(glowColor).frame(width: 4, height: 4)
                }
                .foregroundStyle(glowColor)
                .padding(.bottom, 2)
                .overlay(Rectangle().fill(glowColor.opacity(0.4)).frame(height: 1), alignment: .bottom)

                Text(title)
                    .font(.system(size: size.previewFontSize * 0.85, weight: .bold, design: .monospaced))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Text(message)
                    .font(.system(size: size.previewFontSize * 0.75, weight: .regular, design: .monospaced))
                    .foregroundStyle(glowColor)
                    .lineLimit(size == .large ? 1 : 2)
                Spacer(minLength: 0)
            }
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var indicatorLabel: Text {
        switch content {
        case .text(_, let size), .notification(_, _, _, let size):
            return Text("\(size.displayName) text")
        case .image(_, let scale):
            return Text("\(scale)% size")
        case .face(let e):
            return Text(e.displayName)
        }
    }
}

/// Tints a white-on-black 1-bit preview like the OLED: lit pixels in the eye colour,
/// or (inverted) dark pixels on a lit screen.
private struct PixelTint: ViewModifier {
    var inverted: Bool
    var lit: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if inverted {
            content.colorInvert().colorMultiply(lit)
        } else {
            content.colorMultiply(lit)
        }
    }
}
