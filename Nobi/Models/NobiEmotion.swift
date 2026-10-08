import Foundation

/// The 16 built-in firmware emotions.
enum NobiEmotion: String, CaseIterable, Identifiable {
    case normal
    case happy
    case angry
    case sad
    case tired
    case curious
    case surprised
    case love
    case sleepy
    case excited
    case confused
    case wink
    case suspicious
    case scared
    case bored
    case smug

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// How the app talks about the feeling: "Kairo feels ___."
    var feeling: String {
        switch self {
        case .normal: return "calm"
        case .happy: return "happy"
        case .angry: return "grumpy"
        case .sad: return "a bit blue"
        case .tired: return "tired"
        case .curious: return "curious"
        case .surprised: return "surprised"
        case .love: return "loved"
        case .sleepy: return "sleepy"
        case .excited: return "excited"
        case .confused: return "puzzled"
        case .wink: return "cheeky"
        case .suspicious: return "suspicious"
        case .scared: return "spooked"
        case .bored: return "bored"
        case .smug: return "smug"
        }
    }

    /// SF Symbol hint per emotion.
    var symbol: String {
        switch self {
        case .normal: return "face.smiling"
        case .happy: return "face.smiling.inverse"
        case .angry: return "flame"
        case .sad: return "cloud.rain"
        case .tired: return "bed.double"
        case .curious: return "magnifyingglass"
        case .surprised: return "exclamationmark.triangle"
        case .love: return "heart.fill"
        case .sleepy: return "moon.zzz"
        case .excited: return "sparkles"
        case .confused: return "questionmark.circle"
        case .wink: return "eye"
        case .suspicious: return "eye.trianglebadge.exclamationmark"
        case .scared: return "bolt"
        case .bored: return "minus.circle"
        case .smug: return "sunglasses"
        }
    }
}
