import Foundation

nonisolated enum CardSide: String, Codable, CaseIterable, Sendable {
    case front
    case back

    var title: String { self == .front ? "Front" : "Back" }
}

nonisolated struct SideFinding: Codable, Equatable, Sendable {
    var issues: [PhotoIssue]
    var quad: CardQuad?
    var insets: BorderInsets?
    var adjustedByUser: Bool
    var unsupportedReason: String?

    static let empty = SideFinding(issues: [], quad: nil, insets: nil, adjustedByUser: false, unsupportedReason: nil)

    var passedQuality: Bool { issues.isEmpty }

    var hasMeasurableCentering: Bool { insets?.isMeasurable ?? false }

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
        if front.passedQuality, front.hasMeasurableCentering {
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
