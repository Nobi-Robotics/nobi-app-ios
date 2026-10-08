import PhotosUI
import SwiftUI

/// A photo, redrawn in light for the robot's screen (Spec §15–§21).
struct NobiImageView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var bitmap: Data?
    @State private var preview: UIImage?
    @State private var mode: NobiImageConverter.FitMode = .fit
    @State private var dither = true
    @State private var invert = false
    @State private var threshold = 128.0
    @State private var scalePercent: Double = 100
    @State private var showAdjust = false
    @State private var beamedTo: [NobiRobot] = []
    @State private var thump = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let preview {
                OLEDPreviewView(content: .image(uiImage: preview, scale: Int(scalePercent)), plate: robot.profile.plate, inverted: robot.deviceState.inverted)
            } else {
                OLEDPreviewView(content: .face(.curious), plate: robot.profile.plate, inverted: robot.deviceState.inverted)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(sourceImage == nil ? "Choose a photo" : "Choose another", systemImage: "photo")
            }
            .buttonStyle(InkButtonStyle(kind: sourceImage == nil ? .primary : .secondary, size: .large, fullWidth: true))
            .onChange(of: pickerItem) { _, item in
                Task { await loadPicked(item) }
            }

            if sourceImage != nil {
                adjustments

                if !beamedTo.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(beamedTo) { r in TransferRow(robot: r) }
                    }
                }

                VStack(spacing: 6) {
                    Button {
                        thump += 1
                        guard let bitmap else { return }
                        beamedTo = fleet.targets
                        fleet.perform { $0.beginImageTransfer(bitmap: bitmap) }
                    } label: {
                        Text("Send photo")
                    }
                    .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                    .disabled(bitmap == nil || !fleet.canSend || fleet.targets.contains { $0.imageTransferState.isActive })

                    HStack(spacing: 18) {
                        Button("Show") { fleet.perform { $0.showImage() } }
                        Button("Clear") { fleet.perform { $0.clearImage() } }
                        Button("Back to face") { fleet.perform { $0.sendFace() } }
                    }
                    .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                    .frame(maxWidth: .infinity)
                    .disabled(!fleet.canSend)
                }
            }
        }
        .sensoryFeedback(.success, trigger: thump)
        .onAppear { scalePercent = Double(robot.deviceState.imageScale) }
    }

    // MARK: - Adjustments (tucked away)

    private var adjustments: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showAdjust.toggle() }
            } label: {
                HStack {
                    Text("Adjust")
                        .font(NobiFont.body(16, .medium))
                        .foregroundStyle(NobiTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NobiTheme.ink3)
                        .rotationEffect(.degrees(showAdjust ? 180 : 0))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdjust {
                VStack(alignment: .leading, spacing: 18) {
                    InkSegmented(options: NobiImageConverter.FitMode.allCases.map { (value: $0, title: $0.rawValue) }, selection: $mode)
                        .onChange(of: mode) { _, _ in reconvert() }

                    Toggle(isOn: $dither) { rowLabel("Soft shading") }
                        .toggleStyle(InkToggleStyle())
                        .onChange(of: dither) { _, _ in reconvert() }

                    Toggle(isOn: $invert) { rowLabel("Negative") }
                        .toggleStyle(InkToggleStyle())
                        .onChange(of: invert) { _, _ in reconvert() }

                    if !dither {
                        VStack(alignment: .leading, spacing: 6) {
                            rowLabel("Contrast")
                            Slider(value: $threshold, in: 1...254, step: 1)
                                .onChange(of: threshold) { _, _ in reconvert() }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            rowLabel("Size")
                            Spacer()
                            Text("\(Int(scalePercent))%")
                                .font(NobiFont.body(14, .medium))
                                .foregroundStyle(NobiTheme.ink3)
                                .monospacedDigit()
                        }
                        Slider(value: $scalePercent, in: 25...200, step: 5) { editing in
                            if !editing {
                                let v = Int(scalePercent)
                                fleet.perform { $0.sendImageScale(v) }
                            }
                        }
                    }
                }
                .padding(.top, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .inkCard(radius: 22, padding: 18)
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(NobiFont.body(15))
            .foregroundStyle(NobiTheme.ink)
    }

    // MARK: - Conversion

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
            await MainActor.run {
                sourceImage = ui
                reconvert()
            }
        }
    }

    private func reconvert() {
        guard let sourceImage else { return }
        let opts = NobiImageConverter.Options(mode: mode, dither: dither, invert: invert, threshold: threshold)
        DispatchQueue.global(qos: .userInitiated).async {
            let data = NobiImageConverter.convert(sourceImage, options: opts)
            let prev = data.flatMap { NobiImageConverter.previewImage(from: $0) }
            DispatchQueue.main.async {
                bitmap = data
                preview = prev
            }
        }
    }
}

/// Per-robot send progress.
private struct TransferRow: View {
    @ObservedObject var robot: NobiRobot

    var body: some View {
        let state = robot.imageTransferState
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RobotAvatar(plate: robot.profile.plate, emotion: robot.currentEmotion, size: 24)
                Text(robot.name)
                    .font(NobiFont.body(14, .medium))
                    .foregroundStyle(NobiTheme.ink)
                Spacer()
                Text(state.displayName)
                    .font(NobiFont.body(13))
                    .foregroundStyle(NobiTheme.ink3)
                    .lineLimit(1)
                if state.isActive {
                    Button { robot.cancelImageTransfer() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }
            }
            InkProgressBar(value: state.progress, tint: tint(state), height: 4)
        }
    }

    private func tint(_ s: ImageTransferState) -> Color {
        switch s {
        case .succeeded: return NobiTheme.online
        case .failed: return NobiTheme.red
        default: return NobiTheme.ink
        }
    }
}
