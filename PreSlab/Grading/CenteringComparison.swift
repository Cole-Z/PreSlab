import Foundation

nonisolated enum CenteringRowState: String, Equatable, Sendable {
    case compatible
    case outsideBaseline
    case borderlineUncertain
    case insufficientPublishedInformation
    case missingMeasurement
    case qualitativeReviewRequired
    case invalidMeasurement

    var title: String {
        switch self {
        case .compatible: "Baseline-compatible"
        case .outsideBaseline: "Outside baseline"
        case .borderlineUncertain: "Borderline / uncertain"
        case .insufficientPublishedInformation: "Insufficient published information"
        case .missingMeasurement: "Missing measurement"
        case .qualitativeReviewRequired: "Qualitative review required"
        case .invalidMeasurement: "Invalid measurement"
        }
    }
    var symbol: String {
        switch self {
        case .compatible: "checkmark.circle.fill"
        case .outsideBaseline: "xmark.circle.fill"
        case .borderlineUncertain: "questionmark.circle.fill"
        case .insufficientPublishedInformation: "minus.circle"
        case .missingMeasurement: "exclamationmark.circle"
        case .qualitativeReviewRequired: "eye"
        case .invalidMeasurement: "exclamationmark.triangle.fill"
        }
    }
}

/// Imbalance percentages (50...100) per face. Worst axis is what matters.
nonisolated struct FaceImbalance: Equatable, Sendable {
    var horizontal: Double
    var vertical: Double
    var worst: Double { max(horizontal, vertical) }
    var isValid: Bool {
        [horizontal, vertical].allSatisfy { $0.isFinite && $0 >= 50 - 1e-9 && $0 <= 100 + 1e-9 }
    }
    init(horizontal: Double, vertical: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    /// §7.3: max(a,b)/(a+b)*100. Returns nil for invalid geometry.
    static func imbalance(a: Double, b: Double) -> Double? {
        guard a.isFinite, b.isFinite, a >= 0, b >= 0, a + b > 0 else { return nil }
        return max(a, b) / (a + b) * 100
    }
    init?(insets: BorderInsets) {
        guard let h = Self.imbalance(a: insets.left, b: insets.right),
              let v = Self.imbalance(a: insets.top, b: insets.bottom) else { return nil }
        self.init(horizontal: h, vertical: v)
    }
    /// Build from a measured ratio split like 58/42 (direction does not matter).
    init(split: (Double, Double), vertical: (Double, Double)) {
        self.init(horizontal: max(split.0, split.1), vertical: max(vertical.0, vertical.1))
    }
}

nonisolated struct CenteringRowResult: Identifiable, Equatable, Sendable {
    var row: CenteringStandardRow
    var state: CenteringRowState
    var detail: String
    var id: String { row.id }
}

nonisolated struct CenteringComparison: Equatable, Sendable {
    var grader: GraderProfile
    var category: CardCategory
    var rows: [CenteringRowResult]
    var front: FaceImbalance?
    var back: FaceImbalance?

    var highestCompatible: CenteringRowResult? {
        rows.first { $0.state == .compatible }
    }
    /// Higher rows that were not ruled out — never collapse into a ceiling claim.
    var unresolvedHigherRows: [CenteringRowResult] {
        guard let highest = highestCompatible else {
            return rows.filter { ![.outsideBaseline, .compatible].contains($0.state) }
        }
        guard let idx = rows.firstIndex(where: { $0.id == highest.id }) else { return [] }
        return Array(rows[..<idx]).filter { $0.state != .outsideBaseline }
    }
    /// One specific reason no baseline can be confirmed, when that is the case.
    var blockerSummary: String? {
        guard highestCompatible == nil else { return nil }
        if front == nil && back == nil { return "Neither face was measured, so no \(grader.title) baseline can be checked." }
        if back == nil, front != nil { return "The back was not measured, so no full \(grader.title) baseline can be confirmed. A missing back is not 50/50." }
        if front == nil { return "The front was not measured, so no \(grader.title) baseline can be checked." }
        if let firstOutside = rows.first(where: { $0.state == .outsideBaseline }) {
            return "The closest assessable row, \(grader.title) \(firstOutside.row.gradeLabel), is outside its published limit (\(firstOutside.detail))"
        }
        if rows.contains(where: { $0.state == .qualitativeReviewRequired }) {
            return "The remaining \(grader.title) rows need a qualitative check (such as a border sliver) that a centering ratio alone cannot settle."
        }
        return "No published \(grader.title) numerical baseline is available to confirm from these measurements."
    }

    var summaryText: String {
        if let highest = highestCompatible {
            return "Centering fits \(grader.title) \(highest.row.gradeLabel) published baseline; this is not an overall grade prediction."
        }
        if rows.contains(where: { $0.state == .outsideBaseline }) && rows.allSatisfy({ $0.state == .outsideBaseline || $0.state == .insufficientPublishedInformation || $0.state == .qualitativeReviewRequired || $0.state == .missingMeasurement }) {
            // At least the assessable rows were outside; still not a grade claim.
            if let firstOutside = rows.first(where: { $0.state == .outsideBaseline }) {
                _ = firstOutside
            }
            return "No fully assessable published \(grader.title) baseline is met by these measurements. This is not an overall grade prediction."
        }
        return "No \(grader.title) baseline can be confirmed from these measurements yet. This is not an overall grade prediction."
    }
}

nonisolated enum CenteringComparisonEngine {
    /// uncertainty is in percentage points (e.g. 1.0). No allowance is invented when nil.
    static func evaluate(grader: GraderProfile, category: CardCategory,
                         front: FaceImbalance?, back: FaceImbalance?,
                         uncertainty: Double? = nil) -> CenteringComparison {
        let rows = CenteringStandards.rows(grader: grader, category: category)
        let results = rows.map { evaluateRow($0, front: front, back: back, uncertainty: uncertainty, grader: grader) }
        return CenteringComparison(grader: grader, category: category, rows: results, front: front, back: back)
    }

    static func evaluate(grader: GraderProfile, category: CardCategory,
                         frontFinding: SideFinding, backFinding: SideFinding,
                         uncertainty: Double? = nil) -> CenteringComparison {
        if frontFinding.measurementBasis?.supportsGradingComparison == true,
           let insets = frontFinding.insets, !insets.isValidPlacement {
            return invalidComparison(grader: grader, category: category, detail: "Invalid front geometry.")
        }
        if backFinding.measurementBasis?.supportsGradingComparison == true,
           let insets = backFinding.insets, !insets.isValidPlacement {
            return invalidComparison(grader: grader, category: category, detail: "Invalid back geometry.")
        }
        // Insets that are not measurable (both sides of an axis on the card
        // edge) count as missing everywhere, never as a 50/50 measurement.
        let f = frontFinding.hasGradingComparableCentering
            ? frontFinding.insets.flatMap { FaceImbalance(insets: $0) }
            : nil
        let b = backFinding.hasGradingComparableCentering
            ? backFinding.insets.flatMap { FaceImbalance(insets: $0) }
            : nil
        // Preserve invalid geometry: measurable insets that still produce
        // nil (negative or non-finite widths) surface invalid via sentinel.
        if frontFinding.hasGradingComparableCentering,
           let insets = frontFinding.insets, insets.isMeasurable, f == nil {
            return CenteringComparison(grader: grader, category: category,
                rows: CenteringStandards.rows(grader: grader, category: category).map {
                    CenteringRowResult(row: $0, state: .invalidMeasurement, detail: "Invalid geometry: negative width or zero sum of opposite borders.")
                }, front: nil, back: b)
        }
        return evaluate(grader: grader, category: category, front: f, back: b, uncertainty: uncertainty)
    }

    private static func invalidComparison(grader: GraderProfile, category: CardCategory, detail: String) -> CenteringComparison {
        CenteringComparison(
            grader: grader,
            category: category,
            rows: CenteringStandards.rows(grader: grader, category: category).map {
                CenteringRowResult(row: $0, state: .invalidMeasurement, detail: detail)
            },
            front: nil,
            back: nil
        )
    }

    private static func crosses(_ worst: Double, _ limit: Double, _ u: Double?) -> Bool {
        guard let u, u > 0 else { return false }
        return (worst <= limit && worst + u > limit) || (worst > limit && worst - u <= limit)
    }

    private static func evaluateRow(_ row: CenteringStandardRow, front: FaceImbalance?, back: FaceImbalance?,
                                    uncertainty: Double?, grader: GraderProfile) -> CenteringRowResult {
        func result(_ s: CenteringRowState, _ d: String) -> CenteringRowResult {
            var detail = d
            if let note = row.note { detail += (detail.isEmpty ? "" : " ") + note }
            if grader == .psa, row.gradeValue >= 7, row.front.numericLimit != nil {
                detail += " PSA notes a discretionary 5% front leeway for PSA 7 or better with eye appeal — not auto-applied."
            }
            if grader == .tag, let band = row.scoreBand {
                _ = band // already in note
            }
            return CenteringRowResult(row: row, state: s, detail: detail)
        }
        // Invalid geometry
        if let f = front, !f.isValid { return result(.invalidMeasurement, "Invalid front measurement.") }
        if let b = back, !b.isValid { return result(.invalidMeasurement, "Invalid back measurement.") }

        // Shared-scope rows (CGC): preserve literal, do not invent faces.
        if row.sharedScopeUnresolved, let shared = row.sharedLimit {
            if front == nil && back == nil { return result(.missingMeasurement, "No measurement to compare against \(format(shared)) statement.") }
            // Even if numeric value would fit, scope is unresolved.
            return result(.insufficientPublishedInformation, "Published \(format(shared)) statement with unresolved face scope.")
        }
        // Qualitative-only rows
        let frontPublished = row.front.isPublished
        let backPublished = row.back.isPublished
        if !frontPublished && !backPublished {
            // TAG grade 1: both sliver
            if row.front.isSliver || row.back.isSliver {
                return result(.qualitativeReviewRequired, "SLIVER is qualitative (tiny sliver of border, not miscut, no other card shown) — a ratio alone cannot establish it.")
            }
            let qualitative = [row.front.qualitativeText, row.back.qualitativeText].compactMap { $0 }
            if !qualitative.isEmpty {
                let unique = qualitative.reduce(into: [String]()) { values, value in
                    if !values.contains(value) { values.append(value) }
                }
                return result(.qualitativeReviewRequired, "Published qualitative criterion: \(unique.joined(separator: "; ")). A ratio alone cannot establish it.")
            }
            return result(.insufficientPublishedInformation, "No numerical ratio published for this grade (NP). Not an automatic pass or failure.")
        }
        // Front check
        if frontPublished {
            guard let front else { return result(.missingMeasurement, "Front measurement missing.") }
            if row.front.isSliver {
                return result(.qualitativeReviewRequired, "Front SLIVER requires qualitative review (sliver / miscut / other-card check).")
            }
            if let limit = row.front.numericLimit {
                if crosses(front.worst, limit, uncertainty) {
                    return result(.borderlineUncertain, "Front worst axis \(format(front.worst)) is within measurement uncertainty of \(format(limit)) limit.")
                }
                if front.worst > limit {
                    return result(.outsideBaseline, "Front worst axis \(format(front.worst)) exceeds \(format(limit)) limit.")
                }
            }
        }
        // Back check (only after front passes, so one bad axis/face cannot be averaged away)
        if backPublished {
            if row.back.isSliver {
                return result(.qualitativeReviewRequired, "Front fits numerically. Back is SLIVER — qualitative review required (tiny sliver, not miscut, no other card). A ratio alone cannot establish SLIVER.")
            }
            guard let back else {
                return result(.missingMeasurement, "Front fits, but back measurement is missing. A missing back photo is not 50/50 and cannot establish a full front/back match.")
            }
            if let limit = row.back.numericLimit {
                if crosses(back.worst, limit, uncertainty) {
                    return result(.borderlineUncertain, "Back worst axis \(format(back.worst)) is within measurement uncertainty of \(format(limit)) limit.")
                }
                if back.worst > limit {
                    return result(.outsideBaseline, "Back worst axis \(format(back.worst)) exceeds \(format(limit)) limit.")
                }
            }
        }
        // Front published & passed, back not published: partial but front baseline is assessable.
        // For rows where back is NP but front exists, we can call compatible on published front rule
        // only if grader actually published a front-only rule. CGC shared rows already handled.
        // PSA/BGS/TAG all publish both, so this path is rare.
        var detail = "Front \(front.map { format($0.worst) } ?? "—") and back \(back.map { format($0.worst) } ?? "—") fit published limits."
        if row.front.numericLimit != nil || row.back.numericLimit != nil {
            let approx = [row.front, row.back].contains { if case .numeric(_, let a) = $0 { return a }; return false }
            if approx { detail += " Limits are published as approximate (~); grader discretion may apply." }
        }
        return result(.compatible, detail)
    }

    static func format(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        if rounded == rounded.rounded() { return "\(Int(rounded))/\(100 - Int(rounded))" }
        return String(format: "%.1f/%.1f", rounded, 100 - rounded)
    }
}
