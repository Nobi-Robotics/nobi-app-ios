import Foundation

/// Kairo comes with a yellow or a white face plate (the white one is the panda from Day 16).
enum FacePlate: String, Codable, CaseIterable, Identifiable {
    case yellow
    case white

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yellow: return "Sunny yellow"
        case .white: return "Cloud white"
        }
    }

    /// Prefix of the hand-drawn boil frames in the asset catalog (…0, …1, …2).
    var artPrefix: String {
        switch self {
        case .yellow: return "KairoYellow"
        case .white: return "KairoWhite"
        }
    }
}

/// Treats you can give a robot.
enum NobiSnack: String, CaseIterable, Identifiable {
    case bamboo = "bamboo"
    case boba = "boba"
    case matcha = "matcha"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bamboo: return "Bamboo shoot"
        case .boba: return "Boba milk"
        case .matcha: return "Matcha cookie"
        }
    }

    var icon: String {
        switch self {
        case .bamboo: return "leaf.fill"
        case .boba: return "cup.and.saucer.fill"
        case .matcha: return "circle.grid.2x2.fill"
        }
    }

    var xpEarned: Int { 15 }
}

/// Everything the app remembers about one robot in the family. Persisted as JSON.
struct RobotProfile: Codable, Identifiable, Equatable {
    /// CoreBluetooth peripheral identifier (stable per phone).
    var id: UUID
    var name: String
    var plate: FacePlate
    /// Name the robot advertises over Bluetooth (e.g. "Kairo").
    var hardwareName: String
    var addedAt: Date

    // Care & bond
    var bondXP: Int = 120
    var totalPets: Int = 0
    var totalFeedings: Int = 0
    var lastMood: String = NobiEmotion.happy.rawValue

    // Hardware memory
    var savedBitmap: Data? = nil
    var lastFirmware: String? = nil

    var lastEmotion: NobiEmotion { NobiEmotion(rawValue: lastMood) ?? .happy }

    // MARK: - Bond level progression

    private static let thresholds = [0, 100, 300, 600, 1000]

    var bondLevel: Int {
        if bondXP < 100 { return 1 }
        if bondXP < 300 { return 2 }
        if bondXP < 600 { return 3 }
        if bondXP < 1000 { return 4 }
        return 5
    }

    var bondLevelTitle: String {
        switch bondLevel {
        case 1: return "New friend"
        case 2: return "Playmate"
        case 3: return "Bestie"
        case 4: return "True companion"
        default: return "Family"
        }
    }

    var xpProgressInLevel: Double {
        let lvl = bondLevel - 1
        if lvl >= 4 { return 1.0 }
        let start = Self.thresholds[lvl]
        let end = Self.thresholds[lvl + 1]
        return max(0, min(1, Double(bondXP - start) / Double(end - start)))
    }

    var xpToNextLevel: Int {
        let lvl = bondLevel - 1
        if lvl >= 4 { return 0 }
        return Self.thresholds[lvl + 1] - bondXP
    }
}
