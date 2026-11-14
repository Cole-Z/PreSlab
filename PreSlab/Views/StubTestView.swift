import SwiftUI
import SwiftData

/// Developer-only surface for poking the observation harness.
/// Runs the real crop pipeline on the sample card or a saved assessment and
/// answers it with a canned local stub.
/// Never a grade.
struct StubTestView: View {
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var records: [AssessmentRecord]
    @State private var useSample = true
    @State private var selectedID: UUID?
    @State private var crops: [ObservationCrop] = []
    @State private var observations: [ConditionObservation] = []
    @State private var errorMessage: String?
    @State private var ran = false

    var body: some View {
        List {
            Section("Photo") {
                Picker("Photo", selection: $useSample) {
                    Text("Sample card").tag(true)
                    Text("Saved assessment").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("observerPhotoPicker")
                if !useSample {
                    Text("Each assessment is a whole card. One run covers its front and its back.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(records) { record in
                        Button {
                            selectedID = record.id
                        } label: {
                            HStack(spacing: 12) {
                                if let thumb = ImageStore.load(record.frontFileName) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    Text("Front + back • \(AssessmentVerdict.decide(front: record.frontFinding, back: record.backFinding).title)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedID == record.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityIdentifier("observerAssessmentRow")
                    }
                }
            }
            Section {
                Text("Stub — no model looked at anything below. No network, no key, no spend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Run observations") { Task { await run() } }
                    .accessibilityIdentifier("runObservationsButton")
                if !ran {
                    ProgressView("Building crops…")
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text("\(crops.count) crops, \(observations.count) observations.")
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
        .navigationTitle("AI observer test")
        .navigationBarTitleDisplayMode(.inline)
        .task { await run() }
    }

    private func run() async {
        ran = false
        errorMessage = nil
        let warped = warpedCards()
        guard !warped.isEmpty else {
            errorMessage = useSample
                ? "The sample card could not be flattened."
                : "Pick a saved assessment with usable photos first."
            ran = true
            return
        }
        let built = warped.flatMap { side, image in
            ObservationCropBuilder.buildRegions(from: image, prefix: "\(side)-")
        }
        crops = built
        observations = (try? await StubConditionObserver().observe(crops: built)) ?? []
        ran = true
    }

    /// Flattens front and back: the sample card, or a saved assessment's
    /// photos re-flattened from their stored card positions.
    private func warpedCards() -> [(String, RGBAImage)] {
        if useSample {
            return [
                ("front", CardGeometryEngine.assess(SampleCard.front).warped),
                ("back", CardGeometryEngine.assess(SampleCard.back).warped),
            ].compactMap { side, image in image.map { (side, $0) } }
        }
        guard let id = selectedID,
              let record = records.first(where: { $0.id == id })
        else { return [] }
        return [
            ("front", flatten(photoName: record.frontFileName, finding: record.frontFinding)),
            ("back", flatten(photoName: record.backFileName, finding: record.backFinding)),
        ].compactMap { side, image in image.map { (side, $0) } }
    }

    private func flatten(photoName: String, finding: SideFinding) -> RGBAImage? {
        guard let photo = ImageStore.load(photoName),
              let rgba = ImageCoding.rgba(from: photo)
        else { return nil }
        if let quad = finding.quad {
            return CardGeometryEngine.assess(
                image: rgba,
                quad: quad,
                presetInsets: finding.insets,
                adjustedByUser: finding.adjustedByUser
            ).warped
        }
        return CardGeometryEngine.assess(rgba).warped
    }
}
