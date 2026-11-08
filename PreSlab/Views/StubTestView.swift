import SwiftUI
import SwiftData

/// Developer-only surface for poking the observation harness.
/// Runs the real crop pipeline on the sample card or a saved assessment and
/// answers it with the canned stub or the live pilot server.
/// Never a grade.
struct StubTestView: View {
    enum Source: String, CaseIterable {
        case stub = "Stub"
        case live = "Live pilot"
    }

    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var records: [AssessmentRecord]
    @State private var useSample = true
    @State private var selectedID: UUID?
    @State private var source: Source = .stub
    @State private var serverURL = "http://192.168.1.73:8080"
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
                    Picker("Assessment", selection: $selectedID) {
                        Text("Pick one").tag(nil as UUID?)
                        ForEach(records) { record in
                            Text("\(record.createdAt.formatted(date: .abbreviated, time: .shortened)) — \(AssessmentVerdict.decide(front: record.frontFinding, back: record.backFinding).title)").tag(record.id as UUID?)
                        }
                    }
                    .accessibilityIdentifier("observerAssessmentPicker")
                }
            }
            Section {
                Picker("Source", selection: $source) {
                    ForEach(Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("observerSourcePicker")
                if source == .live {
                    TextField("Server URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("observerServerURL")
                    Text("Live calls your Mac's pilot server, which holds your key. Billed to you, a few cents per run.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Stub — no model looked at anything below. No network, no key, no spend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
        guard let warped = warpedCard() else {
            errorMessage = useSample
                ? "The sample card could not be flattened."
                : "Pick a saved assessment with a usable front photo first."
            ran = true
            return
        }
        let built = ObservationCropBuilder.build(from: warped)
        crops = built
        switch source {
        case .stub:
            observations = (try? await StubConditionObserver().observe(crops: built)) ?? []
            ran = true
        case .live:
            guard let base = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                errorMessage = "That server URL does not parse."
                ran = true
                return
            }
            do {
                observations = try await LiveConditionObserver(baseURL: base).observe(crops: built)
            } catch {
                observations = []
                errorMessage = "Live call failed: \(error.localizedDescription). Is the pilot server running on your Mac?"
            }
            ran = true
        }
    }

    /// Flattens the sample card, or re-flattens a saved assessment's front
    /// photo from its stored card position so crops land on the card.
    private func warpedCard() -> RGBAImage? {
        if useSample {
            return CardGeometryEngine.assess(SampleCard.front).warped
        }
        guard let id = selectedID,
              let record = records.first(where: { $0.id == id }),
              let photo = ImageStore.load(record.frontFileName),
              let rgba = ImageCoding.rgba(from: photo)
        else { return nil }
        let finding = record.frontFinding
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
