import CoreText
import SwiftUI
import UIKit

// MARK: - Palette
//
// Calm by design: warm paper and sumi ink by day, deep indigo by night.
// Red is an accent, used sparingly. Hairlines instead of heavy outlines.

enum NobiTheme {
    static func dynamicUI(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(dynamicUI(light, dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    // Surfaces
    static let uiPaper = dynamicUI(0xF6F1E7, 0x13152F)
    static let paper = Color(uiPaper)
    static let paper2 = dynamic(0xEEE7D8, 0x1B1E42)
    static let card = dynamic(0xFCFAF5, 0x1E2148)

    // Text
    static let uiInk = dynamicUI(0x1F1D1B, 0xFBF3E4)
    static let ink = Color(uiInk)
    static let ink2 = dynamic(0x5B554E, 0xC9C2DC)
    static let ink3 = dynamic(0x9A9187, 0x8A84AE)

    /// Hairline borders and dividers.
    static let line = dynamic(0x1F1D1B, 0xFBF3E4, lightAlpha: 0.11, darkAlpha: 0.13)
    /// Full-strength ink for illustrations (avatars, plates).
    static let inkLine = dynamic(0x1F1D1B, 0xF1E6D2, darkAlpha: 0.9)
    /// Soft card shadow (invisible at night).
    static let softShadow = dynamic(0x1F1D1B, 0x000000, lightAlpha: 0.06, darkAlpha: 0.0)

    // Accents
    static let red = dynamic(0xD8352A, 0xFF5A4E)
    static let redDeep = dynamic(0xB52A20, 0xFF7A6E)
    static let onRed = Color(UIColor(hex: 0xFFF8EC))
    static let yellow = Color(UIColor(hex: 0xF4CF2C))
    static let yellowDeep = Color(UIColor(hex: 0xD9AE1C))
    static let cyan = Color(UIColor(hex: 0x4DF2E6))
    static let online = dynamic(0x2E9A6B, 0x5FE3A1)
    static let pink = dynamic(0xE8557F, 0xFF6FAE)
    static let leaf = dynamic(0x5E9E4B, 0x8FD27A)
    static let eyebrow = dynamic(0x9A9187, 0x8A84AE)
    /// Selected tile tint.
    static let highlight = dynamic(0xEFE6D0, 0x2A2E62)

    // Hardware colours from the robot itself
    static let robotBody = Color(UIColor(hex: 0x222024))
    static let plateYellow = Color(UIColor(hex: 0xE6D23A))
    static let plateWhite = Color(UIColor(hex: 0xDADAD6))
    static let screenMint = Color(UIColor(hex: 0x7FE3B8))
    static let screenBlack = Color(UIColor(hex: 0x121518))
    static let whiteEye = Color(UIColor(hex: 0xF4F8FF))

    static func plateColor(_ plate: FacePlate) -> Color {
        plate == .yellow ? plateYellow : plateWhite
    }

    static func eyeColor(_ plate: FacePlate) -> Color {
        plate == .yellow ? cyan : whiteEye
    }

    static func linkColor(_ link: RobotLink) -> Color {
        switch link {
        case .connected: return online
        case .connecting, .searching: return yellowDeep
        case .offline: return ink3
        }
    }

    /// Native navigation bar: quiet, paper-tinted, Instrument Sans titles, chevron-only back button.
    static func configureNavigationBar() {
        let titleFont = UIFont(name: "InstrumentSans-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        let largeFont = UIFont(name: "Fraunces-Regular", size: 34) ?? .systemFont(ofSize: 34, weight: .regular)

        let back = UIBarButtonItemAppearance()
        back.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        back.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)
        scrolled.backgroundColor = uiPaper.withAlphaComponent(0.72)
        scrolled.shadowColor = .clear
        scrolled.titleTextAttributes = [.font: titleFont, .foregroundColor: uiInk]
        scrolled.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: uiInk]
        scrolled.backButtonAppearance = back

        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = scrolled.titleTextAttributes
        edge.largeTitleTextAttributes = scrolled.largeTitleTextAttributes
        edge.backButtonAppearance = back

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.scrollEdgeAppearance = edge
        bar.tintColor = uiInk
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Type
//
// Fraunces (titles) · Instrument Sans (everything else) · IBM Plex Mono (tiny labels) · Gaegu (rare hand notes).

enum NobiFont {
    enum Weight { case regular, medium, semibold, bold }

    /// Registers the bundled fonts once at launch (also listed in Info.plist).
    static func register() {
        let names = [
            "Fraunces-Regular", "Fraunces-Italic", "Fraunces-SemiBold",
            "InstrumentSans-Regular", "InstrumentSans-Medium", "InstrumentSans-SemiBold", "InstrumentSans-Bold",
            "IBMPlexMono-Regular", "IBMPlexMono-Medium", "IBMPlexMono-SemiBold",
            "Gaegu-Bold",
        ]
        for name in names {
            guard UIFont(name: name, size: 12) == nil,
                  let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fraunces-Regular", size: size, relativeTo: style)
    }

    static func displayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fraunces-Italic", size: size, relativeTo: style)
    }

    static func title(_ size: CGFloat = 20, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom("Fraunces-SemiBold", size: size, relativeTo: style)
    }

    static func body(_ size: CGFloat = 16, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .regular: name = "InstrumentSans-Regular"
        case .medium: name = "InstrumentSans-Medium"
        case .semibold: name = "InstrumentSans-SemiBold"
        case .bold: name = "InstrumentSans-Bold"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat = 12, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .caption) -> Font {
        let name: String
        switch weight {
        case .regular: name = "IBMPlexMono-Regular"
        case .medium: name = "IBMPlexMono-Medium"
        case .semibold, .bold: name = "IBMPlexMono-SemiBold"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    static func hand(_ size: CGFloat = 20, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Gaegu-Bold", size: size, relativeTo: style)
    }
}

// MARK: - Surfaces

struct InkCardModifier: ViewModifier {
    var fill: Color = NobiTheme.card
    var radius: CGFloat = 24
    var padding: CGFloat = 20
    var dashed: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: NobiTheme.softShadow, radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(NobiTheme.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 5] : []))
            )
    }
}

extension View {
    /// Quiet card: soft paper surface, hairline edge, gentle shadow by day.
    func inkCard(
        fill: Color = NobiTheme.card,
        radius: CGFloat = 24,
        padding: CGFloat = 20,
        dashed: Bool = false
    ) -> some View {
        modifier(InkCardModifier(fill: fill, radius: radius, padding: padding, dashed: dashed))
    }

    /// Recessed field background.
    func inkWell(radius: CGFloat = 16, padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(NobiTheme.paper2))
    }
}

// MARK: - Buttons

struct InkButtonStyle: ButtonStyle {
    enum Kind {
        /// Solid ink — the one main action on a screen.
        case primary
        /// Hairline outline.
        case secondary
        /// Brand red — reserved for special moments (pairing).
        case accent
        /// Text only.
        case plain
    }
    enum Size { case small, regular, large }

