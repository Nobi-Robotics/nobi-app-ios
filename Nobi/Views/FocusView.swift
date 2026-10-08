import SwiftUI

/// Work / break timer. Counts down on Kairo's screen too, and Kairo celebrates
/// with its buzzer when each work session ends (Spec §30–§31, firmware 0.7 cycles).
struct FocusView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @AppStorage("nobi.focus.work") private var workMinutes: Int = 25
    @AppStorage("nobi.focus.break") private var breakMinutes: Int = 5
    @AppStorage("nobi.focus.rounds") private var rounds: Int = 1

    @State private var localRemainingSeconds: Int = 25 * 60
    @State private var sessionTotalSeconds: Int = 25 * 60
    @State private var timer: Timer?
    @State private var thump = 0

    private let workPresets = [15, 25, 45, 60]
    private let breakPresets = [0, 5, 10, 15]

    private var active: Bool { robot.deviceState.focusActive }
    private var cycle: FocusCycleState { robot.focusCycle }
    private var canCycle: Bool { robot.supportsKairoFeatures }

    var body: some View {
        NobiPage(spacing: 30, topPadding: 4) {
            SendTargetLine()

            ZStack {
                Circle()
                    .stroke(NobiTheme.line, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(active && cycle.isBreak ? NobiTheme.online : NobiTheme.ink,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: ringProgress)
                VStack(spacing: 6) {
                    Text(formattedTime(displaySeconds))
                        .font(NobiFont.display(60))
                        .monospacedDigit()
                        .foregroundStyle(NobiTheme.ink)
                        .contentTransition(.numericText(countsDown: true))
                    Text(statusLine)
                        .font(NobiFont.body(15))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }
            .frame(width: 250, height: 250)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            if active {
                VStack(spacing: 6) {
                    Button {
                        thump += 1
                        fleet.perform { $0.stopFocus() }
                    } label: {
                        Text("Stop")
                    }
                    .buttonStyle(InkButtonStyle(kind: .secondary, size: .large, fullWidth: true))

                    if canCycle && cycle.rounds > 1 {
                        Button(cycle.isBreak ? "Skip break" : "Finish this round") {
                            fleet.perform { $0.skipFocusPhase() }
                        }
                        .buttonStyle(InkButtonStyle(kind: .plain, size: .small))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        label("Work")
                        InkSegmented(options: workPresets.map { (value: $0, title: "\($0) min") }, selection: $workMinutes)
                    }

                    if canCycle {
                        VStack(alignment: .leading, spacing: 10) {
                            label("Break")
                            InkSegmented(options: breakPresets.map { (value: $0, title: $0 == 0 ? "None" : "\($0) min") },
                                         selection: $breakMinutes)
                        }

                        HStack {
                            label("Rounds")
                            Spacer()
                            Button { rounds = max(1, rounds - 1) } label: { Image(systemName: "minus") }
                                .buttonStyle(InkIconButtonStyle(size: 36))
                                .disabled(rounds <= 1)
                            Text("\(rounds)")
                                .font(NobiFont.body(18, .semibold))
                                .foregroundStyle(NobiTheme.ink)
                                .frame(minWidth: 34)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Button { rounds = min(8, rounds + 1) } label: { Image(systemName: "plus") }
                                .buttonStyle(InkIconButtonStyle(size: 36))
                                .disabled(rounds >= 8)
                        }
                        .animation(.snappy, value: rounds)
                    }

                    Button {
                        start()
                    } label: {
                        Text("Start")
                    }
                    .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                    .disabled(!fleet.canSend)

                    if canCycle {
                        Text(planSummary)
                            .font(NobiFont.body(13))
                            .foregroundStyle(NobiTheme.ink3)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: thump)
        .onAppear {
            if !workPresets.contains(workMinutes) { workMinutes = 25 }
            if !breakPresets.contains(breakMinutes) { breakMinutes = 5 }
            if robot.isConnected { robot.requestPomodoroStatus() }
            syncFromRobot()
            startLocalTimer()
        }
        .onDisappear { stopLocalTimer() }
        .onChange(of: robot.deviceState.focusActive) { _, isActive in
            if !isActive { localRemainingSeconds = workMinutes * 60 }
        }
        .onChange(of: robot.deviceState.focusRemainingSeconds) { _, _ in syncFromRobot() }
        .onChange(of: robot.focusCycle) { _, _ in syncFromRobot() }
    }

    // MARK: - Text

    private var statusLine: String {
        if active {
            if cycle.isBreak { return "Break · round \(cycle.round) of \(cycle.rounds)" }
            if cycle.rounds > 1 { return "Round \(cycle.round) of \(cycle.rounds)" }
            return "Focusing"
        }
        return "\(workMinutes) minutes"
    }

    private var planSummary: String {
        if rounds <= 1 { return "One session — \(robot.name) cheers when it ends." }
        let brk = breakMinutes == 0 ? "no breaks" : "\(breakMinutes) min breaks"
        let total = workMinutes * rounds + breakMinutes * (rounds - 1)
        return "\(rounds) rounds, \(brk) · about \(total) min"
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(NobiFont.body(14, .medium))
            .foregroundStyle(NobiTheme.ink3)
    }

    // MARK: - Timer

    private var displaySeconds: Int {
        active ? max(0, localRemainingSeconds) : workMinutes * 60
    }

    private var ringProgress: Double {
        guard active, sessionTotalSeconds > 0 else { return 1 }
        return Double(max(0, localRemainingSeconds)) / Double(sessionTotalSeconds)
    }

    private func start() {
        thump += 1
        let w = workMinutes, b = breakMinutes, r = rounds
        if canCycle {
            fleet.perform { $0.startFocusCycle(work: w, breakMinutes: b, rounds: r) }
        } else {
            fleet.perform { $0.startFocus(minutes: w) }
        }
        sessionTotalSeconds = w * 60
        localRemainingSeconds = w * 60
    }

    private func syncFromRobot() {
        guard active else { return }
        let phaseMinutes = cycle.isBreak ? cycle.breakMinutes : cycle.workMinutes
        if phaseMinutes > 0 { sessionTotalSeconds = phaseMinutes * 60 }
        let remaining = robot.deviceState.focusRemainingSeconds
        if remaining > 0 {
            localRemainingSeconds = remaining
            sessionTotalSeconds = max(sessionTotalSeconds, remaining)
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func startLocalTimer() {
        timer?.invalidate()
        let robot = robot
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard robot.deviceState.focusActive else { return }
            if localRemainingSeconds > 0 {
                localRemainingSeconds -= 1
            } else {
                robot.requestPomodoroStatus()
            }
        }
    }

    private func stopLocalTimer() {
        timer?.invalidate()
        timer = nil
    }
}
