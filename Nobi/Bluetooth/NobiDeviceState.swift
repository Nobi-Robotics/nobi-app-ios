import Foundation

/// Phone-side Bluetooth availability (shared by every robot in the fleet).
enum BluetoothAvailability: Equatable {
    case unknown
    case poweredOn
    case poweredOff
    case unauthorized
    case unsupported

    var isReady: Bool { self == .poweredOn }

    var displayName: String {
        switch self {
        case .unknown: return "Waking Bluetooth…"
        case .poweredOn: return "Bluetooth ready"
        case .poweredOff: return "Bluetooth is off"
        case .unauthorized: return "Bluetooth not allowed"
        case .unsupported: return "Bluetooth unsupported"
        }
    }

    var help: String {
        switch self {
        case .unknown: return "Give it a second…"
        case .poweredOn: return "Your robots can hear you."
        case .poweredOff: return "Turn Bluetooth on in Control Centre so your robots can hear you."
        case .unauthorized: return "Allow Bluetooth for Nobi in Settings › Privacy › Bluetooth."
        case .unsupported: return "This device can't talk to Nobi robots."
        }
    }
}

/// The link between the phone and one robot.
enum RobotLink: Equatable {
    /// Not connected and not looking for it.
    case offline
    /// A pending connection: the phone will connect as soon as the robot is in range.
    case searching
    /// The user asked to connect and we are actively handshaking.
    case connecting
    case connected

    var isConnected: Bool { self == .connected }

    var displayName: String {
        switch self {
        case .offline: return "Offline"
        case .searching: return "Looking…"
        case .connecting: return "Connecting…"
        case .connected: return "Online"
        }
    }
}

/// Nobi OLED text sizing modes (Spec §12).
enum NobiTextSize: Int, CaseIterable, Identifiable {
    case small = 1
    case medium = 2
    case large = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Approximate visual point size for SwiftUI previews matching OLED pixels
    var previewFontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 18
        case .large: return 26
        }
    }

    var linesShownHint: String {
        switch self {
        case .small: return "Up to ~4 lines"
        case .medium: return "Two comfy lines"
        case .large: return "One big bold line"
        }
    }
}

/// Estimated proximity zones based on peripheral RSSI (Spec §9/§29).
enum ProximityZone: String, CaseIterable {
    case near
    case mid
    case far
    case unknown

    var displayName: String {
        switch self {
        case .near: return "Right here"
        case .mid: return "Nearby"
        case .far: return "Far away"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .near: return "antenna.radiowaves.left.and.right"
        case .mid: return "dot.radiowaves.right"
        case .far: return "wave.3.forward"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Parsed device state from `status`, `life:stats`, and game responses.
struct NobiDeviceState: Equatable {
    var name: String = "Kairo"
    var firmware: String = "0.6.3"
    var screen: String = "home"        // home | menu | games | life | focus | settings | text | notification | image | game
    var emotion: String = "normal"

    var brightness: Int = 180
    var textSize: Int = 2             // 1 = small, 2 = medium, 3 = large
    var imageScale: Int = 100         // 25...200%
    var hasImage: Bool = false
    /// OLED colours inverted (firmware 0.7+).
    var inverted: Bool = false
    /// Hold mode: what's on screen stays until changed (firmware 0.7+).
    var hold: Bool = false

    var lifeModeEnabled: Bool = true
    var sleeping: Bool = false

    // Personality stats (0...100)
    var mood: Int = 80
    var energy: Int = 75
    var attention: Int = 70
    var bond: Int = 50

    var proximity: String = "unknown"
    var timeSynced: Bool = false

    // Focus / Pomodoro
    var focusActive: Bool = false
    var focusRemainingSeconds: Int = 0

    // Mini-games
    var activeGame: String = "none"   // none | catch | says | stack | dodge
    var highCatch: Int = 0
    var highSays: Int = 0
    var highStack: Int = 0
    var highDodge: Int = 0

    var raw: String = ""

    static let empty = NobiDeviceState()

    init() {}

    init(dict: [String: String], raw: String = "") {
        self.raw = raw
        if let v = dict["name"] { name = v }
        if let v = dict["fw"] { firmware = v }
        if let v = dict["screen"] { screen = v } else if let v = dict["mode"] { screen = v }
        if let v = dict["emotion"] { emotion = v }
        if let v = dict["brightness"], let b = Int(v) { brightness = b }

        // Text size parser (spec §8: text=1|2|3)
        if let v = dict["text"], let ts = Int(v), (1...3).contains(ts) {
            textSize = ts
        } else if let v = dict["text_size"], let ts = Int(v), (1...3).contains(ts) {
            textSize = ts
        }

        // Image scale parser (spec §8: scale=100)
        if let v = dict["scale"], let sc = Int(v), (25...200).contains(sc) {
            imageScale = sc
        } else if let v = dict["image_scale"], let sc = Int(v), (25...200).contains(sc) {
            imageScale = sc
        }

        if let v = dict["image"] { hasImage = (v == "1") }
        if let v = dict["invert"] { inverted = (v == "1") }
        if let v = dict["hold"] { hold = (v == "1") }
        if let v = dict["life"] { lifeModeEnabled = (v == "1") }
        if let v = dict["sleep"] { sleeping = (v == "1") }
        if let v = dict["game"] { activeGame = v }

        if let v = dict["mood"], let n = Int(v) { mood = n }
        if let v = dict["energy"], let n = Int(v) { energy = n }
        if let v = dict["attention"], let n = Int(v) { attention = n }
        if let v = dict["bond"], let n = Int(v) { bond = n }
        if let v = dict["proximity"] { proximity = v }
        if let v = dict["time_synced"] { timeSynced = (v == "1") }
        if let v = dict["focus"] { focusActive = (v == "1") }
        if let v = dict["focus_remaining"], let n = Int(v) { focusRemainingSeconds = n }
    }

    /// Keeps the high scores we already know when a fresh `status` line arrives.
    mutating func carryScores(from old: NobiDeviceState) {
        highCatch = old.highCatch
        highSays = old.highSays
        highStack = old.highStack
        highDodge = old.highDodge
    }
}

/// Image transfer state machine.
enum ImageTransferState: Equatable {
    case idle
    case waitingBeginAck
    case sending(progress: Double)
    case waitingReceived
    case finishing
    case succeeded
    case failed(String)

    var isActive: Bool {
        switch self {
        case .waitingBeginAck, .sending, .waitingReceived, .finishing: return true
        default: return false
        }
    }

    var progress: Double {
        switch self {
        case .idle, .failed: return 0
        case .waitingBeginAck: return 0.04
        case .sending(let p): return 0.05 + 0.85 * p
        case .waitingReceived: return 0.92
        case .finishing: return 0.97
        case .succeeded: return 1
        }
    }

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .waitingBeginAck: return "Saying hello…"
        case .sending(let p): return "Beaming \(Int(p * 100))%"
        case .waitingReceived: return "Checking…"
        case .finishing: return "Drawing…"
        case .succeeded: return "On screen!"
        case .failed(let e): return "Oops: \(e)"
        }
    }
}

/// A robot seen during a scan that isn't in the family yet.
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int

    /// 0...3 signal bars from RSSI.
    var bars: Int {
        if rssi >= -60 { return 3 }
        if rssi >= -72 { return 2 }
        if rssi >= -85 { return 1 }
        return 0
    }

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id && lhs.rssi == rhs.rssi && lhs.name == rhs.name
    }
}
