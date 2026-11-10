import Foundation

nonisolated enum BorderScanResult: Equatable, Sendable {
    case measured(BorderInsets)
    case unsupported(String)
}

nonisolated enum BorderScanRejection: String, Equatable, Sendable {
    case imageTooSmall
    case weakGradient
    case inconsistentPosition
    case outsideSearchWindow
}

/// Calibration data for one card side. This is diagnostic evidence, not a
/// user-facing confidence score.
nonisolated struct BorderSideDiagnostics: Equatable, Sendable {
    var candidatePositionPixels: Float
    var medianGradient: Float
    var medianDeviationPixels: Float
    var searchDepthPixels: Int
    var sampleCount: Int
    var rejection: BorderScanRejection?

    var acceptedPositionPixels: Float? { rejection == nil ? candidatePositionPixels : nil }
}

nonisolated struct BorderScanDiagnostics: Equatable, Sendable {
    var left: BorderSideDiagnostics
    var right: BorderSideDiagnostics
    var top: BorderSideDiagnostics
    var bottom: BorderSideDiagnostics

    var allSidesAccepted: Bool {
        [left, right, top, bottom].allSatisfy { $0.rejection == nil }
    }
}

nonisolated enum BorderScanner {
    /// Looks inward from each edge for one consistent color step.
    static func scan(_ image: RGBAImage) -> BorderScanResult {
        guard image.width > 40, image.height > 40 else {
            return .unsupported("The card image is too small to measure a border.")
        }
        let diagnostics = diagnose(image)
        guard let left = diagnostics.left.acceptedPositionPixels,
              let right = diagnostics.right.acceptedPositionPixels,
              let top = diagnostics.top.acceptedPositionPixels,
              let bottom = diagnostics.bottom.acceptedPositionPixels else {
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

    static func diagnose(_ image: RGBAImage) -> BorderScanDiagnostics {
        guard image.width > 40, image.height > 40 else {
            let rejected = BorderSideDiagnostics(
                candidatePositionPixels: 0,
                medianGradient: 0,
                medianDeviationPixels: 0,
                searchDepthPixels: 0,
                sampleCount: 0,
                rejection: .imageTooSmall
            )
            return BorderScanDiagnostics(left: rejected, right: rejected, top: rejected, bottom: rejected)
        }
        return BorderScanDiagnostics(
            left: edgeDiagnostics(image, side: .left),
            right: edgeDiagnostics(image, side: .right),
            top: edgeDiagnostics(image, side: .top),
            bottom: edgeDiagnostics(image, side: .bottom)
        )
    }

    private enum Side { case left, right, top, bottom }

    private static func edgeDiagnostics(_ image: RGBAImage, side: Side) -> BorderSideDiagnostics {
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
                let value = gradient(image, side: side, along: sample, depth: index)
                if value > bestGradient {
                    bestGradient = value
                    bestIndex = index
                }
            }
            positions.append(Float(bestIndex))
            strengths.append(bestGradient)
            sample += strideCount
        }
        guard positions.count >= 8 else {
            return BorderSideDiagnostics(
                candidatePositionPixels: 0,
                medianGradient: 0,
                medianDeviationPixels: 0,
                searchDepthPixels: search,
                sampleCount: positions.count,
                rejection: .inconsistentPosition
            )
        }
        let strength = median(strengths)
        let position = median(positions)
        let deviation = median(positions.map { abs($0 - position) })
        let positionLimit = Float(search - 3)
        // The step has to be strong, agree along the side, and sit inside the
        // search window. Hitting the window edge means there was no border there.
        let rejection: BorderScanRejection?
        if strength < 0.18 {
            rejection = .weakGradient
        } else if deviation > 3.5 {
            rejection = .inconsistentPosition
        } else if position <= 2 || position >= positionLimit {
            rejection = .outsideSearchWindow
        } else {
            rejection = nil
        }
        return BorderSideDiagnostics(
            candidatePositionPixels: position,
            medianGradient: strength,
            medianDeviationPixels: deviation,
            searchDepthPixels: search,
            sampleCount: positions.count,
            rejection: rejection
        )
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
