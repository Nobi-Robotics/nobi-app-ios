import Foundation

/// 4×4 Bayer matrix for ordered dithering (spec §14).
enum Dithering {
    static let bayer: [[Int]] = [
        [0,  8,  2, 10],
        [12, 4, 14,  6],
        [3, 11,  1,  9],
        [15, 7, 13,  5],
    ]

    /// Per-pixel threshold in 0…255 for ordered dithering.
    static func threshold(x: Int, y: Int) -> Double {
        (Double(bayer[y % 4][x % 4]) + 0.5) * 16.0
    }
}
