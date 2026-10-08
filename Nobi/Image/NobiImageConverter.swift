import UIKit
import CoreGraphics

/// Converts a phone photo to the exact 128×64 1-bit buffer the firmware draws.
///
/// Pipeline (spec §13–14):
/// UIImage → orientation normalize → aspect-fit/fill onto 128×64 black canvas →
/// grayscale → ordered dither / fixed threshold → LSB-first row-major packing.
///
/// Packing: byteIndex = y*16 + x/8, bitIndex = x%8, ON = buffer[i] |= 1<<bit.
enum NobiImageConverter {

    enum FitMode: String, CaseIterable, Identifiable {
        case fit = "Fit"
        case fill = "Fill"
        var id: String { rawValue }
    }

    struct Options {
        var mode: FitMode = .fit
        var dither: Bool = true
        var invert: Bool = false
        var threshold: Double = 128  // used when dither == false
    }

    static let width = NobiProtocol.imageWidth   // 128
    static let height = NobiProtocol.imageHeight // 64

    // MARK: - Public API

    /// Returns exactly 1024 bytes, or nil on failure.
    static func convert(_ image: UIImage, options: Options) -> Data? {
        guard let normalized = normalized(image) else { return nil }
        guard let gray = grayscalePixels(of: normalized, mode: options.mode) else { return nil }
        var buffer = Data(repeating: 0, count: width * height / 8)
        for y in 0..<height {
            for x in 0..<width {
                let g = gray[y * width + x] // 0…255
                let on: Bool
                if options.dither {
                    on = Double(g) > Dithering.threshold(x: x, y: y)
                } else {
                    on = Double(g) > options.threshold
                }
                let pixelOn = options.invert ? !on : on
                if pixelOn {
                    let byteIndex = y * (width / 8) + x / 8
                    let bitIndex = x % 8
                    buffer[byteIndex] |= (1 << bitIndex)
                }
            }
        }
        return buffer
    }

    /// Builds a preview UIImage from the exact transmitted buffer.
    /// Rendered 1:1 and displayed with `.interpolation(.none)` for crisp pixels.
    static func previewImage(from buffer: Data, scale: Int = 4) -> UIImage? {
        guard buffer.count == width * height / 8 else { return nil }
        let w = width, h = height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: colorSpace, bitmapInfo: 0
        ) else { return nil }
        guard let px = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        for y in 0..<h {
            for x in 0..<w {
                let byteIndex = y * (w / 8) + x / 8
                let bitIndex = x % 8
                let on = (buffer[byteIndex] >> bitIndex) & 1 == 1
                px[y * w + x] = on ? 255 : 0
            }
        }
        guard let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
    }

    /// White-pixel ratio, useful for warning about all-black / all-white results.
    static func whiteRatio(of buffer: Data) -> Double {
        var bits = 0
        for b in buffer { bits += b.nonzeroBitCount }
        return Double(bits) / Double(width * height)
    }

    // MARK: - Steps

    /// Redraws so `imageOrientation` is baked in.
    private static func normalized(_ image: UIImage) -> UIImage? {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in image.draw(at: .zero) }
    }

    /// Draws onto a 128×64 black canvas (fit or fill), returns row-major gray bytes.
    private static func grayscalePixels(of image: UIImage, mode: FitMode) -> [UInt8]? {
        let W = CGFloat(width), H = CGFloat(height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: format)
        let canvas = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
            let iw = image.size.width, ih = image.size.height
            guard iw > 0, ih > 0 else { return }
            let canvasAspect = W / H
            let imgAspect = iw / ih
            var dw: CGFloat, dh: CGFloat
            switch mode {
            case .fit:
                if imgAspect > canvasAspect { dw = W; dh = W / imgAspect }
                else { dh = H; dw = H * imgAspect }
            case .fill:
                if imgAspect > canvasAspect { dh = H; dw = H * imgAspect }
                else { dw = W; dh = W / imgAspect }
            }
            let dx = (W - dw) / 2, dy = (H - dh) / 2
            image.draw(in: CGRect(x: dx, y: dy, width: dw, height: dh))
        }
        guard let cg = canvas.cgImage else { return nil }
        let bytesPerPixel = 4, bytesPerRow = width * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(
            data: &raw, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var gray = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Double(raw[i * 4]), g = Double(raw[i * 4 + 1]), b = Double(raw[i * 4 + 2])
            gray[i] = UInt8(min(255, max(0, r * 0.299 + g * 0.587 + b * 0.114)))
        }
        return gray
    }
}
