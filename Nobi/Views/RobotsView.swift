import SwiftUI

// MARK: - Robots (tab root)

/// Your robots, the group switch, and everything else tucked one tap away.
struct RobotsView: View {
    @EnvironmentObject var fleet: NobiFleet
    @Environment(\.shell) private var shell

    var body: some View {
        NobiPage(spacing: 26, topPadding: 8) {
            Text("Robots")
                .font(NobiFont.display(34))
                .foregroundStyle(NobiTheme.ink)

            BluetoothNotice()

            InkGroup {
                ForEach(fleet.robots) { r in
                    NavigationLink(value: Route.robot(r.id)) {
                        RobotListRow(robot: r, isActive: r.id == fleet.activeRobot?.id)
                    }
                    .buttonStyle(.plain)
                }
                Button { shell.openPairing() } label: {
                    InkRow(title: "Pair a robot", showDivider: false) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NobiTheme.ink)
                            .frame(width: 40, height: 40)
                            .background(Circle().strokeBorder(NobiTheme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    } trailing: {
                        EmptyView()
                    }
                }
                .buttonStyle(.plain)
                .disabled(!fleet.bluetooth.isReady)
            }

            if fleet.canSync {
                InkGroup(footer: "Faces, words, photos, games and timers go to every robot in the group.") {
                    Toggle(isOn: $fleet.syncEnabled) {
                        Text("Move together")
                            .font(NobiFont.body(16, .medium))
                            .foregroundStyle(NobiTheme.ink)
                    }
                    .toggleStyle(InkToggleStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            InkGroup {
                NavigationLink(value: Route.comingSoon) {
                    InkRow(title: "Coming soon", subtitle: "Aura, Camera Bot and one more") {
                        RowIcon(systemName: "shippingbox")
                    } trailing: {
                        Chevron()
                    }
                }
                .buttonStyle(.plain)
                NavigationLink(value: Route.settings) {
                    InkRow(title: "Settings", showDivider: false) {
                        RowIcon(systemName: "gearshape")
                    } trailing: {
                        Chevron()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RobotListRow: View {
    @ObservedObject var robot: NobiRobot
    var isActive: Bool

    var body: some View {
        InkRow(title: robot.name, subtitle: isActive ? "\(robot.link.displayName) · Selected" : robot.link.displayName) {
            RobotAvatar(plate: robot.profile.plate, emotion: robot.currentEmotion, size: 40, dimmed: !robot.isConnected)
        } trailing: {
            HStack(spacing: 10) {
                StatusDot(link: robot.link)
                Chevron()
            }
        }
    }
}

// MARK: - Robot detail

/// One robot: its picture, its connection, and its display settings.
struct RobotDetailView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot
    @Environment(\.dismiss) private var dismiss

    @State private var brightness: Double = 180
    @State private var showRename = false
    @State private var renameText = ""
    @State private var confirmForget = false

    private var isActive: Bool { fleet.activeRobot?.id == robot.id }

    var body: some View {
        NobiPage(spacing: 26, topPadding: 0) {
            VStack(spacing: 14) {
                KairoView(plate: robot.profile.plate, emotion: robot.currentEmotion, live: robot.isConnected,
                          inverted: robot.deviceState.inverted)
                    .frame(height: 210)
                    .saturation(robot.isConnected ? 1 : 0.35)
                Text(robot.name)
                    .font(NobiFont.display(30))
                    .foregroundStyle(NobiTheme.ink)
                StatusPill(link: robot.link)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                if !isActive {
                    Button("Talk to \(robot.name)") {
                        withAnimation { fleet.setActive(robot) }
                    }
                    .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                }
                if robot.isConnected && robot.supportsKairoFeatures {
                    Button {
                        if robot.isFinding { robot.stopFind() } else { robot.startFind() }
                    } label: {
                        Label(robot.isFinding ? "Stop ringing" : "Find \(robot.name)",
                              systemImage: robot.isFinding ? "bell.slash" : "bell.and.waves.left.and.right")
                    }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .large, fullWidth: true))
                }
                if robot.isConnected {
                    Button("Disconnect") { fleet.disconnect(robot) }
                        .buttonStyle(InkButtonStyle(kind: isActive ? .secondary : .plain, fullWidth: true))
                } else {
                    Button(robot.link == .offline ? "Connect" : "Looking…") { fleet.connect(robot) }
                        .buttonStyle(InkButtonStyle(kind: isActive ? .primary : .secondary, size: .large, fullWidth: true))
                        .disabled(!fleet.bluetooth.isReady || robot.link != .offline)
                }
            }

            InkGroup(header: "Display") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Brightness")
                            .font(NobiFont.body(16, .medium))
                            .foregroundStyle(NobiTheme.ink)
                        Spacer()
                        Text("\(Int(brightness * 100 / 255))%")
                            .font(NobiFont.body(14))
                            .foregroundStyle(NobiTheme.ink3)
                            .monospacedDigit()
                    }
                    Slider(value: $brightness, in: 10...255, step: 5) { editing in
                        if !editing { robot.sendBrightness(Int(brightness)) }
                    }
                }
                .padding(16)
                Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                Toggle(isOn: Binding(
                    get: { robot.deviceState.lifeModeEnabled },
                    set: { robot.sendLifeMode(enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Life mode")
                            .font(NobiFont.body(16, .medium))
                            .foregroundStyle(NobiTheme.ink)
                        Text("Picks its own moods through the day")
                            .font(NobiFont.body(13))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                if robot.supportsKairoFeatures {
                    Toggle(isOn: Binding(
                        get: { robot.deviceState.inverted },
                        set: { robot.setInverted($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invert colors")
                                .font(NobiFont.body(16, .medium))
                                .foregroundStyle(NobiTheme.ink)
                            Text("Dark eyes on a bright screen")
                                .font(NobiFont.body(13))
                                .foregroundStyle(NobiTheme.ink3)
                        }
                    }
                    .toggleStyle(InkToggleStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                    Toggle(isOn: Binding(
                        get: { robot.deviceState.hold },
                        set: { robot.setHold($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep on screen")
                                .font(NobiFont.body(16, .medium))
                                .foregroundStyle(NobiTheme.ink)
                            Text("Faces and words stay until you change them")
                                .font(NobiFont.body(13))
                                .foregroundStyle(NobiTheme.ink3)
                        }
                    }
                    .toggleStyle(InkToggleStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                }
                Button { robot.syncTime() } label: {
                    InkRow(title: "Sync clock", showDivider: false) { EmptyView() } trailing: {
                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(NobiTheme.ink3)
                    }
                }
                .buttonStyle(.plain)
            }
            .disabled(!robot.isConnected)
            .opacity(robot.isConnected ? 1 : 0.5)

            if fleet.syncEnabled && !isActive {
                InkGroup {
                    Toggle(isOn: Binding(
                        get: { fleet.syncMembers.contains(robot.id) },
                        set: { _ in fleet.toggleSyncMember(robot) }
                    )) {
                        Text("Moves with the group")
                            .font(NobiFont.body(16, .medium))
                            .foregroundStyle(NobiTheme.ink)
                    }
                    .toggleStyle(InkToggleStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            InkGroup(header: "About this robot") {
                Button {
                    renameText = robot.name
                    showRename = true
                } label: {
                    InkRow(title: "Name") { EmptyView() } trailing: {
                        HStack(spacing: 8) {
                            Text(robot.name).font(NobiFont.body(15)).foregroundStyle(NobiTheme.ink3)
                            Chevron()
                        }
                    }
                }
                .buttonStyle(.plain)

                Menu {
                    Picker("Face plate", selection: Binding(get: { robot.profile.plate }, set: { fleet.setPlate(robot, $0) })) {
                        ForEach(FacePlate.allCases) { p in Text(p.displayName).tag(p) }
                    }
                } label: {
                    InkRow(title: "Face plate") { EmptyView() } trailing: {
                        HStack(spacing: 8) {
                            Text(robot.profile.plate.displayName).font(NobiFont.body(15)).foregroundStyle(NobiTheme.ink3)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NobiTheme.ink3)
                        }
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.robotDetails(robot.id)) {
                    InkRow(title: "Details", showDivider: false) { EmptyView() } trailing: { Chevron() }
                }
                .buttonStyle(.plain)
            }

            Button { confirmForget = true } label: {
                Text("Forget this robot")
                    .font(NobiFont.body(15, .medium))
                    .foregroundStyle(NobiTheme.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { brightness = Double(robot.deviceState.brightness) }
        .onChange(of: robot.deviceState.brightness) { _, b in brightness = Double(b) }
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") { fleet.rename(robot, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Forget \(robot.name)?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget", role: .destructive) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fleet.forget(robot) }
            }
        } message: {
            Text("Its name and bond will be removed from this phone. You can pair it again any time.")
        }
    }
}

// MARK: - Diagnostics

/// Firmware, signal and the message log — for the curious.
struct RobotDiagnosticsView: View {
    @EnvironmentObject var robot: NobiRobot

    var body: some View {
        NobiPage(spacing: 24, topPadding: 4) {
            InkGroup {
                VStack(spacing: 10) {
                    InkReadoutRow(label: "Model", value: robot.deviceState.name)
                    InkReadoutRow(label: "Firmware", value: robot.profile.lastFirmware ?? robot.deviceState.firmware)
                    InkReadoutRow(label: "Display", value: "128×64 OLED")
                    InkReadoutRow(label: "Showing", value: robot.deviceState.screen.capitalized)
                    InkReadoutRow(label: "Signal", value: robot.rssi.map { "\($0) dBm" } ?? "—")
                    InkReadoutRow(label: "Distance", value: ProximityZone(rawValue: robot.deviceState.proximity)?.displayName ?? "—")
                    InkReadoutRow(label: "Mood · Energy", value: "\(robot.deviceState.mood)% · \(robot.deviceState.energy)%")
                    if !robot.pingResult.isEmpty {
                        InkReadoutRow(label: "Ping", value: robot.pingResult)
                    }
                }
                .padding(16)
            }

            HStack(spacing: 10) {
                Button("Refresh") { robot.requestStatus() }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small, fullWidth: true))
                Button("Ping") { robot.sendPing() }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small, fullWidth: true))
            }
            .disabled(!robot.isConnected)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Messages")
                        .font(NobiFont.body(13, .semibold))
                        .foregroundStyle(NobiTheme.ink3)
                    Spacer()
                    Button("Clear") { robot.clearLog() }
                        .font(NobiFont.body(13, .medium))
                        .foregroundStyle(NobiTheme.ink3)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        if robot.protocolLog.isEmpty {
                            Text("Nothing yet.").foregroundStyle(Color.white.opacity(0.4))
                        } else {
                            ForEach(Array(robot.protocolLog.suffix(80).reversed().enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .foregroundStyle(line.contains("→") ? Color.white.opacity(0.85) : NobiTheme.cyan)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(height: 260)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NobiTheme.screenBlack))
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Coming soon

struct ComingSoonView: View {
    var body: some View {
        NobiPage(spacing: 22, topPadding: 4) {
            ScreenIntro(title: "More friends are ", emphasis: "on the way", tail: ".",
                        sub: "Kairo is the first. The rest of the crew is still in the lab.", size: 30)

            SoonCard(art: "Aura", name: "Aura", blurb: "A little rover with a curious, stretchy neck.")
            SoonCard(art: "CameraBot", name: "Camera Bot", blurb: "Takes tiny photos of your best days.")
            SoonCard(art: nil, name: "Top secret", blurb: "Small, four legs… that's all we can say.")
        }
        .navigationTitle("Coming soon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SoonCard: View {
    var art: String?
    var name: String
    var blurb: String

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NobiTheme.paper2)
                if let art {
                    Image("\(art)0")
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Text("?")
                        .font(NobiFont.displayItalic(44))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(NobiFont.display(22))
                        .foregroundStyle(NobiTheme.ink)
                    Spacer()
                    TagLabel(text: "Soon")
                }
                Text(blurb)
                    .font(NobiFont.body(14))
                    .foregroundStyle(NobiTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .inkCard(radius: 24, padding: 14)
    }
}
