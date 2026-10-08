import SwiftUI

/// Sixteen faces. Tap one and it appears on the robot.
struct EmotionsView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OLEDPreviewView(content: .face(robot.currentEmotion), plate: robot.profile.plate, inverted: robot.deviceState.inverted)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(NobiEmotion.allCases) { emotion in
                    let isCurrent = robot.currentEmotion == emotion
                    Button {
                        fleet.perform { $0.sendEmotion(emotion) }
                        if !robot.isConnected { robot.noteMood(emotion) }
                    } label: {
                        VStack(spacing: 8) {
                            OLEDFaceView(emotion: emotion, color: NobiTheme.eyeColor(robot.profile.plate),
                                         live: isCurrent, showScreen: true, glow: false,
                                         inverted: robot.deviceState.inverted)
                                .frame(height: 30)
                                .padding(.horizontal, 6)
                            Text(emotion.displayName)
                                .font(NobiFont.body(12, isCurrent ? .semibold : .regular))
                                .foregroundStyle(isCurrent ? NobiTheme.ink : NobiTheme.ink2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(InkTileStyle(selected: isCurrent, radius: 16))
                    .disabled(!fleet.canSend)
                    .sensoryFeedback(.selection, trigger: isCurrent)
                    .accessibilityLabel(emotion.displayName)
                }
            }

            if robot.isConnected && !robot.deviceState.lifeModeEnabled {
                HStack {
                    Text("\(robot.name) holds this face until you let it be itself.")
                        .font(NobiFont.body(14))
                        .foregroundStyle(NobiTheme.ink3)
                    Spacer(minLength: 8)
                    Button("Let it be") { fleet.perform { $0.sendLifeMode(enabled: true) } }
                        .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
                }
            }
        }
    }
}
