import Foundation

// MARK: - Music (firmware v0.7+)

/// What's playing on Kairo, and the songs it knows.
struct KairoMusicState: Equatable {
    var playing = false
    var song = 0
    var titles: [String] = KairoMusicState.builtInTitles

    /// Same order as the firmware's built-in list ("My song" is added once you send one).
    static let builtInTitles = [
        "Kairo Theme", "Bamboo Bounce", "Twinkle Twinkle", "Ode to Joy",
        "Happy Birthday", "Jingle Bells", "Little Lamb", "Fur Elise",
    ]

    static func subtitle(for index: Int) -> String {
        switch index {
        case 0, 1: return "Kairo original"
        case 2, 6: return "Traditional"
        case 3, 7: return "Beethoven"
        case 4: return "Party song"
        case 5: return "Holiday classic"
        default: return "Composed by you"
        }
    }
}

/// One note in a song you compose: MIDI number (0 = rest) and length in sixteenths.
struct ComposedNote: Equatable, Identifiable {
    let id = UUID()
    var midi: Int
    var length: Int

    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var name: String {
        if midi == 0 { return "rest" }
        return "\(Self.names[midi % 12])\(midi / 12 - 1)"
    }

    static func == (lhs: ComposedNote, rhs: ComposedNote) -> Bool {
        lhs.midi == rhs.midi && lhs.length == rhs.length
    }

    /// "72.4,74.4,0.2"
    static func encode(_ notes: [ComposedNote]) -> String {
        notes.map { "\($0.midi).\($0.length)" }.joined(separator: ",")
    }

    static func decode(_ text: String) -> [ComposedNote] {
        text.split(separator: ",").compactMap { token in
            let p = token.split(separator: ".")
            guard p.count == 2, let m = Int(p[0]), let l = Int(p[1]) else { return nil }
            return ComposedNote(midi: m, length: l)
        }
    }
}

extension NobiProtocol {
    static let music = "music"
    static let musicStop = "music:stop"
    static let holdOn = "hold:on"
    static let holdOff = "hold:off"

    static func musicPlay(_ index: Int) -> String { "music:play:\(index)" }

    /// Up to 48 notes; Kairo stores it as "My song" and plays it.
    static func musicCustom(bpm: Int, notes: [ComposedNote]) -> String {
        "music:custom:\(min(240, max(40, bpm)))|\(ComposedNote.encode(Array(notes.prefix(48))))"
    }

    /// `music|playing=1|song=2|count=9|s0=Kairo Theme|s1=...`
    static func parseMusic(_ message: String) -> KairoMusicState? {
        guard message.hasPrefix("music|") else { return nil }
        let d = parsePipeKeyValue(prefix: "music", message: message)
        var state = KairoMusicState()
        state.playing = d["playing"] == "1"
        state.song = Int(d["song"] ?? "0") ?? 0
        let count = Int(d["count"] ?? "") ?? 0
        let titles = (0..<count).compactMap { d["s\($0)"] }
        if !titles.isEmpty { state.titles = titles }
        return state
    }
}
