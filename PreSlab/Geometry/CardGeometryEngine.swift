import Foundation

nonisolated struct GeometryAssessment: Sendable {
    var finding: SideFinding
    var warped: RGBAImage?
}

nonisolated enum CardGeometryEngine {
    static func assess(_ image: RGBAImage) -> GeometryAssessment {
        guard let quad = RectangleDetector.detect(in: image) else {
            var finding = SideFinding(issues: [.noCard], quad: nil, insets: nil, adjustedByUser: false, unsupportedReason: PhotoIssue.noCard.explanation)
            finding.limitation = .cardNotFound
            return GeometryAssessment(
                finding: finding,
                warped: nil
            )
        }
        return assess(image: image, quad: quad, presetInsets: nil, adjustedByUser: false)
    }

    /// Re-runs warp, quality, and the border scan from a quad the user moved.
    /// `presetInsets` keeps a border the user already placed by hand.
    static func assess(
        image: RGBAImage,
        quad: CardQuad,
        presetInsets: BorderInsets?,
        adjustedByUser: Bool,
        presetBasis: CenteringMeasurementBasis? = nil
    ) -> GeometryAssessment {
        var issues = PhotoQuality.geometricIssues(image: image, quad: quad)
        // A corner the user dragged just past the photo edge is a deliberate
        // placement (the editor allows a small overscan), not a cut-off card.
        // The automatic pass still flags a card touching the frame.
        if adjustedByUser {
            issues.removeAll { $0 == .edgeCutOff }
        }
        guard QuadGeometry.isConvex(quad.pixelPoints(width: image.width, height: image.height)),
              let warped = CardWarp.flatten(image, quad: quad) else {
            if !issues.contains(.tooSkewed) { issues.append(.tooSkewed) }
            var finding = SideFinding(issues: issues, quad: quad, insets: nil, adjustedByUser: adjustedByUser, unsupportedReason: "The card corners could not be flattened.")
            finding.limitation = .invalidGeometry
            return GeometryAssessment(
                finding: finding,
                warped: nil
            )
        }
        issues.append(contentsOf: PhotoQuality.appearanceIssues(warped))

        let insets: BorderInsets?
        let unsupported: String?
        let basis: CenteringMeasurementBasis?
        let limitation: CenteringLimitation?
        if let presetInsets {
            insets = presetInsets.clamped()
            unsupported = nil
            basis = presetBasis ?? .manualPrintedFrame
            limitation = nil
        } else if issues.isEmpty {
            switch BorderScanner.scan(warped) {
            case .measured(let measured):
                insets = measured
                unsupported = nil
                basis = .automaticPrintedFrame
                limitation = nil
            case .unsupported(let reason):
                insets = nil
                unsupported = reason
                basis = nil
                limitation = .noStablePrintedFrame
            }
        } else {
            insets = nil
            unsupported = "Centering was not measured because the photo needs a retake."
            basis = nil
            limitation = .photoQuality
        }

        var finding = SideFinding(
            issues: issues,
            quad: quad,
            insets: insets,
            adjustedByUser: adjustedByUser,
            unsupportedReason: unsupported
        )
        finding.measurementBasis = basis
        finding.limitation = limitation
        return GeometryAssessment(
            finding: finding,
            warped: warped
        )
    }
}
