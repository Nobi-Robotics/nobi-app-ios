import SwiftUI

/// Home: your robot, alive on the page. Three things to do, two places to go.
struct HomeView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot
    @Environment(\.shell) private var shell

    @State private var showSnacks = false
    @State private var feedback: String?
    @State private var feedbackEmotion: NobiEmotion?
    @State private var thump = 0

    var body: some View {
        NobiPage(spacing: 0, topPadding: 8) {
            header

            hero
                .padding(.top, 20)

            statusLine
                .padding(.top, 14)

            quickActions
                .padding(.top, 30)

            if robot.supportsKairoFeatures {
                TodayGoalsCard()
                    .padding(.top, 34)
            }

            bond
                .padding(.top, robot.supportsKairoFeatures ? 16 : 34)

            activities
                .padding(.top, 16)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: thump)
        .sheet(isPresented: $showSnacks) {
            snackSheet
                .presentationDetents([.height(290)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            if robot.isConnected { robot.requestLifeStats() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { shell.openSwitcher() } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(robot.name)
                        .font(NobiFont.display(34))
                        .foregroundStyle(NobiTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(robot.name). Switch robot")

            Spacer(minLength: 8)

            if fleet.isBroadcasting {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(fleet.targets.count) together")
                        .font(NobiFont.body(13, .medium))
                }
                .foregroundStyle(NobiTheme.ink2)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(NobiTheme.paper2))
            } else {
                StatusPill(link: robot.link)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(NobiTheme.ink.opacity(0.06))
                .frame(width: 190, height: 22)
                .blur(radius: 6)
                .offset(y: 6)
            KairoView(
                plate: robot.profile.plate,
                emotion: feedbackEmotion ?? robot.currentEmotion,
                live: true,
                inverted: robot.deviceState.inverted,
                onTap: { pet() },
                onStroke: { pet() }
            )
            .frame(height: 300)
            .saturation(robot.isConnected ? 1 : 0.35)
            .opacity(robot.isConnected ? 1 : 0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusLine: some View {
        VStack(spacing: 12) {
            if let feedback {
                Text(feedback)
                    .font(NobiFont.body(16, .medium))
                    .foregroundStyle(NobiTheme.ink)
                    .transition(.opacity)
            } else if robot.isConnected {
                Text(robot.deviceState.sleeping ? "Sleeping" : "Feeling \(robot.currentEmotion.feeling)")
                    .font(NobiFont.body(16))
                    .foregroundStyle(NobiTheme.ink2)
                    .transition(.opacity)
            } else {
                Text(robot.link == .offline ? "Not connected" : "Looking for \(robot.name)…")
                    .font(NobiFont.body(16))
                    .foregroundStyle(NobiTheme.ink2)
                if robot.link == .offline {
                    Button("Connect") { fleet.connect(robot) }
                        .buttonStyle(InkButtonStyle(kind: .primary, size: .small))
                        .disabled(!fleet.bluetooth.isReady)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: feedback)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 0) {
            QuickActionButton(title: "Pet", icon: "hand.wave") { pet() }
            QuickActionButton(title: "Feed", icon: "leaf") { showSnacks = true }
            QuickActionButton(title: robot.deviceState.sleeping ? "Wake" : "Sleep",
                              icon: robot.deviceState.sleeping ? "sun.max" : "moon") { toggleSleep() }
                .disabled(!robot.isConnected)
        }
    }

    // MARK: - Bond

    private var bond: some View {
        let p = robot.profile
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bond")
                    .font(NobiFont.body(16, .semibold))
                    .foregroundStyle(NobiTheme.ink)
                Spacer()
                Text("Level \(p.bondLevel) · \(p.bondLevelTitle)")
                    .font(NobiFont.body(14, .medium))
                    .foregroundStyle(NobiTheme.ink3)
            }
            InkProgressBar(value: p.xpProgressInLevel, tint: NobiTheme.ink, height: 5)
        }
        .inkCard(radius: 22, padding: 18)
    }

    // MARK: - Activities

    private var activities: some View {
        InkGroup {
            NavigationLink(value: Route.games) {
                InkRow(title: "Games", subtitle: "Four tiny games on its screen") {
                    RowIcon(systemName: "gamecontroller")
                } trailing: {
                    Chevron()
                }
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.focus) {
                InkRow(title: "Focus", subtitle: "Work and break timer, together") {
                    RowIcon(systemName: "timer")
                } trailing: {
                    Chevron()
                }
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.reminders) {
                InkRow(title: "Reminders", subtitle: "Water, stretch, eyes, bedtime") {
                    RowIcon(systemName: "bell")
                } trailing: {
                    Chevron()
                }
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.music) {
                InkRow(title: "Music", subtitle: "Songs on its buzzer, or write your own", showDivider: false) {
                    RowIcon(systemName: "music.note")
                } trailing: {
                    Chevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Snacks

    private var snackSheet: some View {
        VStack(spacing: 22) {
            Text("A little treat")
                .font(NobiFont.display(26))
                .foregroundStyle(NobiTheme.ink)
                .padding(.top, 30)
            HStack(spacing: 12) {
                ForEach(NobiSnack.allCases) { snack in
                    Button { feed(snack) } label: {
                        VStack(spacing: 10) {
                            Image(systemName: snack.icon)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(NobiTheme.ink)
                            Text(snack.title)
                                .font(NobiFont.body(14, .medium))
                                .foregroundStyle(NobiTheme.ink)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .padding(8)
                    }
                    .buttonStyle(InkTileStyle())
                }
            }
            .padding(.horizontal, 22)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PaperBackground() }
    }

    // MARK: - Actions

    private func pet() {
        robot.stroke()
        thump += 1
        say("♥")
        showLove()
    }

    private func feed(_ snack: NobiSnack) {
        showSnacks = false
        robot.feed(snack)
        thump += 1
        say("Yum, \(snack.title.lowercased())")
        showLove()
    }

    private func showLove() {
        withAnimation { feedbackEmotion = .love }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { feedbackEmotion = nil }
        }
    }

    private func toggleSleep() {
        thump += 1
        if robot.deviceState.sleeping {
            fleet.perform { $0.wake() }
        } else {
            fleet.perform { $0.sleep() }
        }
    }

    private func say(_ msg: String) {
        withAnimation { feedback = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if feedback == msg { withAnimation { feedback = nil } }
        }
    }
}