    var kind: Kind = .secondary
    var size: Size = .regular
    var fullWidth: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    private var height: CGFloat {
        switch size {
        case .small: return 38
        case .regular: return 50
        case .large: return 56
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return NobiTheme.ink
        case .accent: return NobiTheme.red
        case .secondary, .plain: return .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return NobiTheme.paper
        case .accent: return NobiTheme.onRed
        case .secondary, .plain: return NobiTheme.ink
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .font(NobiFont.body(size == .small ? 14 : 16, .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .plain ? 4 : (size == .small ? 16 : 22))
            .frame(minHeight: height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule(style: .continuous).fill(fill))
            .overlay {
                if kind == .secondary {
                    Capsule(style: .continuous).strokeBorder(NobiTheme.ink.opacity(0.18), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(isEnabled ? (pressed ? 0.85 : 1) : 0.35)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

/// Soft selectable tile (emotion tiles, snacks).
struct InkTileStyle: ButtonStyle {
    var selected: Bool = false
    var radius: CGFloat = 18

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? NobiTheme.highlight : NobiTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(selected ? NobiTheme.ink.opacity(0.85) : NobiTheme.line, lineWidth: selected ? 1.5 : 1)
            )
            .scaleEffect(pressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }
}

/// Round icon button.
struct InkIconButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    var fill: Color = NobiTheme.card

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(NobiTheme.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(NobiTheme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Large circular quick action with a label underneath (Home: Pet · Feed · Sleep).
struct QuickActionButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(NobiTheme.ink)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(NobiTheme.card).shadow(color: NobiTheme.softShadow, radius: 10, y: 4))
                    .overlay(Circle().strokeBorder(NobiTheme.line, lineWidth: 1))
                Text(title)
                    .font(NobiFont.body(13, .medium))
                    .foregroundStyle(NobiTheme.ink2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.35)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Selection controls

/// Pill chip. Selected = ink pill.
struct InkChip: View {
    var title: String
    var icon: String? = nil
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(NobiFont.body(14, .medium))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .foregroundStyle(selected ? NobiTheme.paper : NobiTheme.ink)
            .background(Capsule().fill(selected ? NobiTheme.ink : Color.clear))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : NobiTheme.ink.opacity(0.16), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Segmented control with a sliding ink thumb.
struct InkSegmented<Value: Hashable>: View {
    var options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i]
                let isOn = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(NobiFont.body(14, .semibold))
                        .foregroundStyle(isOn ? NobiTheme.paper : NobiTheme.ink2)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isOn {
                                Capsule().fill(NobiTheme.ink).matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(NobiTheme.paper2))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? NobiTheme.ink : NobiTheme.paper2)
                        .frame(width: 50, height: 30)
                    Circle()
                        .fill(configuration.isOn ? NobiTheme.paper : NobiTheme.card)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
    }
}

// MARK: - Grouped rows

/// A card holding rows separated by hairlines.
struct InkGroup<Content: View>: View {
    var header: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header)
                    .font(NobiFont.body(13, .semibold))
                    .foregroundStyle(NobiTheme.ink3)
                    .padding(.leading, 6)
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NobiTheme.card)
                    .shadow(color: NobiTheme.softShadow, radius: 14, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NobiTheme.line, lineWidth: 1))
            if let footer {
                Text(footer)
                    .font(NobiFont.body(13))
                    .foregroundStyle(NobiTheme.ink3)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One row inside an InkGroup.
struct InkRow<Leading: View, Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    var showDivider: Bool = true
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NobiFont.body(16, .medium))
                        .foregroundStyle(NobiTheme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(NobiFont.body(13))
                            .foregroundStyle(NobiTheme.ink3)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            if showDivider {
                Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
            }
        }
    }
}

/// Icon in a soft rounded square, for rows.
struct RowIcon: View {
    var systemName: String
    var tint: Color = NobiTheme.ink

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NobiTheme.paper2))
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NobiTheme.ink3)
    }
}

