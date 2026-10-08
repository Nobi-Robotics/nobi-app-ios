import SwiftUI

/// A few words on the robot's screen (Spec §11–§13).
struct TextSendView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var message = ""
    @State private var selectedSize: NobiTextSize = .medium
    @State private var thump = 0
    @FocusState private var isMessageFocused: Bool

    private let suggestions = ["Good morning!", "You got this!", "Snack time!", "Be right back", "Miss you!"]

    private var sanitized: String { NobiProtocol.sanitizeText(message) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OLEDPreviewView(content: .text(message: sanitized, size: selectedSize), plate: robot.profile.plate, inverted: robot.deviceState.inverted)

            TextField("Write something…", text: $message, axis: .vertical)
                .font(NobiFont.body(18))
                .foregroundStyle(NobiTheme.ink)
                .lineLimit(1...3)
                .focused($isMessageFocused)
                .submitLabel(.send)
                .inkWell(radius: 18, padding: 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        InkChip(title: s, selected: false) {
                            message = s
                            isMessageFocused = false
                        }
                    }
                }
            }
            .scrollClipDisabled()

            VStack(alignment: .leading, spacing: 10) {
                Text("Size")
                    .font(NobiFont.body(14, .medium))
                    .foregroundStyle(NobiTheme.ink3)
                InkSegmented(options: NobiTextSize.allCases.map { (value: $0, title: $0.displayName) }, selection: $selectedSize)
                    .onChange(of: selectedSize) { _, size in
                        fleet.perform { $0.sendTextSize(size.rawValue) }
                    }
            }

            Button {
                thump += 1
                isMessageFocused = false
                let text = message
                let size = selectedSize.rawValue
                fleet.perform { $0.sendText(text, size: size) }
                fleet.recordText(text)
            } label: {
                Text("Send")
            }
            .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
            .disabled(!fleet.canSend || sanitized.isEmpty)
        }
        .dismissKeyboardToolbar { isMessageFocused = false }
        .sensoryFeedback(.success, trigger: thump)
        .onAppear {
            if let synced = NobiTextSize(rawValue: robot.deviceState.textSize) { selectedSize = synced }
        }
    }
}

/// Simple left-aligned wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
