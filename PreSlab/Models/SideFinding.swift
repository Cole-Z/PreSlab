import Foundation

nonisolated enum CardSide: String, Codable, CaseIterable, Sendable {
    case front
    case back

    var title: String { self == .front ? "Front" : "Back" }
}

nonisolated enum CenteringMeasurementBasis: String, Codable, Sendable {
    case automaticPrintedFrame
    case manualPrintedFrame
    case userDefinedVisualReference

    var title: String {
        switch self {
        case .automaticPrintedFrame: "Printed frame detected automatically"
        case .manualPrintedFrame: "Printed frame placed manually"
        case .userDefinedVisualReference: "User-defined visual reference"
        }
    }

    var supportsGradingComparison: Bool { self != .userDefinedVisualReference }
}

nonisolated enum CenteringLimitation: String, Codable, Sendable {
    case cardNotFound
    case photoQuality
    case invalidGeometry
    case noStablePrintedFrame
}

nonisolated struct SideFinding: Codable, Equatable, Sendable {
    var issues: [PhotoIssue]
    var quad: CardQuad?
    var insets: BorderInsets?
    var adjustedByUser: Bool
    var unsupportedReason: String?
    /// Optional raw values preserve decoding of assessments saved before Phase 5.
    var measurementBasisRaw: String? = nil
    var limitationRaw: String? = nil

    static let empty = SideFinding(issues: [], quad: nil, insets: nil, adjustedByUser: false, unsupportedReason: nil)

    var passedQuality: Bool { issues.isEmpty }

    var hasMeasurableCentering: Bool { insets?.isMeasurable ?? false }

    var measurementBasis: CenteringMeasurementBasis? {
        get {
            if let measurementBasisRaw,
               let stored = CenteringMeasurementBasis(rawValue: measurementBasisRaw) {
                return stored
            }
            // Legacy measured findings were either automatic or manually adjusted
            // printed-border measurements; preserve their previous behavior.
            guard hasMeasurableCentering else { return nil }
            return adjustedByUser ? .manualPrintedFrame : .automaticPrintedFrame
        }
        set { measurementBasisRaw = newValue?.rawValue }
    }

    var limitation: CenteringLimitation? {
        get { limitationRaw.flatMap(CenteringLimitation.init(rawValue:)) }
        set { limitationRaw = newValue?.rawValue }
    }

    var hasGradingComparableCentering: Bool {
        hasMeasurableCentering && (measurementBasis?.supportsGradingComparison ?? false)
    }

    var ratios: CenteringRatios? {
        guard let insets, insets.isMeasurable else { return nil }
        return CenteringRatios(insets: insets)
    }
}

nonisolated enum AssessmentVerdict: Equatable, Sendable {
    case centeringRecorded
    case inconclusive

    var title: String {
        switch self {
        case .centeringRecorded: "Centering recorded"
        case .inconclusive: "Inconclusive"
        }
    }

    static func decide(front: SideFinding, back: SideFinding) -> AssessmentVerdict {
        if front.passedQuality, front.hasGradingComparableCentering {
            return .centeringRecorded
        }
        _ = back
        return .inconclusive
    }

    static let notAssessed = [
        "Corners, edges, and surface wear",
        "Scratches, creases, and print defects",
        "Alterations and whether the card is authentic",
        "What the card is worth, and whether a grading fee would pay for itself",
    ]

    static let gradeDisclaimer = "This is not a professional grade. PreSlab does not estimate a grade, a grade range, or a confidence percentage."
}
