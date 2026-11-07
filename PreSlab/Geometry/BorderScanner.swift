import Foundation

nonisolated enum BorderScanResult: Equatable, Sendable {
    case measured(BorderInsets)
    case unsupported(String)
}

nonisolated enum BorderScanner {
    /// Looks inward from each edge for one consistent color step.
    /// A full-art card, or a photo with no stable step, comes back unsupported.
    static func scan(_ image: RGBAImage) -> BorderScanResult {
        guard image.width > 40, image.height > 40 else {
            return .unsupported("The card image is too small to measure a border.")
        }
        guard let left = edgePosition(image, side: .left),
              let right = edgePosition(image, side: .right),
              let top = edgePosition(image, side: .top),
              let bottom = edgePosition(image, side: .bottom) else {
            return .unsupported("No consistent artwork border was found. Full-art and borderless cards are not measured.")
        }
        let insets = BorderInsets(
            left: Double(left) / Double(image.width),
            right: Double(right) / Double(image.width),
            top: Double(top) / Double(image.height),
            bottom: Double(bottom) / Double(image.height)
        ).clamped()
        return .measured(insets)
    }

    private enum Side { case left, right, top, bottom }

    /// Returns the border width in pixels, or nil when the step is weak or wanders.
    private static func edgePosition(_ image: RGBAImage, side: Side) -> Float? {
        let horizontal = side == .left || side == .right
        let length = horizontal ? image.height : image.width
        let depth = horizontal ? image.width : image.height
        let search = max(8, Int(Double(depth) * 0.22))
        let start = length / 5
        let end = length * 4 / 5
        let strideCount = max(1, length / 100)
        var positions: [Float] = []
        var strengths: [Float] = []
        var sample = start
        while sample < end {
            var bestIndex = 1
            var bestGradient: Float = 0
            for index in 2..<(search - 1) {
                let gradient = gradient(image, side: side, along: sample, depth: index)
                if gradient > bestGradient {
                    bestGradient = gradient
                    bestIndex = index
                }
            }
            positions.append(Float(bestIndex))
            strengths.append(bestGradient)
            sample += strideCount
        }
        guard positions.count >= 8 else { return nil }
        let strength = median(strengths)
        let position = median(positions)
        let deviation = median(positions.map { abs($0 - position) })
        let positionLimit = Float(search - 3)
        // The step has to be strong, agree along the side, and sit inside the
        // search window. Hitting the window edge means there was no border there.
        guard strength >= 0.18, deviation <= 3.5, position > 2, position < positionLimit else {
            return nil
        }
        return position
    }

    private static func gradient(_ image: RGBAImage, side: Side, along: Int, depth: Int) -> Float {
        switch side {
        case .left:
            return abs(image.luminance(depth + 1, along) - image.luminance(depth - 1, along))
        case .right:
            let x = image.width - 1 - depth
            return abs(image.luminance(x - 1, along) - image.luminance(x + 1, along))
        case .top:
            return abs(image.luminance(along, depth + 1) - image.luminance(along, depth - 1))
        case .bottom:
            let y = image.height - 1 - depth
            return abs(image.luminance(along, y - 1) - image.luminance(along, y + 1))
        }
    }

    private static func median(_ values: [Float]) -> Float {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
