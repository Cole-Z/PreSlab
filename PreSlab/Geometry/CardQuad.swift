import CoreGraphics
import Foundation

nonisolated struct NormPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    func pixel(width: Int, height: Int) -> CGPoint {
        CGPoint(x: x * Double(width - 1), y: y * Double(height - 1))
    }
}

/// Card corners in normalized image space. Origin is the top-left.
nonisolated struct CardQuad: Codable, Equatable, Sendable {
    var topLeft: NormPoint
    var topRight: NormPoint
    var bottomRight: NormPoint
    var bottomLeft: NormPoint

    var points: [NormPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    func pixelPoints(width: Int, height: Int) -> [CGPoint] {
        points.map { $0.pixel(width: width, height: height) }
    }

    static func axisAligned(left: Double, top: Double, right: Double, bottom: Double) -> CardQuad {
        CardQuad(
            topLeft: NormPoint(x: left, y: top),
            topRight: NormPoint(x: right, y: top),
            bottomRight: NormPoint(x: right, y: bottom),
            bottomLeft: NormPoint(x: left, y: bottom)
        )
    }

    static var fullImage: CardQuad {
        axisAligned(left: 0, top: 0, right: 1, bottom: 1)
    }

    /// A conservative starting box for fully manual recovery when Vision does
    /// not return a card. It is only an editor seed, never an automatic result.
    static func centeredStandardCardSeed(imageWidth: Int, imageHeight: Int) -> CardQuad {
        guard imageWidth > 1, imageHeight > 1 else { return .fullImage }
        let availableWidth = Double(imageWidth - 1) * 0.80
        let availableHeight = Double(imageHeight - 1) * 0.80
        let cardAspect = 2.5 / 3.5
        let width: Double
        let height: Double
        if availableWidth / availableHeight > cardAspect {
            height = availableHeight
            width = height * cardAspect
        } else {
            width = availableWidth
            height = width / cardAspect
        }
        let left = (Double(imageWidth - 1) - width) / 2 / Double(imageWidth - 1)
        let top = (Double(imageHeight - 1) - height) / 2 / Double(imageHeight - 1)
        let right = left + width / Double(imageWidth - 1)
        let bottom = top + height / Double(imageHeight - 1)
        return .axisAligned(left: left, top: top, right: right, bottom: bottom)
    }
}

/// Coordinates of the expanded warp used by the artwork editor. The card
/// occupies the centre of that canvas; the surrounding ring is real photo
/// around the card, so a border line can be placed (and seen) in the ring.
/// A line at `pad` is exactly on the card edge; inside the ring is past it.
nonisolated enum PaddedCardCoordinates {
    static let pad = 0.10
    static let expansion = 1.25 // 0.5 / (0.5 - pad)

    static func paddedFraction(fromCard card: Double) -> Double {
        pad + card * (1 - 2 * pad)
    }

    static func cardFraction(fromPadded padded: Double) -> Double {
        (padded - pad) / (1 - 2 * pad)
    }

    static func expandedQuad(_ quad: CardQuad) -> CardQuad? {
        // Expand in the flat card's plane. Scaling the photographed corners
        // about their centroid shifts the inset outline on perspective photos.
        guard let mapping = Homography.mapping(
            from: [(0, 0), (1, 0), (1, 1), (0, 1)],
            to: quad.points.map { ($0.x, $0.y) }) else { return nil }
        let low = cardFraction(fromPadded: 0)
        let high = cardFraction(fromPadded: 1)
        func point(_ x: Double, _ y: Double) -> NormPoint? {
            guard let result = mapping.apply(x: x, y: y), result.0.isFinite, result.1.isFinite else { return nil }
            return NormPoint(x: result.0, y: result.1)
        }
        guard let tl = point(low, low), let tr = point(high, low),
              let br = point(high, high), let bl = point(low, high) else { return nil }
        return CardQuad(topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl)
    }
}

nonisolated struct BorderInsets: Codable, Equatable, Sendable {
    var left: Double
    var right: Double
    var top: Double
    var bottom: Double

    /// Editor positions can extend into the photo margin, but such positions
    /// must not silently become zero-width borders in a saved measurement.
    var isValidPlacement: Bool {
        [left, right, top, bottom].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 0.4 }
            && left + right <= 0.75 && top + bottom <= 0.75
    }

    /// Both sides of an axis at zero means the lines were never moved off
    /// the card edge: that axis was not measured. One zero side (a sliver
    /// of border) with a real opposite side is a valid measurement.
    var isMeasurable: Bool {
        isValidPlacement && left + right > 0.0001 && top + bottom > 0.0001
    }

    /// Keeps each border inside the card and leaves artwork in the middle.
    /// A border may be zero: a badly off-center card can have almost no
    /// border on one side, and forcing a 1% floor biases it toward 50/50.
    func clamped() -> BorderInsets {
        func pair(_ a: Double, _ b: Double) -> (Double, Double) {
            var first = min(max(a, 0), 0.4)
            var second = min(max(b, 0), 0.4)
            if first + second > 0.75 {
                let scale = 0.75 / (first + second)
                first *= scale
                second *= scale
            }
            return (first, second)
        }
        let horizontal = pair(left, right)
        let vertical = pair(top, bottom)
        return BorderInsets(left: horizontal.0, right: horizontal.1, top: vertical.0, bottom: vertical.1)
    }
}

nonisolated struct CenteringRatios: Equatable, Sendable {
    /// Share of the horizontal border that sits on the left. 0.40 is a 40/60 left/right split.
    var leftShare: Double
    /// Share of the vertical border that sits on the top.
    var topShare: Double

    init(insets: BorderInsets) {
        let horizontal = insets.left + insets.right
        let vertical = insets.top + insets.bottom
        leftShare = horizontal > 0 ? insets.left / horizontal : 0.5
        topShare = vertical > 0 ? insets.top / vertical : 0.5
    }

    var horizontalText: String { Self.splitText(leftShare) }
    var verticalText: String { Self.splitText(topShare) }

    private static func splitText(_ share: Double) -> String {
        let first = Int((share * 100).rounded())
        let clamped = min(100, max(0, first))
        return "\(clamped)/\(100 - clamped)"
    }
}

nonisolated enum QuadGeometry {
    static func isConvex(_ points: [CGPoint]) -> Bool {
        guard points.count == 4 else { return false }
        var sign = 0
        for index in 0..<4 {
            let a = points[index]
            let b = points[(index + 1) % 4]
            let c = points[(index + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            let current = cross > 0 ? 1 : (cross < 0 ? -1 : 0)
            if current == 0 { continue }
            if sign == 0 { sign = current }
            else if current != sign { return false }
        }
        return sign != 0
    }

    static func cornerAngleDegrees(_ points: [CGPoint], at index: Int) -> Double {
        let vertex = points[index]
        let previous = points[(index + 3) % 4]
        let next = points[(index + 1) % 4]
        let first = CGVector(dx: previous.x - vertex.x, dy: previous.y - vertex.y)
        let second = CGVector(dx: next.x - vertex.x, dy: next.y - vertex.y)
        let magnitude = hypot(first.dx, first.dy) * hypot(second.dx, second.dy)
        guard magnitude > 0 else { return 0 }
        let cosine = min(1, max(-1, (first.dx * second.dx + first.dy * second.dy) / magnitude))
        return acos(cosine) * 180 / .pi
    }

    static func edgeLength(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(b.x - a.x, b.y - a.y)
    }
}
