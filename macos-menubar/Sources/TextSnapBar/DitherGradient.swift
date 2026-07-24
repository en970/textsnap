import CoreGraphics
import AppKit

/// Renders a small warm gradient with an ordered (Bayer) dither pass baked in,
/// so the HUD background reads as a textured card instead of a flat gradient.
enum DitherGradient {
    static let cached: CGImage = image(size: CGSize(width: 220, height: 84))

    private static let bayer8x8: [[Int]] = [
        [ 0, 48, 12, 60,  3, 51, 15, 63],
        [32, 16, 44, 28, 35, 19, 47, 31],
        [ 8, 56,  4, 52, 11, 59,  7, 55],
        [40, 24, 36, 20, 43, 27, 39, 23],
        [ 2, 50, 14, 62,  1, 49, 13, 61],
        [34, 18, 46, 30, 33, 17, 45, 29],
        [10, 58,  6, 54,  9, 57,  5, 53],
        [42, 26, 38, 22, 41, 25, 37, 21],
    ]

    static func image(size: CGSize, scale: CGFloat = 2) -> CGImage {
        let w = Int(size.width * scale)
        let h = Int(size.height * scale)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        // Warm, muted plum -> coral/amber diagonal gradient.
        let c1: (CGFloat, CGFloat, CGFloat) = (0.29, 0.19, 0.40)
        let c2: (CGFloat, CGFloat, CGFloat) = (0.95, 0.55, 0.32)
        let levels: CGFloat = 6
        let strength: CGFloat = 1.0 / levels

        for y in 0..<h {
            for x in 0..<w {
                let t = CGFloat(x + y) / CGFloat(w + h)
                let r = c1.0 + (c2.0 - c1.0) * t
                let g = c1.1 + (c2.1 - c1.1) * t
                let b = c1.2 + (c2.2 - c1.2) * t

                let threshold = (CGFloat(bayer8x8[y % 8][x % 8]) / 64.0) - 0.5

                let idx = (y * w + x) * 4
                pixels[idx]     = quantize(r, threshold: threshold, levels: levels, strength: strength)
                pixels[idx + 1] = quantize(g, threshold: threshold, levels: levels, strength: strength)
                pixels[idx + 2] = quantize(b, threshold: threshold, levels: levels, strength: strength)
                pixels[idx + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private static func quantize(_ value: CGFloat, threshold: CGFloat, levels: CGFloat, strength: CGFloat) -> UInt8 {
        let adjusted = value + threshold * strength
        let stepped = (adjusted * levels).rounded() / levels
        let clamped = min(max(stepped, 0), 1)
        return UInt8(clamping: Int(clamped * 255))
    }
}
