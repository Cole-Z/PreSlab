import CoreGraphics
import Foundation

/// Top-left origin, straight RGBA8. Geometry code uses this instead of UIImage
/// so border math can be tested without a camera.
nonisolated struct RGBAImage: Sendable, Equatable {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(width: Int, height: Int, fill: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)) {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color = fill(x, y)
                let index = (y * width + x) * 4
                pixels[index] = color.0
                pixels[index + 1] = color.1
                pixels[index + 2] = color.2
                pixels[index + 3] = color.3
            }
        }
        self.init(width: width, height: height, pixels: pixels)
    }

    func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let index = (y * width + x) * 4
        return (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])
    }

    func luminance(_ x: Int, _ y: Int) -> Float {
        let sample = pixel(x, y)
        return (0.2126 * Float(sample.0) + 0.7152 * Float(sample.1) + 0.0722 * Float(sample.2)) / 255
    }

    func cgImage() -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big)
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func from(cgImage: CGImage) -> RGBAImage? {
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return RGBAImage(width: width, height: height, pixels: pixels)
    }
}
