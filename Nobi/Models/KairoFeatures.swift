import Foundation

// MARK: - Daily goals

/// What a daily goal is about. Matches the firmware's goal kinds (v0.7+).
enum GoalKind: String, CaseIterable, Identifiable, Codable {
    case water, focus, stretch, read, walk, sleep, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Drink water"
        case .focus: return "Focus sessions"
        case .stretch: return "Stretch"
        case .read: return "Read"
        case .walk: return "Go for a walk"
        case .sleep: return "Sleep on time"
        case .custom: return "Something else"
        }
    }

    var shortLabel: String {
        switch self {
        case .water: return "Water"
        case .focus: return "Focus"
        case .stretch: return "Stretch"
        case .read: return "Read"
        case .walk: return "Walk"
        case .sleep: return "Sleep"
        case .custom: return "My goal"
        }
    }

    /// Plural unit shown next to the count.
    var unit: String {
        switch self {
        case .water: return "glasses"
        case .focus: return "sessions"
        case .stretch: return "stretches"
        case .read: return "pages"
        case .walk: return "walks"
        case .sleep: return "nights"
        case .custom: return "times"
        }
    }

    var symbol: String {
        switch self {
        case .water: return "drop"
        case .focus: return "leaf"
        case .stretch: return "figure.arms.open"
        case .read: return "book"
        case .walk: return "shoeprints.fill"
        case .sleep: return "moon"
        case .custom: return "star"
        }
    }

    var defaultTarget: Int {
        switch self {
        case .water: return 8
        case .focus: return 4
        case .stretch: return 3
        case .read: return 10
        case .walk: return 1
        case .sleep: return 1
        case .custom: return 3
        }
    }

    /// How progress gets counted besides tapping +1.
    var autoNote: String? {
        switch self {
        case .water: return "Counts when you tap Done on a water reminder."
        case .focus: return "Counts every finished focus session."
        case .stretch: return "Counts when you tap Done on a stretch reminder."
        case .sleep: return "Counts when you tap Done on the bedtime reminder."
        default: return nil
        }
    }
}

struct KairoGoal: Identifiable, Equatable {
    var slot: Int
    var kind: GoalKind
    var label: String
    var progress: Int
    var target: Int

    var id: Int { slot }
    var isDone: Bool { progress >= target }
    var fraction: Double { target > 0 ? min(1, Double(progress) / Double(target)) : 0 }
}

struct KairoGoalsState: Equatable {
    /// Three slots; nil = empty.
    var slots: [KairoGoal?] = [nil, nil, nil]
    var streak: Int = 0

    var goals: [KairoGoal] { slots.compactMap { $0 } }
    var doneCount: Int { goals.filter(\.isDone).count }
    var allDone: Bool { !goals.isEmpty && doneCount == goals.count }
    var firstEmptySlot: Int? { slots.firstIndex { $0 == nil } }
}

// MARK: - Reminders

enum ReminderKind: String, CaseIterable, Identifiable {
    case water, stretch, eyes, bed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Drink water"
        case .stretch: return "Stretch"
        case .eyes: return "Rest your eyes"
        case .bed: return "Bedtime"
        }
    }

    var subtitle: String {
        switch self {
        case .water: return "A gentle nudge to sip"
        case .stretch: return "Stand up and reach high"
        case .eyes: return "Look far away for 20 seconds"
        case .bed: return "Time to wind down"
        }
    }

    var symbol: String {
        switch self {
        case .water: return "drop"
        case .stretch: return "figure.arms.open"
        case .eyes: return "eye"
        case .bed: return "moon"
        }
    }
}

struct ReminderSetting: Equatable {
    var enabled: Bool
    /// Minutes between reminders (water/stretch/eyes) or minute-of-day (bed).
    var value: Int
}

struct KairoReminders: Equatable {
    var water = ReminderSetting(enabled: true, value: 60)
    var stretch = ReminderSetting(enabled: true, value: 90)
    var eyes = ReminderSetting(enabled: false, value: 45)
    var bed = ReminderSetting(enabled: false, value: 22 * 60 + 30)
    var quietEnabled = true
    var quietStart = 22 * 60
    var quietEnd = 8 * 60
    var sound = true
    var breakMinutes = 5
    var rounds = 1

    subscript(kind: ReminderKind) -> ReminderSetting {
        get {
            switch kind {
            case .water: return water
            case .stretch: return stretch
            case .eyes: return eyes
            case .bed: return bed
            }
        }
        set {
            switch kind {
            case .water: water = newValue
            case .stretch: stretch = newValue
            case .eyes: eyes = newValue
            case .bed: bed = newValue
            }
        }
    }
}

// MARK: - Focus cycle

