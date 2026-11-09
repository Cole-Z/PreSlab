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
    @State private var showShare = false

    private var shareItems: [Any] {
        var items: [Any] = [AssessmentShareText.make(front: front, back: back, createdAt: createdAt)]
        if let frontImage { items.append(frontImage) }
        if let backImage { items.append(backImage) }
        return items
    }

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Not assessed").font(.headline)
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
                    showShare = true
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
            return "These photos do not support a centering measurement on the front. You can keep them and try another shot. Nothing here fills in a grade."
        }
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
            } else {
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
