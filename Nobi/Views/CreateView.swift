import SwiftUI

/// Create: one canvas — the robot's screen — and four ways to fill it.
struct CreateView: View {
    enum Section: String, CaseIterable, Identifiable, Hashable {
        case faces = "Face"
        case words = "Words"
        case photo = "Photo"
        case note = "Note"
        var id: String { rawValue }
    }

    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot
    @State private var section: Section = .faces

    var body: some View {
        NobiPage(spacing: 22, topPadding: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Create")
                        .font(NobiFont.display(34))
                        .foregroundStyle(NobiTheme.ink)
                    Spacer()
                    if robot.supportsKairoFeatures {
                        Button {
                            let on = !robot.deviceState.hold
                            fleet.perform { $0.setHold(on) }
                        } label: {
                            Image(systemName: robot.deviceState.hold ? "pin.fill" : "pin")
                        }
                        .buttonStyle(InkIconButtonStyle(size: 38))
                        .disabled(!fleet.canSend)
                        .accessibilityLabel(robot.deviceState.hold ? "Stop keeping on screen" : "Keep on screen")
                        Button {
                            let on = !robot.deviceState.inverted
                            fleet.perform { $0.setInverted(on) }
                        } label: {
                            Image(systemName: robot.deviceState.inverted ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                        }
                        .buttonStyle(InkIconButtonStyle(size: 38))
                        .disabled(!fleet.canSend)
                        .accessibilityLabel(robot.deviceState.inverted ? "Normal colors" : "Invert colors")
                    }
                }
                SendTargetLine()
                if robot.supportsKairoFeatures && robot.deviceState.hold {
                    Label("Pinned — what you send stays on screen", systemImage: "pin.fill")
                        .font(NobiFont.body(13))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }

            InkSegmented(options: Section.allCases.map { (value: $0, title: $0.rawValue) }, selection: $section)
                .onChange(of: section) { _, _ in hideKeyboard() }

            Group {
                switch section {
                case .faces: EmotionsView()
                case .words: TextSendView()
                case .photo: NobiImageView()
                case .note: NotificationView()
                }
            }
            .id(section)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: section)
    }
}