struct FocusCycleState: Equatable {
    var isBreak = false
    var round = 1
    var rounds = 1
    var workMinutes = 25
    var breakMinutes = 5
    var sessionsToday = 0
}

// MARK: - Minutes <-> Date helpers

enum MinuteOfDay {
    static func date(_ minutes: Int) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func label(_ minutes: Int) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date(minutes))
    }
}

// MARK: - Protocol (firmware v0.7+)

extension NobiProtocol {
    static let goals = "goals"
    static let goalsShow = "goals:show"
    static let goalReset = "goal:reset"
    static let reminders = "reminders"
    static let findStart = "find:start"
    static let findStop = "find:stop"
    static let pomodoroSkip = "pomodoro:skip"

    static func goalSet(slot: Int, kind: GoalKind, target: Int, label: String) -> String {
        let clean = sanitizePipeField(label)
            .replacingOccurrences(of: ",", with: " ")
        let short = String(sanitizeText(clean).prefix(13))
        return "goal:set:\(slot)|\(kind.rawValue)|\(min(50, max(1, target)))|\(short)"
    }

    static func goalClear(slot: Int) -> String { "goal:clear:\(slot)" }
    static func goalAdd(slot: Int, delta: Int) -> String { "goal:add:\(slot)|\(delta)" }

    static func remindSet(_ kind: ReminderKind, _ setting: ReminderSetting) -> String {
        "remind:set:\(kind.rawValue)|\(setting.enabled ? 1 : 0)|\(setting.value)"
    }

    static func remindTest(_ kind: ReminderKind) -> String { "remind:test:\(kind.rawValue)" }

    static func quietSet(enabled: Bool, start: Int, end: Int) -> String {
        "quiet:set:\(enabled ? 1 : 0)|\(start)|\(end)"
    }

    static func sound(_ on: Bool) -> String { on ? "sound:on" : "sound:off" }

    static func invert(_ on: Bool) -> String { on ? "invert:on" : "invert:off" }

    static func pomodoroCycle(work: Int, breakMinutes: Int, rounds: Int) -> String {
        "pomodoro:cycle:\(min(180, max(1, work)))|\(min(60, max(0, breakMinutes)))|\(min(8, max(1, rounds)))"
    }

    /// `goals|day=..|streak=2|done=1|g0=water,5,8,Water|g1=none|g2=...`
    static func parseGoals(_ message: String) -> KairoGoalsState? {
        guard message.hasPrefix("goals|") else { return nil }
        var state = KairoGoalsState()
        for part in message.split(separator: "|").dropFirst() {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = String(kv[0]), value = String(kv[1])
            if key == "streak" {
                state.streak = Int(value) ?? 0
            } else if key.hasPrefix("g"), let slot = Int(key.dropFirst()), (0..<3).contains(slot) {
                if value == "none" { continue }
                let f = value.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
                guard f.count >= 3 else { continue }
                let kind = GoalKind(rawValue: f[0]) ?? .custom
                state.slots[slot] = KairoGoal(
                    slot: slot,
                    kind: kind,
                    label: f.count >= 4 && !f[3].isEmpty ? f[3] : kind.shortLabel,
                    progress: Int(f[1]) ?? 0,
                    target: max(1, Int(f[2]) ?? 1)
                )
            }
        }
        return state
    }

    /// `reminders|water=1,60|stretch=1,90|eyes=0,45|bed=0,1350|quiet=1,1320,480|sound=1|break=5|rounds=1`
    static func parseReminders(_ message: String) -> KairoReminders? {
        guard message.hasPrefix("reminders|") else { return nil }
        var r = KairoReminders()
        for part in message.split(separator: "|").dropFirst() {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = String(kv[0])
            let nums = kv[1].split(separator: ",").map { Int($0) ?? 0 }
            if let kind = ReminderKind(rawValue: key), nums.count >= 2 {
                r[kind] = ReminderSetting(enabled: nums[0] == 1, value: nums[1])
            } else if key == "quiet", nums.count >= 3 {
                r.quietEnabled = nums[0] == 1
                r.quietStart = nums[1]
                r.quietEnd = nums[2]
            } else if key == "sound", let v = nums.first {
                r.sound = v == 1
            } else if key == "break", let v = nums.first {
                r.breakMinutes = v
            } else if key == "rounds", let v = nums.first {
                r.rounds = max(1, v)
            }
        }
        return r
    }

    /// True when the firmware version is at least `major.minor`.
    static func firmware(_ version: String, atLeast major: Int, _ minor: Int) -> Bool {
        let parts = version.split(separator: ".").map { Int($0) ?? 0 }
        let ma = parts.first ?? 0
        let mi = parts.count > 1 ? parts[1] : 0
        return ma > major || (ma == major && mi >= minor)
    }
}
