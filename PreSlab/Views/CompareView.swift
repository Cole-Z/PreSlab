import SwiftUI

struct CompareView: View {
    var first: AssessmentRecord
    var second: AssessmentRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Compare centering")
                    .font(.title2.bold())
                Text("Closer to 50/50 only describes the borders in each photo. It is not a grade, and it does not say which card is worth more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    column(first)
                    column(second)
                }
                Text(AssessmentVerdict.gradeDisclaimer)
                    .font(.footnote.bold())
                    .accessibilityIdentifier("notAGradeLabel")
            }
            .padding()
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func column(_ record: AssessmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if record.isSample {
                Text("Sample image").font(.caption2)
            }
            if let image = ImageStore.load(record.frontFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            measurement("Front", record.frontFinding)
            measurement("Back", record.backFinding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func measurement(_ title: String, _ finding: SideFinding) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.bold())
            if let ratios = finding.ratios {
                Text("L/R \(ratios.horizontalText)").font(.subheadline.monospacedDigit())
                Text("T/B \(ratios.verticalText)").font(.subheadline.monospacedDigit())
            } else {
                Text("Not measured").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
