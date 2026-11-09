import SwiftUI

private func stateColor(_ s: CenteringRowState) -> Color {
    switch s {
    case .compatible: return .green
    case .outsideBaseline: return .red
    case .borderlineUncertain: return .orange
    case .missingMeasurement: return .orange
    case .qualitativeReviewRequired: return .purple
    case .insufficientPublishedInformation: return .secondary
    case .invalidMeasurement: return .red
    }
}

private struct BaselineRowView: View {
    var result: CenteringRowResult
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.state.symbol)
                .foregroundStyle(stateColor(result.state))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.row.gradeLabel).font(.subheadline.bold())
                    Spacer()
                    Text(result.state.title).font(.caption).foregroundStyle(stateColor(result.state))
                }
                Text(result.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct CenteringBaselinesView: View {
    var front: SideFinding
    var back: SideFinding
    @State private var grader: GraderProfile = .psa
    @State private var category: CardCategory = .tcg
    @State private var showAll = false

    private var comparison: CenteringComparison {
        CenteringComparisonEngine.evaluate(grader: grader, category: category, frontFinding: front, backFinding: back)
    }

    var body: some View {
        let comp = comparison
        VStack(alignment: .leading, spacing: 12) {
            header
            graderPicker
            if grader == .cgc || grader == .tag { categoryPicker }
            Text(comp.summaryText)
                .font(.subheadline.bold())
                .accessibilityIdentifier("baselineSummary")
            Text(measuredLine(comp))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("baselineMeasured")
            if let highest = comp.highestCompatible {
                highestBanner(highest)
            } else if let blocker = comp.blockerSummary {
                Text(blocker)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("baselineBlocker")
            }
            if !comp.unresolvedHigherRows.isEmpty {
                unresolvedList(comp)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("All graders at a glance").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(GraderProfile.allCases) { g in
                    BaselineCompactLine(grader: g, category: category, front: front, back: back)
                }
            }
            DisclosureGroup("All \(grader.title) grades", isExpanded: $showAll) {
                VStack(spacing: 0) {
                    ForEach(comp.rows) { r in
                        BaselineRowView(result: r)
                        Divider()
                    }
                }
            }
            .font(.subheadline)
            footer
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("centeringBaselines")
    }

    private var header: some View {
        HStack {
            Label("Published centering baselines", systemImage: "ruler").font(.headline)
            Spacer()
            Text("v\(CenteringStandards.version)").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var graderPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CenteringStandards.resultLabel).font(.caption).foregroundStyle(.secondary)
            Picker("Grader", selection: $grader) {
                ForEach(GraderProfile.allCases) { g in Text(g.title).tag(g) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("graderPicker")
        }
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            Text("TCG").tag(CardCategory.tcg)
            Text("Sports").tag(CardCategory.sports)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("categoryPicker")
    }

    private func highestBanner(_ highest: CenteringRowResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(grader.title) \(highest.row.gradeLabel)").font(.title3.bold())
                Text(highest.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func measuredLine(_ comp: CenteringComparison) -> String {
        let f = comp.front.map { "front worst \(CenteringComparisonEngine.format($0.worst))" } ?? "front not measured"
        let b = comp.back.map { "back worst \(CenteringComparisonEngine.format($0.worst))" } ?? "back not measured"
        return "Measured: \(f) · \(b)."
    }

    private func unresolvedList(_ comp: CenteringComparison) -> some View {
        let rows = comp.unresolvedHigherRows
        let qualitative = rows.filter { $0.state == .qualitativeReviewRequired }
        let others = rows.filter { $0.state != .qualitativeReviewRequired }
        return VStack(alignment: .leading, spacing: 4) {
            Label("Not ruled out — insufficient published info above", systemImage: "questionmark.circle")
                .font(.caption.bold()).foregroundStyle(.orange)
            ForEach(others) { r in
                Text("• \(grader.title) \(r.row.gradeLabel): \(r.state.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if qualitative.count > 1, let first = qualitative.first, let last = qualitative.last {
                Text("• \(grader.title) \(first.row.gradeLabel) through \(last.row.gradeLabel): Qualitative review required (\(qualitative.count) grades; a ratio alone cannot settle these)")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let only = qualitative.first {
                Text("• \(grader.title) \(only.row.gradeLabel): \(only.state.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Link("Official \(grader.title) standards · checked \(CenteringStandards.checkedDate)", destination: grader.sourceURL)
                .font(.caption)
            Text(CenteringStandards.disclaimer).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct BaselineCompactLine: View {
    var grader: GraderProfile
    var category: CardCategory
    var front: SideFinding
    var back: SideFinding
    var body: some View {
        let c = CenteringComparisonEngine.evaluate(grader: grader, category: category, frontFinding: front, backFinding: back)
        if let h = c.highestCompatible {
            Label("\(grader.title) \(h.row.gradeLabel) baseline fits", systemImage: "checkmark.circle.fill")
                .font(.caption.bold()).foregroundStyle(.green)
                .accessibilityIdentifier("baselineCompact")
        } else {
            Label("No \(grader.title) baseline confirmed", systemImage: "minus.circle")
                .font(.caption.bold()).foregroundStyle(.secondary)
                .accessibilityIdentifier("baselineCompact")
        }
    }
}
