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
}

nonisolated struct BorderInsets: Codable, Equatable, Sendable {
    var left: Double
    var right: Double
    var top: Double
    var bottom: Double

    /// Keeps each border inside the card and leaves artwork in the middle.
    func clamped() -> BorderInsets {
        func pair(_ a: Double, _ b: Double) -> (Double, Double) {
            var first = min(max(a, 0.01), 0.4)
            var second = min(max(b, 0.01), 0.4)
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
        leftShare = insets.left / (insets.left + insets.right)
        topShare = insets.top / (insets.top + insets.bottom)
    }

    var horizontalText: String { Self.splitText(leftShare) }
    var verticalText: String { Self.splitText(topShare) }

    private static func splitText(_ share: Double) -> String {
        let first = Int((share * 100).rounded())
        let clamped = min(99, max(1, first))
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