// MARK: - Text styles

/// Small quiet label above a section.
struct Eyebrow: View {
    var text: String
    var color: Color = NobiTheme.eyebrow

    var body: some View {
        Text(text.uppercased())
            .font(NobiFont.mono(11, .medium))
            .tracking(1.4)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Serif headline with an optional italic accent word.
struct InkHeadline: View {
    var lead: String
    var emphasis: String = ""
    var tail: String = ""
    var size: CGFloat = 34
    var alignment: TextAlignment = .leading

    var body: some View {
        (Text(lead).font(NobiFont.display(size))
            + Text(emphasis).font(NobiFont.displayItalic(size))
            + Text(tail).font(NobiFont.display(size)))
            .foregroundStyle(NobiTheme.ink)
            .tracking(-0.5)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Section title with optional subtitle and trailing value.
struct InkSectionTitle: View {
    var title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NobiFont.body(17, .semibold))
                    .foregroundStyle(NobiTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(NobiFont.body(14))
                        .foregroundStyle(NobiTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(NobiFont.body(14, .medium))
                    .foregroundStyle(NobiTheme.ink3)
                    .monospacedDigit()
            }
        }
    }
}

/// Hand-written note in Gaegu (use rarely).
struct HandNote: View {
    var text: String
    var color: Color = NobiTheme.ink3
    var size: CGFloat = 19
    var rotation: Double = 0

    var body: some View {
        Text(text)
            .font(NobiFont.hand(size))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotation))
    }
}

/// Label + value row.
struct InkReadoutRow: View {
    var label: String
    var value: String
    var valueColor: Color = NobiTheme.ink

    var body: some View {
        HStack {
            Text(label)
                .font(NobiFont.body(15))
                .foregroundStyle(NobiTheme.ink2)
            Spacer()
            Text(value)
                .font(NobiFont.body(15, .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Meters & status

struct InkProgressBar: View {
    var value: Double // 0...1
    var tint: Color = NobiTheme.ink
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NobiTheme.paper2)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(min(1, max(0, value)))))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
    }
}

struct InkMeter: View {
    var title: String
    var icon: String
    var value: Int
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NobiFont.body(13, .medium))
                .foregroundStyle(NobiTheme.ink3)
            Text("\(value)%")
                .font(NobiFont.body(20, .semibold))
                .foregroundStyle(NobiTheme.ink)
                .contentTransition(.numericText())
            InkProgressBar(value: Double(value) / 100, tint: tint, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value) percent")
    }
}

struct StatusDot: View {
    var link: RobotLink
    var size: CGFloat = 7
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(NobiTheme.linkColor(link))
            .frame(width: size, height: size)
            .opacity(link == .searching || link == .connecting ? (pulse ? 0.3 : 1) : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

/// "● Online" pill.
struct StatusPill: View {
    var link: RobotLink

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(link: link)
            Text(link.displayName)
                .font(NobiFont.body(13, .medium))
                .foregroundStyle(NobiTheme.ink2)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(NobiTheme.paper2))
    }
}

struct SignalBars: View {
    var bars: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? NobiTheme.ink2 : NobiTheme.ink3.opacity(0.3))
                    .frame(width: 3, height: CGFloat(5 + i * 3))
            }
        }
        .accessibilityLabel("Signal \(bars) of 3")
    }
}

/// Small quiet tag ("Soon").
struct TagLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(NobiFont.body(12, .semibold))
            .foregroundStyle(NobiTheme.ink2)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(NobiTheme.paper2))
    }
}

// MARK: - Keyboard helpers

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func dismissKeyboardToolbar(onDismiss: (() -> Void)? = nil) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                    onDismiss?()
                }
                .font(NobiFont.body(15, .semibold))
                .foregroundStyle(NobiTheme.ink)
            }
        }
    }
}
