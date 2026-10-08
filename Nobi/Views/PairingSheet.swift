import SwiftUI

/// Find a robot nearby, name it, done.
struct PairingSheet: View {
    @EnvironmentObject var fleet: NobiFleet
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: DiscoveredDevice?
    @State private var name = ""
    @State private var nameEdited = false
    @State private var plate: FacePlate = .yellow
    @State private var pulse = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if chosen != nil {
                    Button { withAnimation { chosen = nil } } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(InkIconButtonStyle(size: 36))
                        .accessibilityLabel("Back")
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(InkIconButtonStyle(size: 36))
                    .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            if let device = chosen {
                setup(for: device)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                scanning
                    .transition(.opacity)
            }
        }
        .background { PaperBackground() }
        .onAppear { fleet.startScan() }
        .onDisappear { fleet.stopScan() }
    }

    // MARK: - Step 1: looking

    private var scanning: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(NobiTheme.line, lineWidth: 1)
                    .frame(width: 210, height: 210)
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .opacity(pulse ? 0 : 1)
                    .animation(fleet.isScanning ? .easeOut(duration: 1.8).repeatForever(autoreverses: false) : .default, value: pulse)
                Circle()
                    .fill(NobiTheme.card)
                    .frame(width: 150, height: 150)
                    .overlay(Circle().strokeBorder(NobiTheme.line, lineWidth: 1))
                RobotAvatar(plate: .yellow, emotion: fleet.nearby.isEmpty ? .curious : .happy, size: 84, live: true)
            }
            .frame(height: 230)
            .padding(.top, 20)
            .onAppear { pulse = true }

            Text(fleet.nearby.isEmpty ? (fleet.isScanning ? "Looking for robots…" : "No robots found") : "Say hi")
                .font(NobiFont.display(28))
                .foregroundStyle(NobiTheme.ink)
                .padding(.top, 18)
            Text(fleet.nearby.isEmpty ? "Switch your robot on and hold it close." : "Tap your robot to pair it.")
                .font(NobiFont.body(16))
                .foregroundStyle(NobiTheme.ink2)
                .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    BluetoothNotice()
                    if !fleet.nearby.isEmpty {
                        InkGroup {
                            ForEach(Array(fleet.nearby.enumerated()), id: \.element.id) { i, device in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                        chosen = device
                                        if !nameEdited { name = fleet.suggestedName(for: plate) }
                                    }
                                } label: {
                                    InkRow(title: device.name, subtitle: device.bars >= 2 ? "Close by" : "A little far",
                                           showDivider: i < fleet.nearby.count - 1) {
                                        RobotAvatar(plate: .yellow, emotion: .happy, size: 40)
                                    } trailing: {
                                        HStack(spacing: 10) {
                                            SignalBars(bars: device.bars)
                                            Chevron()
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if !fleet.isScanning {
                        Button("Look again") { fleet.startScan() }
                            .buttonStyle(InkButtonStyle(kind: .primary, fullWidth: true))
                            .disabled(!fleet.bluetooth.isReady)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Step 2: name

    private func setup(for device: DiscoveredDevice) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                KairoView(plate: plate, emotion: .excited, live: true)
                    .frame(height: 220)
                    .animation(.easeInOut(duration: 0.25), value: plate)
                    .padding(.top, 8)

                TextField("Name", text: $name)
                    .font(NobiFont.display(30))
                    .foregroundStyle(NobiTheme.ink)
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onChange(of: name) { _, _ in if nameFocused { nameEdited = true } }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(NobiTheme.line).frame(height: 1)
                    }
                    .padding(.horizontal, 40)

                VStack(spacing: 10) {
                    Text("Face plate")
                        .font(NobiFont.body(13, .semibold))
                        .foregroundStyle(NobiTheme.ink3)
                    InkSegmented(options: [(value: FacePlate.yellow, title: "Yellow"), (value: FacePlate.white, title: "White")],
                                 selection: $plate)
                        .frame(maxWidth: 260)
                        .onChange(of: plate) { _, p in
                            if !nameEdited { name = fleet.suggestedName(for: p) }
                        }
                }

                Button {
                    fleet.pair(device, name: name, plate: plate)
                    dismiss()
                } label: {
                    Text("Pair \(name.isEmpty ? "robot" : name)")
                }
                .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }
}
