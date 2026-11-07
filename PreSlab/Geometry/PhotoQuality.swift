import CoreGraphics
import Foundation

nonisolated enum PhotoIssue: String, Codable, CaseIterable, Equatable, Sendable {
    case noCard
    case tooSmall
    case edgeCutOff
    case tooSkewed
    case blur
    case glare

    var title: String {
        switch self {
        case .noCard: "No card found"
        case .tooSmall: "Card is too small"
        case .edgeCutOff: "Card is cut off"
        case .tooSkewed: "Camera angle is too steep"
        case .blur: "Photo is soft"
        case .glare: "Glare on the card"
        }
    }

    var explanation: String {
        switch self {
        case .noCard:
            "No card edges were found. Use a plain background that contrasts with the card, and keep the whole card in the frame."
        case .tooSmall:
            "Move closer so the card fills more of the photo. Leave a small margin around it."
        case .edgeCutOff:
            "Part of the card touches the edge of the photo. Reframe so all four sides have a small margin."
        case .tooSkewed:
            "Hold the phone nearly square above the card. A steep angle stretches the borders."
        case .blur:
            "Hold steady and let the camera focus. The card edges need to be sharp before they can be measured."
        case .glare:
            "A bright patch is washing out the card. Tilt the card or move the light, then take another photo."
        }
    }
}

nonisolated enum PhotoQuality {
    /// Mean gradient of the strongest half-percent of pixels. Flat borders with a
    /// real edge score high. A box-blurred edge falls below this.
    /// Uncalibrated on real photos; the geometry study is what moves it.
    static let blurEdgeStrengthMinimum: Float = 0.22
    static let glareFractionLimit: Float = 0.08

    static func geometricIssues(image: RGBAImage, quad: CardQuad) -> [PhotoIssue] {
        var issues: [PhotoIssue] = []
        let pixels = quad.pixelPoints(width: image.width, height: image.height)
        if quad.points.contains(where: { $0.x < 0.02 || $0.y < 0.02 || $0.x > 0.98 || $0.y > 0.98 }) {
            issues.append(.edgeCutOff)
        }
        let width = pixels.map(\.x).max()! - pixels.map(\.x).min()!
        let height = pixels.map(\.y).max()! - pixels.map(\.y).min()!
        let shorterImageSide = Double(min(image.width, image.height))
        if min(width, height) < 0.50 * shorterImageSide {
            issues.append(.tooSmall)
        }
        if !QuadGeometry.isConvex(pixels) || isTooSkewed(pixels) {
            issues.append(.tooSkewed)
        }
        return issues
    }

    static func appearanceIssues(_ image: RGBAImage) -> [PhotoIssue] {
        var issues: [PhotoIssue] = []
        if edgeStrength(image) < blurEdgeStrengthMinimum {
            issues.append(.blur)
        }
        if glareFraction(image) > glareFractionLimit {
            issues.append(.glare)
        }
        return issues
    }

    static func edgeStrength(_ image: RGBAImage) -> Float {
        guard image.width > 4, image.height > 4 else { return 0 }
        let step = max(1, min(image.width, image.height) / 350)
        var magnitudes: [Float] = []
        magnitudes.reserveCapacity((image.width / step) * (image.height / step))
        var y = 1
        while y < image.height - 1 {
            var x = 1
            while x < image.width - 1 {
                let gx = image.luminance(x + 1, y) - image.luminance(x - 1, y)
                let gy = image.luminance(x, y + 1) - image.luminance(x, y - 1)
                magnitudes.append(abs(gx) + abs(gy))
                x += step
            }
            y += step
        }
        guard !magnitudes.isEmpty else { return 0 }
        magnitudes.sort()
        let start = Int(Double(magnitudes.count) * 0.995)
        let peak = magnitudes[start...]
        let total = peak.reduce(Float(0), +)
        return total / Float(peak.count)
    }

    static func glareFraction(_ image: RGBAImage) -> Float {
        var bright = 0
        let count = image.width * image.height
        var index = 0
        while index < image.pixels.count {
            let red = Float(image.pixels[index]) / 255
            let green = Float(image.pixels[index + 1]) / 255
            let blue = Float(image.pixels[index + 2]) / 255
            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let saturation = maxChannel == 0 ? Float(0) : (maxChannel - minChannel) / maxChannel
            if luminance > 0.96 && saturation < 0.12 {
                bright += 1
            }
            index += 4
        }
        return Float(bright) / Float(count)
    }

    private static func isTooSkewed(_ points: [CGPoint]) -> Bool {
        let top = QuadGeometry.edgeLength(points[0], points[1])
        let right = QuadGeometry.edgeLength(points[1], points[2])
        let bottom = QuadGeometry.edgeLength(points[2], points[3])
        let left = QuadGeometry.edgeLength(points[3], points[0])
        if ratio(top, bottom) > 1.45 || ratio(left, right) > 1.45 {
            return true
        }
        for index in 0..<4 {
            let angle = QuadGeometry.cornerAngleDegrees(points, at: index)
            if abs(angle - 90) > 30 { return true }
        }
        return false
    }

    private static func ratio(_ a: Double, _ b: Double) -> Double {
        let low = min(a, b)
        guard low > 1 else { return 999 }
        return max(a, b) / low
    }
}
