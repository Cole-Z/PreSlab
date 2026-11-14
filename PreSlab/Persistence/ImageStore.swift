import Foundation
import ImageIO
import UIKit

enum ImageStore {
    static func saveJPEG(_ image: UIImage, name: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: fileURL(name), options: .atomic)
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(name).path)
    }

    /// Decode only a small thumbnail, away from the main thread. Library rows
    /// previously loaded full-resolution photos while drawing their first frame.
    nonisolated static func thumbnail(_ name: String) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL(name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 192,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
    }

    nonisolated private static func fileURL(_ name: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Assessments", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(name)
    }
}

enum ImageCoding {
    /// Draws the image upright and caps the long side so measurement stays fast.
    static func rgba(from image: UIImage, maxSide: Int = 1800) -> RGBAImage? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        let scale = min(1, CGFloat(maxSide) / max(longest, 1))
        let width = max(1, Int((pixelWidth * scale).rounded()))
        let height = max(1, Int((pixelHeight * scale).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return RGBAImage.from(cgImage: cgImage)
    }

    nonisolated static func uiImage(from image: RGBAImage) -> UIImage? {
        guard let cgImage = image.cgImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
