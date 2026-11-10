import SwiftUI
import UIKit

struct SummaryView: View {
    var front: SideFinding
    var back: SideFinding
    var frontImage: UIImage?
    var backImage: UIImage?
    var isSample: Bool
    var saveTitle: String?
    var onSave: (() -> Void)?
    var onDelete: (() -> Void)?
    var createdAt: Date = .now
    var cardName: String?
    var conditionChecklist: ConditionChecklist = .empty
    var gradingOutcome: ProfessionalGradingOutcome?
    var gradingCostInputs: GradingCostInputs? = nil
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private var verdict: AssessmentVerdict { .decide(front: front, back: back) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isSample {
                    Text("Sample image. This is a drawn rectangle, not a real card.")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
                Text(verdict.title).font(.title.bold()).accessibilityIdentifier("verdictTitle")
                Text(verdictDetail)
                    .font(.body)
                Text(AssessmentVerdict.gradeDisclaimer)
                    .font(.subheadline.bold())
                    .accessibilityIdentifier("notAGradeLabel")

                sideSection("Front", finding: front, image: frontImage)
                sideSection("Back", finding: back, image: backImage)

                CenteringBaselinesView(front: front, back: back)

                if hasConditionObservations {
                    conditionSection
                }

                if let gradingOutcome {
                    outcomeSection(gradingOutcome)
                }

                if let gradingCostInputs {
                    economicsSection(gradingCostInputs)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Not automatically assessed").font(.headline)
                    ForEach(AssessmentVerdict.notAssessed, id: \.self) { item in
                        Text("• \(item)")
                    }
                    .font(.subheadline)
                }

                if let onSave, let saveTitle {
                    Button(saveTitle, action: onSave)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("saveAssessmentButton")
                }
                if let onDelete {
                    Button("Delete assessment", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("deleteAssessmentButton")
                }
                Button {
                    prepareShare()
                } label: {
                    Label("Share assessment", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("shareAssessmentButton")
                .sheet(isPresented: $showShare) {
                    ActivitySheet(items: shareItems)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verdictDetail: String {
        switch verdict {
        case .centeringRecorded:
            var text = "The ratios are border measurements from these photos. A professional grader can still disagree. A well-centered card can still be a poor card to submit once its price and the grading fee are known. PreSlab does not estimate that."
            if !back.hasMeasurableCentering {
                text += " The back was not measured. That is left blank on purpose."
            }
            return text
        case .inconclusive:
            if front.measurementBasis == .userDefinedVisualReference, front.ratios != nil {
                return "A visual reference was recorded for this design, but it is not treated as verified centering and is excluded from grading-company comparisons."
            }
            return "These photos do not support a centering measurement on the front. You can keep them and try another shot. Nothing here fills in a grade."
        }
    }

    private func prepareShare() {
        let title = cardName ?? "PreSlab assessment"
        do {
            shareItems = [try AssessmentPDFExporter.writePDF(
                cardName: title,
                createdAt: createdAt,
                front: front,
                back: back,
                frontImage: frontImage,
                backImage: backImage,
                checklist: conditionChecklist,
                outcome: gradingOutcome,
                costs: gradingCostInputs
            )]
        } catch {
            var fallback: [Any] = [AssessmentShareText.make(front: front, back: back, createdAt: createdAt)]
            if let frontImage { fallback.append(frontImage) }
            if let backImage { fallback.append(backImage) }
            shareItems = fallback
        }
        showShare = true
    }

    private var hasConditionObservations: Bool {
        CardSide.allCases.contains { !conditionChecklist.recordedObservations(side: $0).isEmpty }
    }

    private var conditionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your condition observations").font(.headline)
            Text("Collector-entered notes only — not an automated or professional grade.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(CardSide.allCases, id: \.self) { side in
                if !conditionChecklist.recordedObservations(side: side).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(side.title).font(.subheadline.bold())
                        ForEach(ConditionItem.allCases) { item in
                            let state = conditionChecklist.state(for: item, side: side)
                            if state != .notInspected {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(item.category.title): \(item.title)")
                                    Spacer()
                                    Text(state.title)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func outcomeSection(_ outcome: ProfessionalGradingOutcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Actual professional outcome").font(.headline)
            HStack {
                Text(outcome.company.isEmpty ? "Grading company" : outcome.company)
                Spacer()
                Text(outcome.gradeReceived.isEmpty ? "Grade not entered" : outcome.gradeReceived)
                    .font(.title3.bold().monospacedDigit())
            }
            Text("Submitted \(outcome.submissionDate.formatted(date: .abbreviated, time: .omitted)) · Returned \(outcome.returnDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !outcome.notes.isEmpty {
                Text(outcome.notes).font(.subheadline)
            }
            Divider()
            Text("Original PreSlab measurements").font(.subheadline.bold())
            Text("Front: \(measurementSummary(front))")
                .font(.caption.monospacedDigit())
            Text("Back: \(measurementSummary(back))")
                .font(.caption.monospacedDigit())
            Text("This is a historical comparison only. A returned grade reflects factors beyond centering and does not prove PreSlab predicted it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func economicsSection(_ inputs: GradingCostInputs) -> some View {
        let currency = Locale.current.currency?.identifier ?? "USD"
        return VStack(alignment: .leading, spacing: 6) {
            Text("Saved grading economics").font(.headline)
            economicsRow("Submission-only costs", inputs.submissionCosts, currency: currency)
            economicsRow("Total economic basis", inputs.totalInvestment, currency: currency)
            economicsRow("Break-even resale value", inputs.breakEvenResaleValue, currency: currency)
            economicsRow("Potential profit / loss", inputs.potentialProfitOrLoss, currency: currency)
            Text("Based only on collector-entered values; no grade or price is guaranteed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func economicsRow(_ title: String, _ value: Double?, currency: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Text(value, format: .currency(code: currency)).monospacedDigit()
            } else {
                Text("Unavailable").foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private func measurementSummary(_ finding: SideFinding) -> String {
        guard let ratios = finding.ratios else { return "not measured" }
        let source = finding.measurementBasis?.title ?? "legacy measurement"
        return "L/R \(ratios.horizontalText), T/B \(ratios.verticalText) · \(source)"
    }

    private func sideSection(_ title: String, finding: SideFinding, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("\(title) card photo")
            }
            if let ratios = finding.ratios {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Left / right").font(.caption).foregroundStyle(.secondary)
                        Text(ratios.horizontalText).font(.title3.bold().monospacedDigit())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Top / bottom").font(.caption).foregroundStyle(.secondary)
                        Text(ratios.verticalText).font(.title3.bold().monospacedDigit())
                    }
                }
                if finding.adjustedByUser {
                    Text("Borders were adjusted by you.").font(.footnote).foregroundStyle(.secondary)
                }
                if let basis = finding.measurementBasis {
                    Label(basis.title, systemImage: basis.supportsGradingComparison ? "viewfinder" : "eye")
                        .font(.footnote)
                        .foregroundStyle(basis.supportsGradingComparison ? Color.secondary : Color.orange)
                }
                if finding.measurementBasis == .userDefinedVisualReference {
                    Text("Documentation only — excluded from grading-company comparisons.")
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                }
            } else {
                if finding.limitation == .noStablePrintedFrame {
                    Label("Unsupported design or reference", systemImage: "rectangle.slash")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                Text(finding.unsupportedReason ?? "Centering was not measured.")
                    .foregroundStyle(.secondary)
            }
            if !finding.issues.isEmpty {
                Text("Photo notes: \(finding.issues.map(\.title).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
