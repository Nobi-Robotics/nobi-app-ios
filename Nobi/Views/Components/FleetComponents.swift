import SwiftUI

// MARK: - Page scaffolding

/// Large serif title with an optional one-line subtitle.
struct ScreenIntro: View {
    var title: String
    var emphasis: String = ""
    var tail: String = ""
    var sub: String? = nil
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            InkHeadline(lead: title, emphasis: emphasis, tail: tail, size: size)
            if let sub {
                Text(sub)
                    .font(NobiFont.body(16))
                    .foregroundStyle(NobiTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Standard scrolling page with generous margins.
struct NobiPage<Content: View>: View {
    var spacing: CGFloat = 28
    var topPadding: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, topPadding)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Who am I talking to?

/// One quiet line: "To Kairo" — or "To all 3 robots" — with a sync switch when there's more than one robot.
struct SendTargetLine: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    var body: some View {
        let targets = fleet.targets
        HStack(spacing: 10) {
            AvatarStack(robots: targets.isEmpty ? [robot] : targets, size: 26)
            if targets.isEmpty {
                Text("\(robot.name) is offline")
                    .font(NobiFont.body(15, .medium))
                    .foregroundStyle(NobiTheme.ink2)
                Spacer(minLength: 4)
                Button("Find") { fleet.connect(robot) }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
                    .disabled(!fleet.bluetooth.isReady || robot.link == .connecting)
            } else {
                Text(targets.count > 1 ? "To all \(targets.count) robots" : "To \(fleet.targetSummary)")
                    .font(NobiFont.body(15, .medium))
                    .foregroundStyle(NobiTheme.ink2)
                Spacer(minLength: 4)
                if fleet.canSync {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { fleet.syncEnabled.toggle() }
                    } label: {
                        Label(fleet.syncEnabled ? "Together" : "Just one", systemImage: fleet.syncEnabled ? "link" : "circle")
                            .font(NobiFont.body(13, .semibold))
                            .foregroundStyle(NobiTheme.ink2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Switch between sending to one robot and all of them")
                }
            }
        }
    }
}

/// Overlapping robot avatars.
struct AvatarStack: View {
    var robots: [NobiRobot]
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: -size * 0.4) {
            ForEach(Array(robots.prefix(4).enumerated()), id: \.element.id) { i, r in
                RobotAvatar(plate: r.profile.plate, emotion: r.currentEmotion, size: size, dimmed: !r.isConnected)
                    .zIndex(Double(10 - i))
            }
        }
    }
}

// MARK: - Empty states

/// First launch: no robots yet. One picture, one sentence, one button.
struct WelcomeView: View {
    @EnvironmentObject var fleet: NobiFleet
    @Environment(\.shell) private var shell

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    BoilingArt(prefix: "MascotWave")
                        .frame(height: min(250, geo.size.height * 0.36))
                        .accessibilityHidden(true)
                    InkHeadline(lead: "Every robot starts ", emphasis: "alone", tail: ".", size: 34, alignment: .center)
                        .padding(.top, 32)
                    Text("Pair your Kairo to begin.")
                        .font(NobiFont.body(17))
                        .foregroundStyle(NobiTheme.ink2)
                        .padding(.top, 10)
                    Spacer(minLength: 32)
                    VStack(spacing: 12) {
                        if !fleet.bluetooth.isReady {
                            Text(fleet.bluetooth.help)
                                .font(NobiFont.body(14))
                                .foregroundStyle(NobiTheme.ink3)
                                .multilineTextAlignment(.center)
                        }
                        Button { shell.openPairing() } label: { Text("Pair a robot") }
                            .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                            .disabled(!fleet.bluetooth.isReady)
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
    }
}

/// Create without a robot.
struct NoRobotView: View {
    @Environment(\.shell) private var shell

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            InkHeadline(lead: "Nothing to ", emphasis: "draw", tail: " on yet.", size: 30, alignment: .center)
            Text("Pair a robot and its screen becomes your canvas.")
                .font(NobiFont.body(16))
                .foregroundStyle(NobiTheme.ink2)
                .multilineTextAlignment(.center)
            Button { shell.openPairing() } label: { Text("Pair a robot") }
                .buttonStyle(InkButtonStyle(kind: .primary, size: .large))
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

/// Shown only when Bluetooth can't be used.
struct BluetoothNotice: View {
    @EnvironmentObject var fleet: NobiFleet

    var body: some View {
        if !fleet.bluetooth.isReady {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NobiTheme.ink2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fleet.bluetooth.displayName)
                        .font(NobiFont.body(15, .semibold))
                        .foregroundStyle(NobiTheme.ink)
                    Text(fleet.bluetooth.help)
                        .font(NobiFont.body(14))
                        .foregroundStyle(NobiTheme.ink2)
                }
            }
            .inkCard(radius: 18, padding: 14)
        }
    }
}

// MARK: - Robot switcher

struct RobotSwitcherSheet: View {
    @EnvironmentObject var fleet: NobiFleet
    @Environment(\.shell) private var shell
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your robots")
                .font(NobiFont.display(26))
                .foregroundStyle(NobiTheme.ink)
                .padding(.top, 28)

            InkGroup {
                ForEach(Array(fleet.robots.enumerated()), id: \.element.id) { i, r in
                    Button {
                        withAnimation { fleet.setActive(r) }
                        dismiss()
                    } label: {
                        SwitcherRow(robot: r, isActive: r.id == fleet.activeRobot?.id, showDivider: i < fleet.robots.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }

            if fleet.canSync {
                Toggle(isOn: $fleet.syncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Move together")
                            .font(NobiFont.body(16, .semibold))
                            .foregroundStyle(NobiTheme.ink)
                        Text("Everything you send goes to every robot.")
                            .font(NobiFont.body(13))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 6)
            }

            Spacer(minLength: 0)

            Button { shell.openPairing() } label: { Label("Pair a robot", systemImage: "plus") }
                .buttonStyle(InkButtonStyle(kind: .secondary, fullWidth: true))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .background { PaperBackground() }
    }
}

private struct SwitcherRow: View {
    @ObservedObject var robot: NobiRobot
    var isActive: Bool
    var showDivider: Bool

    var body: some View {
        InkRow(title: robot.name, subtitle: robot.link.displayName, showDivider: showDivider) {
            RobotAvatar(plate: robot.profile.plate, emotion: robot.currentEmotion, size: 40, dimmed: !robot.isConnected)
        } trailing: {
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NobiTheme.ink)
            }
        }
    }
}
