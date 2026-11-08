import Foundation

/// Shareable text for an assessment. Pure function so it can be unit-tested.
/// Never contains a grade, a grade range, a value claim, or a confidence
/// percentage.
nonisolated enum AssessmentShareText {
    static func make(front: SideFinding, back: SideFinding, createdAt: Date) -> String {
        var lines = ["PreSlab assessment"]
        lines.append(AssessmentVerdict.decide(front: front, back: back).title)
        lines.append(sideBlock("Front", finding: front))
        lines.append(sideBlock("Back", finding: back))
        lines.append("Recorded \(dateFormatter.string(from: createdAt))")
        lines.append(AssessmentVerdict.gradeDisclaimer)
        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func sideBlock(_ title: String, finding: SideFinding) -> String {
        if let ratios = finding.ratios {
            var block = "\(title): left/right \(ratios.horizontalText), top/bottom \(ratios.verticalText)"
            if finding.adjustedByUser {
                block += " (borders adjusted by hand)"
            }
            return block
        }
        return "\(title): not measured (\(finding.unsupportedReason ?? "no reason recorded"))"
    }
}
