import Foundation

nonisolated struct GeometryAssessment: Sendable {
    var finding: SideFinding
    var warped: RGBAImage?
}

nonisolated enum CardGeometryEngine {
    static func assess(_ image: RGBAImage) -> GeometryAssessment {
        guard let quad = RectangleDetector.detect(in: image) else {
            return GeometryAssessment(
                finding: SideFinding(issues: [.noCard], quad: nil, insets: nil, adjustedByUser: false, unsupportedReason: PhotoIssue.noCard.explanation),
                warped: nil
            )
        }
        return assess(image: image, quad: quad, presetInsets: nil, adjustedByUser: false)
    }

    /// Re-runs warp, quality, and the border scan from a quad the user moved.
    /// `presetInsets` keeps a border the user already placed by hand.
    static func assess(image: RGBAImage, quad: CardQuad, presetInsets: BorderInsets?, adjustedByUser: Bool) -> GeometryAssessment {
        var issues = PhotoQuality.geometricIssues(image: image, quad: quad)
        guard QuadGeometry.isConvex(quad.pixelPoints(width: image.width, height: image.height)),
              let warped = CardWarp.flatten(image, quad: quad) else {
            if !issues.contains(.tooSkewed) { issues.append(.tooSkewed) }
            return GeometryAssessment(
                finding: SideFinding(issues: issues, quad: quad, insets: nil, adjustedByUser: adjustedByUser, unsupportedReason: "The card corners could not be flattened."),
                warped: nil
            )
        }
        issues.append(contentsOf: PhotoQuality.appearanceIssues(warped))

        let insets: BorderInsets?
        let unsupported: String?
        if let presetInsets {
            insets = presetInsets.clamped()
            unsupported = nil
        } else if issues.isEmpty {
            switch BorderScanner.scan(warped) {
            case .measured(let measured):
                insets = measured
                unsupported = nil
            case .unsupported(let reason):
                insets = nil
                unsupported = reason
            }
        } else {
            insets = nil
            unsupported = "Centering was not measured because the photo needs a retake."
        }

        return GeometryAssessment(
            finding: SideFinding(
                issues: issues,
                quad: quad,
                insets: insets,
                adjustedByUser: adjustedByUser,
                unsupportedReason: unsupported
            ),
            warped: warped
        )
    }
}
