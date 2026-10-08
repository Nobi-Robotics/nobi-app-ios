import SwiftUI

// MARK: - Goal ring

/// A thin progress ring with the goal's symbol inside.
struct GoalRing: View {
    var kind: GoalKind
    var fraction: Double
    var size: CGFloat = 56
    var done: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(NobiTheme.paper2, lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(done ? NobiTheme.online : NobiTheme.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: fraction)
            Image(systemName: done ? "checkmark" : kind.symbol)
                .font(.system(size: size * 0.32, weight: .medium))
                .foregroundStyle(done ? NobiTheme.online : NobiTheme.ink)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Home card

/// "Today" on Home: each goal as a little ring. Tap to open Goals.
struct TodayGoalsCard: View {
    @EnvironmentObject var robot: NobiRobot

    var body: some View {
        NavigationLink(value: Route.goals) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(NobiFont.body(16, .semibold))
                        .foregroundStyle(NobiTheme.ink)
                    Spacer()
                    if robot.goals.streak > 0 {
                        Label("\(robot.goals.streak)-day streak", systemImage: "flame")
                            .font(NobiFont.body(13, .medium))
                            .foregroundStyle(NobiTheme.ink3)
                    } else if !robot.goals.goals.isEmpty {
                        Text("\(robot.goals.doneCount) of \(robot.goals.goals.count) done")
                            .font(NobiFont.body(13, .medium))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                    Chevron()
                }

                if robot.goals.goals.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(Circle().strokeBorder(NobiTheme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        Text("Set a daily goal — Kairo will cheer you on.")
                            .font(NobiFont.body(15))
                            .foregroundStyle(NobiTheme.ink2)
                    }
                    .foregroundStyle(NobiTheme.ink)
                } else {
                    HStack(spacing: 0) {
                        ForEach(robot.goals.goals) { g in
                            VStack(spacing: 8) {
                                GoalRing(kind: g.kind, fraction: g.fraction, size: 52, done: g.isDone)
                                Text(g.label)
                                    .font(NobiFont.body(13, .medium))
                                    .foregroundStyle(NobiTheme.ink)
                                    .lineLimit(1)
                                Text("\(g.progress)/\(g.target)")
                                    .font(NobiFont.body(12))
                                    .foregroundStyle(NobiTheme.ink3)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .inkCard(radius: 22, padding: 18)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goals page

struct GoalsView: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot

    @State private var editing: GoalDraft?
    @State private var thump = 0

    var body: some View {
        NobiPage(spacing: 22, topPadding: 4) {
            if !robot.supportsKairoFeatures {
                FirmwareNotice()
            }

            VStack(alignment: .leading, spacing: 6) {
                if robot.goals.goals.isEmpty {
                    Text("Pick up to three things for today. \(robot.name) shows your progress, nudges you gently and celebrates when you're done.")
                        .font(NobiFont.body(16))
                        .foregroundStyle(NobiTheme.ink2)
                } else {
                    Text(robot.goals.allDone ? "Everything done. Nice." : "\(robot.goals.doneCount) of \(robot.goals.goals.count) done")
                        .font(NobiFont.display(26))
                        .foregroundStyle(NobiTheme.ink)
                    if robot.goals.streak > 0 {
                        Label("\(robot.goals.streak)-day streak", systemImage: "flame")
                            .font(NobiFont.body(14, .medium))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                }
            }

            ForEach(robot.goals.goals) { goal in
                GoalCard(goal: goal, onEdit: { editing = GoalDraft(goal: goal) }) { delta in
                    thump += 1
                    let slot = goal.slot
                    fleet.perform { $0.addGoalProgress(slot: slot, delta: delta) }
                }
            }

            if let slot = robot.goals.firstEmptySlot {
                Button {
                    editing = GoalDraft(slot: slot)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Circle().strokeBorder(NobiTheme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        Text("Add a goal")
                            .font(NobiFont.body(16, .medium))
                        Spacer()
                    }
                    .foregroundStyle(NobiTheme.ink)
                    .inkCard(radius: 22, padding: 16, dashed: true)
                }
                .buttonStyle(.plain)
                .disabled(!fleet.canSend)
            }

            if !robot.goals.goals.isEmpty {
                Button {
                    fleet.perform { $0.showGoalsOnRobot() }
                } label: {
                    Text("Show on \(robot.name)")
                }
                .buttonStyle(InkButtonStyle(kind: .secondary, fullWidth: true))
                .disabled(!fleet.canSend)
            }

            Text("Goals reset at midnight. Finish them all to keep your streak going.")
                .font(NobiFont.body(13))
                .foregroundStyle(NobiTheme.ink3)
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.increase, trigger: thump)
        .sheet(item: $editing) { draft in
            GoalEditor(draft: draft)
                .environmentObject(fleet)
                .environmentObject(robot)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear { if robot.isConnected { robot.requestGoals() } }
    }
}

private struct GoalCard: View {
    var goal: KairoGoal
    var onEdit: () -> Void
    var onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onEdit) {
                HStack(spacing: 16) {
                    GoalRing(kind: goal.kind, fraction: goal.fraction, size: 58, done: goal.isDone)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.label)
                            .font(NobiFont.body(17, .semibold))
                            .foregroundStyle(NobiTheme.ink)
                        Text("\(goal.progress) of \(goal.target) \(goal.kind.unit)")
                            .font(NobiFont.body(14))
                            .foregroundStyle(NobiTheme.ink3)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button { onStep(-1) } label: { Image(systemName: "minus") }
                    .buttonStyle(InkIconButtonStyle(size: 36))
                    .disabled(goal.progress == 0)
                    .accessibilityLabel("Remove one")
                Button { onStep(1) } label: { Image(systemName: "plus") }
                    .buttonStyle(InkIconButtonStyle(size: 36, fill: NobiTheme.highlight))
                    .accessibilityLabel("Add one")
            }
        }
        .inkCard(radius: 22, padding: 16)
    }
}

// MARK: - Editor

struct GoalDraft: Identifiable {
    var slot: Int
    var kind: GoalKind = .water
    var label: String = GoalKind.water.shortLabel
    var target: Int = GoalKind.water.defaultTarget
    var isNew: Bool = true

    var id: Int { slot }

    init(slot: Int) {
        self.slot = slot
    }

    init(goal: KairoGoal) {
        slot = goal.slot
        kind = goal.kind
        label = goal.label
        target = goal.target
        isNew = false
    }
}

private struct GoalEditor: View {
    @EnvironmentObject var fleet: NobiFleet
    @EnvironmentObject var robot: NobiRobot
    @Environment(\.dismiss) private var dismiss

    @State var draft: GoalDraft
    @FocusState private var labelFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NobiPage(spacing: 26, topPadding: 30) {
            Text(draft.isNew ? "New goal" : "Edit goal")
                .font(NobiFont.display(28))
                .foregroundStyle(NobiTheme.ink)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GoalKind.allCases) { kind in
                    let selected = draft.kind == kind
                    Button {
                        let oldDefault = draft.kind.shortLabel
                        draft.kind = kind
                        if draft.label.isEmpty || draft.label == oldDefault { draft.label = kind.shortLabel }
                        if draft.isNew { draft.target = kind.defaultTarget }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 20, weight: .regular))
                            Text(kind.shortLabel)
                                .font(NobiFont.body(12, .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(NobiTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 72)
                    }
                    .buttonStyle(InkTileStyle(selected: selected, radius: 16))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(NobiFont.body(13, .semibold))
                    .foregroundStyle(NobiTheme.ink3)
                TextField(draft.kind.shortLabel, text: $draft.label)
                    .font(NobiFont.body(18))
                    .foregroundStyle(NobiTheme.ink)
                    .focused($labelFocused)
                    .onChange(of: draft.label) { _, v in
                        if v.count > 13 { draft.label = String(v.prefix(13)) }
                    }
                    .inkWell(radius: 16, padding: 14)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Every day")
                    .font(NobiFont.body(13, .semibold))
                    .foregroundStyle(NobiTheme.ink3)
                HStack {
                    Button { draft.target = max(1, draft.target - 1) } label: { Image(systemName: "minus") }
                        .buttonStyle(InkIconButtonStyle(size: 44))
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(draft.target)")
                            .font(NobiFont.display(40))
                            .foregroundStyle(NobiTheme.ink)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        Text(draft.kind.unit)
                            .font(NobiFont.body(14))
                            .foregroundStyle(NobiTheme.ink3)
                    }
                    Spacer()
                    Button { draft.target = min(50, draft.target + 1) } label: { Image(systemName: "plus") }
                        .buttonStyle(InkIconButtonStyle(size: 44))
                }
                .animation(.snappy, value: draft.target)
                if let note = draft.kind.autoNote {
                    Text(note)
                        .font(NobiFont.body(13))
                        .foregroundStyle(NobiTheme.ink3)
                }
            }

            VStack(spacing: 8) {
                Button {
                    let d = draft
                    fleet.perform { $0.setGoal(slot: d.slot, kind: d.kind, target: d.target, label: d.label) }
                    dismiss()
                } label: {
                    Text(draft.isNew ? "Add goal" : "Save")
                }
                .buttonStyle(InkButtonStyle(kind: .primary, size: .large, fullWidth: true))
                .disabled(!fleet.canSend)

                if !draft.isNew {
                    Button {
                        let slot = draft.slot
                        fleet.perform { $0.clearGoal(slot: slot) }
                        dismiss()
                    } label: {
                        Text("Remove goal")
                            .font(NobiFont.body(15, .medium))
                            .foregroundStyle(NobiTheme.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background { PaperBackground() }
        .dismissKeyboardToolbar { labelFocused = false }
    }
}

// MARK: - Firmware notice

/// Shown when the robot runs firmware older than 0.7.
struct FirmwareNotice: View {
    @EnvironmentObject var robot: NobiRobot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(NobiTheme.ink2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update \(robot.name)")
                    .font(NobiFont.body(15, .semibold))
                    .foregroundStyle(NobiTheme.ink)
                Text("Goals, reminders and work/break timers need Kairo firmware 0.7. This robot has \(robot.profile.lastFirmware ?? robot.deviceState.firmware).")
                    .font(NobiFont.body(14))
                    .foregroundStyle(NobiTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .inkCard(radius: 18, padding: 14)
    }
}
