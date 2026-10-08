import SwiftUI

/// Gentle nudges from Kairo: water, stretching, eye breaks and bedtime — with quiet hours.
struct RemindersView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var settings = KairoReminders()
    @State private var loaded = false

    private let intervals: [(value: Int, title: String)] = [
        (30, "30m"), (45, "45m"), (60, "1h"), (90, "1.5h"), (120, "2h"),
    ]

    var body: some View {
        NobiPage(spacing: 26, topPadding: 4) {
            if !robot.supportsKairoFeatures {
                FirmwareNotice()
            }

            Text("\(robot.name) taps you on the shoulder — never during focus, games or sleep.")
                .font(NobiFont.body(16))
                .foregroundStyle(NobiTheme.ink2)

            InkGroup(header: "Reminders") {
                ForEach([ReminderKind.water, .stretch, .eyes]) { kind in
                    intervalRow(kind)
                    Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                }
                bedRow
            }

            InkGroup(header: "Quiet hours", footer: "No sounds or reminders in this window. Bedtime still shows, silently.") {
                Toggle(isOn: Binding(
                    get: { settings.quietEnabled },
                    set: { settings.quietEnabled = $0; sendQuiet() }
                )) {
                    rowTitle("Quiet hours", symbol: "moon.zzz")
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if settings.quietEnabled {
                    Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                    timeRow("From", minutes: Binding(
                        get: { settings.quietStart },
                        set: { settings.quietStart = $0; sendQuiet() }
                    ))
                    Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                    timeRow("Until", minutes: Binding(
                        get: { settings.quietEnd },
                        set: { settings.quietEnd = $0; sendQuiet() }
                    ))
                }
            }

            InkGroup {
                Toggle(isOn: Binding(
                    get: { settings.sound },
                    set: { on in
                        settings.sound = on
                        fleet.perform { $0.setSound(on) }
                    }
                )) {
                    rowTitle("Sounds", symbol: "speaker.wave.2")
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .disabled(!fleet.canSend)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: settings)
        .onAppear {
            if let r = robot.reminders { settings = r; loaded = true }
            if robot.isConnected { robot.requestReminders() }
        }
        .onChange(of: robot.reminders) { _, r in
            if let r, !loaded { settings = r; loaded = true }
        }
    }

    // MARK: - Rows

    private func intervalRow(_ kind: ReminderKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { settings[kind].enabled },
                set: { on in
                    settings[kind].enabled = on
                    send(kind)
                }
            )) {
                rowTitle(kind.title, symbol: kind.symbol, subtitle: kind.subtitle)
            }
            .toggleStyle(InkToggleStyle())

            if settings[kind].enabled {
                HStack(spacing: 10) {
                    InkSegmented(
                        options: intervals,
                        selection: Binding(
                            get: { nearestInterval(settings[kind].value) },
                            set: { v in
                                settings[kind].value = v
                                send(kind)
                            }
                        )
                    )
                    Button("Try") { fleet.perform { $0.testReminder(kind) } }
                        .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bedRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { settings.bed.enabled },
                set: { on in
                    settings.bed.enabled = on
                    send(.bed)
                }
            )) {
                rowTitle(ReminderKind.bed.title, symbol: ReminderKind.bed.symbol, subtitle: ReminderKind.bed.subtitle)
            }
            .toggleStyle(InkToggleStyle())

            if settings.bed.enabled {
                HStack {
                    DatePicker(
                        "At",
                        selection: Binding(
                            get: { MinuteOfDay.date(settings.bed.value) },
                            set: { d in
                                settings.bed.value = MinuteOfDay.minutes(d)
                                send(.bed)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(NobiFont.body(15))
                    .foregroundStyle(NobiTheme.ink2)
                    Button("Try") { fleet.perform { $0.testReminder(.bed) } }
                        .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { MinuteOfDay.date(minutes.wrappedValue) },
                set: { minutes.wrappedValue = MinuteOfDay.minutes($0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .font(NobiFont.body(16, .medium))
        .foregroundStyle(NobiTheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func rowTitle(_ title: String, symbol: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            RowIcon(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NobiFont.body(16, .medium))
                    .foregroundStyle(NobiTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(NobiFont.body(13))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }
        }
    }

    // MARK: - Sending

    private func send(_ kind: ReminderKind) {
        let setting = settings[kind]
        fleet.perform { $0.setReminder(kind, setting) }
    }

    private func sendQuiet() {
        let s = settings
        fleet.perform { $0.setQuietHours(enabled: s.quietEnabled, start: s.quietStart, end: s.quietEnd) }
    }

    private func nearestInterval(_ value: Int) -> Int {
        intervals.map(\.value).min(by: { abs($0 - value) < abs($1 - value) }) ?? 60
    }
}
