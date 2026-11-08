import SwiftUI

/// Developer-only surface for poking the observation harness.
/// Runs the real crop pipeline on the sample card and answers it with the
/// canned stub. No network, no model, no key. Never a grade.
struct StubTestView: View {
    enum Source: String, CaseIterable {
        case stub = "Stub"
        case live = "Live pilot"
    }

    @State private var source: Source = .stub
    @State private var serverURL = "http://192.168.1.73:8080"
    @State private var crops: [ObservationCrop] = []
    @State private var observations: [ConditionObservation] = []
    @State private var errorMessage: String?
    @State private var ran = false

    var body: some View {
        List {
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
        let assessment = CardGeometryEngine.assess(SampleCard.front)
        guard let warped = assessment.warped else {
            errorMessage = "The sample card could not be flattened."
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
}
