import Foundation

/// The four built-in Kairo mini-games (Spec §32-§39).
enum NobiGame: String, CaseIterable, Identifiable {
    case catchBamboo = "catch"
    case says = "says"
    case stack = "stack"
    case dodge = "dodge"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catchBamboo: return "Bamboo Catch"
        case .says: return "Kairo Says"
        case .stack: return "Bamboo Stack"
        case .dodge: return "Panda Dodge"
        }
    }

    var subtitle: String {
        switch self {
        case .catchBamboo: return "Catch falling bamboo before it hits the ground."
        case .says: return "Copy Kairo's eye cues with its buttons."
        case .stack: return "Stack moving bamboo blocks as high as possible."
        case .dodge: return "Run, jump, and dodge incoming obstacles."
        }
    }

    var icon: String {
        switch self {
        case .catchBamboo: return "leaf.fill"
        case .says: return "eye.fill"
        case .stack: return "square.3.layers.3d.down.right"
        case .dodge: return "figure.run"
        }
    }

    var storageKey: String {
        switch self {
        case .catchBamboo: return "bestCatch"
        case .says: return "bestSays"
        case .stack: return "bestStack"
        case .dodge: return "bestDodge"
        }
    }

    var bestScore: Int {
        get { UserDefaults.standard.integer(forKey: storageKey) }
        nonmutating set { UserDefaults.standard.set(max(bestScore, newValue), forKey: storageKey) }
    }

    func recordScore(_ score: Int) {
        UserDefaults.standard.set(max(bestScore, score), forKey: storageKey)
    }

    struct ControlGuide {
        let button: String
        let action: String
    }

    var controls: [ControlGuide] {
        switch self {
        case .catchBamboo:
            return [
                ControlGuide(button: "LEFT", action: "Move left"),
                ControlGuide(button: "RIGHT", action: "Move right"),
                ControlGuide(button: "ACTION", action: "Dash toward falling bamboo"),
                ControlGuide(button: "ACTION (hold)", action: "Pause / resume"),
                ControlGuide(button: "BACK", action: "Quit to game picker"),
                ControlGuide(button: "BACK (hold)", action: "Emergency exit to Home"),
            ]
        case .says:
            return [
                ControlGuide(button: "Look LEFT", action: "Press LEFT button"),
                ControlGuide(button: "Look RIGHT", action: "Press RIGHT button"),
                ControlGuide(button: "Heart Eyes", action: "Press ACTION button"),
                ControlGuide(button: "BACK", action: "Quit (BACK is never an eye cue)"),
                ControlGuide(button: "BACK (hold)", action: "Quit to Home"),
            ]
        case .stack:
            return [
                ControlGuide(button: "LEFT", action: "Nudge left"),
                ControlGuide(button: "RIGHT", action: "Nudge right"),
                ControlGuide(button: "ACTION", action: "Drop block on stack"),
                ControlGuide(button: "ACTION (hold)", action: "Pause / resume"),
                ControlGuide(button: "BACK", action: "Quit to game picker"),
                ControlGuide(button: "BACK (hold)", action: "Quit to Home"),
            ]
        case .dodge:
            return [
                ControlGuide(button: "LEFT", action: "Move left"),
                ControlGuide(button: "RIGHT", action: "Move right"),
                ControlGuide(button: "ACTION", action: "Jump over obstacle"),
                ControlGuide(button: "ACTION (hold)", action: "Pause / resume"),
                ControlGuide(button: "BACK", action: "Quit to game picker"),
                ControlGuide(button: "BACK (hold)", action: "Quit to Home"),
            ]
        }
    }

    var howToPlayRules: [String] {
        switch self {
        case .catchBamboo:
            return [
                "Bamboo stalks fall randomly from the top of the OLED screen.",
                "Move Kairo underneath each stalk to catch it.",
                "Three misses will end your run.",
                "Game speed gradually increases as your score rises.",
            ]
        case .says:
            return [
                "Kairo's animated eyes display a sequence of directional cues.",
                "Watch closely: Look Left = LEFT button, Look Right = RIGHT button, Heart Eyes = ACTION button.",
                "BACK button is strictly for quitting; Kairo will never prompt for BACK.",
                "Each round adds another step to test your panda memory!",
            ]
        case .stack:
            return [
                "A bamboo block slides horizontally back and forth.",
                "Press ACTION to drop it squarely on top of the stack.",
                "Any overhang is sliced off — blocks get narrower!",
                "Stack as many blocks as you can without missing.",
            ]
        case .dodge:
            return [
                "Kairo runs along the bottom of the screen.",
                "Press ACTION to leap over approaching rocks and obstacles.",
                "Steer with LEFT and RIGHT to navigate tricky gaps.",
                "Don't bonk!",
            ]
        }
    }
}
