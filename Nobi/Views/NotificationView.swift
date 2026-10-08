import SwiftUI

/// A little note pinned to the robot's screen (Spec §14).
struct NotificationView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var app = "Home"
    @State private var title = "Reminder"
    @State private var message = "Dinner at 8?"
    @State private var selectedSize: NobiTextSize = .medium
    @State private var thump = 0

    enum Field: Hashable { case app, title, message }
    @FocusState private var focusedField: Field?

    private let templates: [(String, String, String)] = [
        ("Home", "Dinner", "Dinner at 8?"),
        ("Home", "Water", "Drink some water!"),
        ("Focus", "Break", "Stretch and rest your eyes."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OLEDPreviewView(
                content: .notification(app: NobiProtocol.sanitizePipeField(app), title: title, message: message, size: selectedSize),
                plate: robot.profile.plate,
                inverted: robot.deviceState.inverted
            )

            VStack(spacing: 0) {
                field("From", text: $app, focus: .app, next: .title)
                Rectangle().fill(NobiTheme.line).frame(height: 1)
                field("Title", text: $title, focus: .title, next: .message)
                Rectangle().fill(NobiTheme.line).frame(height: 1)
                TextField("Message", text: $message, axis: .vertical)
                    .font(NobiFont.body(16))
                    .foregroundStyle(NobiTheme.ink)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .message)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NobiTheme.paper2))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates, id: \.1) { t in
                        InkChip(title: t.1, selected: false) {
                            focusedField = nil
                            app = t.0
                            title = t.1
                            message = t.2
                        }
                    }
                }
            }
            .scrollClipDisabled()

            InkSegmented(options: NobiTextSize.allCases.map { (value: $0, title: $0.displayName) }, selection: $selectedSize)
                .onChange(of: selectedSize) { _, size in
                    fleet.perform { $0.sendTextSize(size.rawValue) }
                }

            VStack(spacing: 6) {
                Button {
                    thump += 1
                    focusedField = nil
                    let a = app, t = title, m = message, s = selectedSize.rawValue
                    fleet.perform { $0.sendNotification(app: a, title: t, message: m, size: s) }
                } label: {
                    Text("Pin note")
                }
                .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                .disabled(!fleet.canSend || app.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Back to face") {
                    focusedField = nil
                    fleet.perform { $0.sendFace() }
                }
                .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                .disabled(!fleet.canSend)
            }
        }
        .dismissKeyboardToolbar { focusedField = nil }
        .sensoryFeedback(.success, trigger: thump)
        .onAppear {
            if let synced = NobiTextSize(rawValue: robot.deviceState.textSize) { selectedSize = synced }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, focus: Field, next: Field) -> some View {
        HStack {
            Text(placeholder)
                .font(NobiFont.body(15))
                .foregroundStyle(NobiTheme.ink3)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder, text: text)
                .font(NobiFont.body(16))
                .foregroundStyle(NobiTheme.ink)
                .focused($focusedField, equals: focus)
                .submitLabel(.next)
                .onSubmit { focusedField = next }
        }
        .padding(.vertical, 14)
    }
}
