import SwiftUI

/// Developer-only surface for poking the observation harness.
/// Runs the real crop pipeline on the sample card and answers it with the
/// canned stub. No network, no model, no key. Never a grade.
struct StubTestView: View {
    @State private var crops: [ObservationCrop] = []
    @State private var observations: [ConditionObservation] = []
    @State private var ran = false

    var body: some View {
        List {
            Section {
                Text("Stub — no model looked at anything below. No network, no key, no spend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !ran {
                    ProgressView("Building crops…")
                } else {
                    Text("\(crops.count) crops, \(observations.count) stub observations.")
                        .font(.subheadline)
                }
            }
            ForEach(observations.indices, id: \.self) { index in
                let observation = observations[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.region).font(.headline)
                    Text(observation.statement).font(.subheadline)
                    Text("Limitation: \(observation.limitation)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("AI stub test")
        .navigationBarTitleDisplayMode(.inline)
        .task { await run() }
    }

    private func run() async {
        let assessment = CardGeometryEngine.assess(SampleCard.front)
        guard let warped = assessment.warped else {
            ran = true
            return
        }
        let built = ObservationCropBuilder.build(from: warped)
        crops = built
        observations = (try? await StubConditionObserver().observe(crops: built)) ?? []
        ran = true
    }
}
