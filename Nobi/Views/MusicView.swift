import SwiftUI

/// Kairo's little jukebox, plus a tiny keyboard to compose "My song".
struct MusicView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @AppStorage("nobi.music.composition") private var compositionText = ""
    @AppStorage("nobi.music.bpm") private var bpm = 120
    @State private var notes: [ComposedNote] = []
    @State private var noteLength = 4
    @State private var thump = 0

    private let maxNotes = 48

    var body: some View {
        NobiPage(spacing: 26, topPadding: 4) {
            if !robot.supportsKairoFeatures {
                FirmwareNotice()
            }

            SendTargetLine()

            if robot.music.playing {
                nowPlaying
            }

            InkGroup(header: "Songs") {
                ForEach(Array(robot.music.titles.enumerated()), id: \.offset) { i, title in
                    Button {
                        thump += 1
                        if robot.music.playing && robot.music.song == i {
                            fleet.perform { $0.stopMusic() }
                        } else {
                            fleet.perform { $0.playSong(i) }
                        }
                    } label: {
                        InkRow(title: title, subtitle: KairoMusicState.subtitle(for: i),
                               showDivider: i < robot.music.titles.count - 1) {
                            RowIcon(systemName: i >= KairoMusicState.builtInTitles.count ? "music.quarternote.3" : "music.note")
                        } trailing: {
                            Image(systemName: robot.music.playing && robot.music.song == i ? "stop.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NobiTheme.ink)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(NobiTheme.paper2))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!fleet.canSend)

            composer
        }
        .navigationTitle("Music")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: thump)
        .onAppear {
            notes = ComposedNote.decode(compositionText)
            if robot.isConnected { robot.requestMusic() }
        }
        .onChange(of: notes) { _, n in compositionText = ComposedNote.encode(n) }
    }

    // MARK: - Now playing

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(NobiTheme.ink)
                .symbolEffect(.variableColor.iterative, isActive: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Playing on \(robot.name)")
                    .font(NobiFont.body(13))
                    .foregroundStyle(NobiTheme.ink3)
                Text(robot.music.titles.indices.contains(robot.music.song) ? robot.music.titles[robot.music.song] : "My song")
                    .font(NobiFont.body(17, .semibold))
                    .foregroundStyle(NobiTheme.ink)
            }
            Spacer()
            Button("Stop") { fleet.perform { $0.stopMusic() } }
                .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
        }
        .inkCard(radius: 22, padding: 16)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Compose")
                    .font(NobiFont.body(17, .semibold))
                    .foregroundStyle(NobiTheme.ink)
                Spacer()
                Text("\(notes.count)/\(maxNotes)")
                    .font(NobiFont.body(13))
                    .foregroundStyle(NobiTheme.ink3)
                    .monospacedDigit()
            }

            // What you've written so far
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if notes.isEmpty {
                            Text("Tap the keys to write a tune")
                                .font(NobiFont.body(14))
                                .foregroundStyle(NobiTheme.ink3)
                                .padding(.vertical, 8)
                        }
                        ForEach(notes) { n in
                            Text(n.name)
                                .font(NobiFont.mono(12, .medium))
                                .foregroundStyle(n.midi == 0 ? NobiTheme.ink3 : NobiTheme.ink)
                                .padding(.horizontal, 8)
                                .frame(minWidth: CGFloat(18 + n.length * 4), minHeight: 30)
                                .background(Capsule().fill(NobiTheme.paper2))
                                .id(n.id)
                        }
                    }
                }
                .onChange(of: notes.count) { _, _ in
                    if let last = notes.last { withAnimation { proxy.scrollTo(last.id, anchor: .trailing) } }
                }
            }

            InkSegmented(options: [(value: 2, title: "Short"), (value: 4, title: "Beat"), (value: 8, title: "Long")],
                         selection: $noteLength)

            PianoKeys { midi in
                add(midi)
            }
            .frame(height: 132)

            HStack(spacing: 10) {
                Button { add(0) } label: { Label("Rest", systemImage: "pause") }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
                Button { _ = notes.popLast() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .small))
                    .disabled(notes.isEmpty)
                Spacer()
                Button("Clear") { notes.removeAll() }
                    .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                    .disabled(notes.isEmpty)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Speed")
                    .font(NobiFont.body(14, .medium))
                    .foregroundStyle(NobiTheme.ink3)
                InkSegmented(options: [(value: 90, title: "Slow"), (value: 120, title: "Normal"), (value: 150, title: "Fast")],
                             selection: $bpm)
            }

            Button {
                thump += 1
                let n = notes, b = bpm
                fleet.perform { $0.playComposition(bpm: b, notes: n) }
            } label: {
                Label("Play on \(fleet.isBroadcasting ? "all \(fleet.targets.count)" : robot.name)", systemImage: "play.fill")
            }
            .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
            .disabled(notes.isEmpty || !fleet.canSend)

            Text("Kairo keeps it as \u{201C}My song\u{201D} — you can play it from the robot's Music menu too.")
                .font(NobiFont.body(13))
                .foregroundStyle(NobiTheme.ink3)
        }
        .inkCard(radius: 24, padding: 18)
    }

    private func add(_ midi: Int) {
        guard notes.count < maxNotes else { return }
        thump += 1
        notes.append(ComposedNote(midi: midi, length: noteLength))
    }
}

// MARK: - Piano

/// One octave and a bit (C5–E6): white keys with black keys on top.
private struct PianoKeys: View {
    var onKey: (Int) -> Void

    private let whites: [Int] = [72, 74, 76, 77, 79, 81, 83, 84, 86, 88]
    /// Black key MIDI and the index of the white key it sits after.
    private let blacks: [(midi: Int, after: Int)] = [(73, 0), (75, 1), (78, 3), (80, 4), (82, 5), (85, 7), (87, 8)]

    @State private var pressed: Int?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(whites.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { m in
                        key(m, isBlack: false)
                            .frame(width: w, height: geo.size.height)
                    }
                }
                ForEach(blacks, id: \.midi) { b in
                    key(b.midi, isBlack: true)
                        .frame(width: w * 0.62, height: geo.size.height * 0.6)
                        .offset(x: w * CGFloat(b.after + 1) - w * 0.31)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(NobiTheme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func key(_ midi: Int, isBlack: Bool) -> some View {
        let down = pressed == midi
        return Rectangle()
            .fill(isBlack ? (down ? Color(UIColor(hex: 0x4A4540)) : Color(UIColor(hex: 0x1F1D1B)))
                          : (down ? NobiTheme.highlight : Color(UIColor(hex: 0xFCFAF5))))
            .overlay(alignment: .trailing) {
                if !isBlack { Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1) }
            }
            .overlay(alignment: .bottom) {
                if !isBlack && midi % 12 == 0 {
                    Text("C\(midi / 12 - 1)")
                        .font(NobiFont.mono(9, .medium))
                        .foregroundStyle(Color.black.opacity(0.4))
                        .padding(.bottom, 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                pressed = midi
                onKey(midi)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if pressed == midi { pressed = nil }
                }
            }
            .accessibilityLabel(ComposedNote(midi: midi, length: 4).name)
            .accessibilityAddTraits(.isButton)
    }
}
