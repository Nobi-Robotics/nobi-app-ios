import CoreBluetooth
import Foundation

/// All BLE UUIDs and protocol string builders for Kairo.
/// Firmware v0.6.x and v0.7 (goals, reminders, focus cycles) — BLE only, no Wi-Fi.
enum NobiProtocol {
    // MARK: - BLE identity

    static let deviceName = "Kairo"

    static let service = CBUUID(string: "A91E0001-7C1A-4B67-9C53-1B7A6E1F0001")
    static let commandRX = CBUUID(string: "A91E0002-7C1A-4B67-9C53-1B7A6E1F0001")
    static let tx = CBUUID(string: "A91E0003-7C1A-4B67-9C53-1B7A6E1F0001")
    static let imageRX = CBUUID(string: "A91E0004-7C1A-4B67-9C53-1B7A6E1F0001")

    // MARK: - Image spec

    static let imageWidth = 128
    static let imageHeight = 64
    static let imageBytesPerRow = 16
    static let imageByteCount = 1024

    // MARK: - Command builders

    static let ping = "ping"
    static let status = "status"
    static let face = "face"
    static let pet = "pet"
    static let sleep = "sleep"
    static let wake = "wake"

    static let lifeOn = "life:on"
    static let lifeOff = "life:off"
    static let lifeStats = "life:stats"

    static let gamesScores = "games:scores"
    static let gameStop = "game:stop"
    static let pomodoroStop = "pomodoro:stop"
    static let pomodoroStatus = "pomodoro:status"

    static let imageBegin = "image_begin"
    static let imageEnd = "image_end"
    static let imageShow = "image_show"
    static let imageClear = "image_clear"

    static func timeSync(unix: Int, offsetMinutes: Int) -> String {
        "time:\(unix)|\(offsetMinutes)"
    }

    static func emotion(_ name: String) -> String {
        "emotion:\(name)"
    }

    static func brightness(_ value: Int) -> String {
        "brightness:\(min(255, max(10, value)))"
    }

    /// Text size: 1 = Small, 2 = Medium, 3 = Large.
    static func textSize(_ size: Int) -> String {
        "text_size:\(min(3, max(1, size)))"
    }

    /// Image scale percentage: 25...200.
    static func imageScale(_ percent: Int) -> String {
        "image_scale:\(min(200, max(25, percent)))"
    }

    /// Firmware truncates to ~100 chars and renders basic Latin/ASCII.
    static func text(_ message: String) -> String {
        let sanitized = sanitizeText(message)
        let truncated = String(sanitized.prefix(100))
        return "text:\(truncated)"
    }

    /// Fields must not contain literal `|`.
    static func notify(app: String, title: String, message: String) -> String {
        let a = sanitizePipeField(app)
        let t = sanitizePipeField(title)
        let m = sanitizePipeField(message)
        return "notify:\(a)|\(t)|\(m)"
    }

    static func pomodoroStart(minutes: Int) -> String {
        "pomodoro:start:\(min(180, max(1, minutes)))"
    }

    static func gameLaunch(_ game: String) -> String {
        "game:\(game)"
    }

    static func proximity(_ zone: String) -> String {
        "proximity:\(zone)"
    }

    // MARK: - Sanitizers

    /// Replace `|` (protocol delimiter) with `/` so the frame stays valid.
    static func sanitizePipeField(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "/")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// OLED font is optimized for basic Latin/ASCII — strip/replace the rest.
    static func sanitizeText(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            let v = scalar.value
            if v >= 0x20 && v <= 0x7E {
                out.unicodeScalars.append(scalar)
            } else if v == 0x0A || v == 0x0D {
                out += " "
            } else {
                switch scalar {
                case "“", "”", "„": out += "\""
                case "‘", "’", "‚": out += "'"
                case "–", "—": out += "-"
                case "…": out += "..."
                default:
                    break
                }
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Parsers

    /// Parses `prefix|k1=v1|k2=v2|...` into key-value pairs.
    /// Token order is NOT guaranteed, unknown keys are retained.
    static func parsePipeKeyValue(prefix: String, message: String) -> [String: String] {
        var result: [String: String] = [:]
        let parts = message.split(separator: "|")
        guard let first = parts.first, first == prefix else { return result }
        for component in parts.dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1)
            if pair.count == 2 {
                result[String(pair[0])] = String(pair[1])
            }
        }
        return result
    }

    static func parseStatus(_ value: String) -> [String: String] {
        parsePipeKeyValue(prefix: "status", message: value)
    }

    static func parseLifeStats(_ value: String) -> [String: String] {
        parsePipeKeyValue(prefix: "life", message: value)
    }

    static func parseGameScores(_ value: String) -> [String: Int] {
        let dict = parsePipeKeyValue(prefix: "scores", message: value)
        var scores: [String: Int] = [:]
        for (k, v) in dict {
            if let n = Int(v) {
                scores[k] = n
            }
        }
        return scores
    }

    static func parsePomodoroStatus(_ value: String) -> (active: Bool, remainingSeconds: Int)? {
        let dict = parsePipeKeyValue(prefix: "pomodoro", message: value)
        guard !dict.isEmpty else { return nil }
        let active = (dict["active"] == "1")
        let remaining = Int(dict["remaining"] ?? "0") ?? 0
        return (active, remaining)
    }
}
