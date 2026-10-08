import SwiftUI

/// Four tiny games that run on the robot itself (Spec §32–§39).
struct PlayView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var explainingGame: NobiGame?
    @State private var thump = 0

    var body: some View {
        NobiPage(spacing: 24, topPadding: 4) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Played on \(robot.name)'s own buttons.")
                    .font(NobiFont.body(16))
                    .foregroundStyle(NobiTheme.ink2)
                SendTargetLine()
            }

            if robot.isConnected && robot.deviceState.activeGame != "none" {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playing now")
                            .font(NobiFont.body(13))
                            .foregroundStyle(NobiTheme.ink3)
                        Text(NobiGame(rawValue: robot.deviceState.activeGame)?.title ?? robot.deviceState.activeGame.capitalized)
                            .font(NobiFont.body(17, .semibold))
                            .foregroundStyle(NobiTheme.ink)
                    }
                    Spacer()
                    Button("Stop") {
                        thump += 1
                        fleet.perform { $0.stopGame() }
                    }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
                }
                .inkCard(radius: 22, padding: 16)
            }

            InkGroup {
                ForEach(Array(NobiGame.allCases.enumerated()), id: \.element.id) { i, game in
                    InkRow(title: game.title,
                           subtitle: game.bestScore > 0 ? "Best \(game.bestScore)" : game.subtitle,
                           showDivider: i < NobiGame.allCases.count - 1) {
                        RowIcon(systemName: game.icon)
                    } trailing: {
                        Button("Play") {
                            thump += 1
                            fleet.perform { $0.launchGame(game) }
                        }
                        .buttonStyle(InkButtonStyle(kind: .primary, size: .small))
                        .disabled(!fleet.canSend)
                    }
                    .onTapGesture { explainingGame = game }
                }
            }

            Text("Tap a game to see how to play.")
                .font(NobiFont.body(13))
                .foregroundStyle(NobiTheme.ink3)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: thump)
        .sheet(item: $explainingGame) { game in
            HowToPlaySheet(game: game)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            if robot.isConnected { robot.requestGameScores() }
        }
    }
}

/// How to play, with the robot's buttons (Spec §35–§40).
private struct HowToPlaySheet: View {
    let game: NobiGame

    var body: some View {
        NobiPage(spacing: 24, topPadding: 30) {
            ScreenIntro(title: game.title, sub: game.subtitle, size: 28)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(game.howToPlayRules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(NobiTheme.ink3).frame(width: 5, height: 5).padding(.top, 8)
                        Text(rule)
                            .font(NobiFont.body(15))
                            .foregroundStyle(NobiTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            InkGroup(header: "Buttons") {
                ForEach(Array(game.controls.enumerated()), id: \.offset) { i, guide in
                    HStack {
                        Text(guide.button)
                            .font(NobiFont.body(15, .medium))
                            .foregroundStyle(NobiTheme.ink)
                        Spacer()
                        Text(guide.action)
                            .font(NobiFont.body(14))
                            .foregroundStyle(NobiTheme.ink2)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if i < game.controls.count - 1 {
                        Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                    }
                }
            }
        }
        .background { PaperBackground() }
    }
}
