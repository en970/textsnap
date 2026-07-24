import CoreGraphics
import AppKit

/// Renders a small, quiet dark card with a barely-there warm gradient and a fine random-noise
/// grain — a subtle dither texture rather than a loud, colorful one.
enum DitherGradient {
    static let cached: CGImage = image(size: CGSize(width: 220, height: 84))

    static func image(size: CGSize, scale: CGFloat = 2) -> CGImage {
        let w = Int(size.width * scale)
        let h = Int(size.height * scale)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        // Near-black, warm-tinted dark card -- close to macOS's own HUD chrome, just a touch warmer.
        let c1: (CGFloat, CGFloat, CGFloat) = (0.13, 0.12, 0.135)
        let c2: (CGFloat, CGFloat, CGFloat) = (0.20, 0.15, 0.13)
        let grainAmplitude: CGFloat = 5.0 / 255.0

        for y in 0..<h {
            for x in 0..<w {
                let t = CGFloat(x + y) / CGFloat(w + h)
                let r = c1.0 + (c2.0 - c1.0) * t
                let g = c1.1 + (c2.1 - c1.1) * t
                let b = c1.2 + (c2.2 - c1.2) * t

                let grain = CGFloat.random(in: -grainAmplitude...grainAmplitude)

                let idx = (y * w + x) * 4
                pixels[idx]     = channel(r + grain)
                pixels[idx + 1] = channel(g + grain)
                pixels[idx + 2] = channel(b + grain)
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

    private static func channel(_ value: CGFloat) -> UInt8 {
        UInt8(clamping: Int(min(max(value, 0), 1) * 255))
    }
}
