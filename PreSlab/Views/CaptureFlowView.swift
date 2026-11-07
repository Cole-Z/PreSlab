import SwiftData
import SwiftUI

struct CaptureFlowView: View {
    var startsWithSample: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var step: FlowStep = .prepare
    @State private var sleeveConfirmed = false
    @State private var front: SideDraft?
    @State private var back: SideDraft?
    @State private var errorMessage: String?
    @State private var isSample = false

    var body: some View {
        Group {
            switch step {
            case .prepare:
                prepare
            case .shoot(let side):
                CameraCaptureView(side: side) { image in
                    accept(image, side: side)
                }
            case .checking:
                ProgressView("Checking the photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .quality(let side):
                quality(side)
            case .centering(let side):
                centering(side)
            case .summary:
                summary
            }
        }
        .navigationTitle(isSample ? "Sample card" : "New assessment")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            if startsWithSample && front == nil {
                await loadSample()
            }
        }
    }

    private var prepare: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Photograph a Pokémon card")
                    .font(.title2.bold())
                Text("PreSlab measures centering on this iPhone. Photos stay on this iPhone until you delete the assessment. Nothing is uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Supported now: a standard 2.5 by 3.5 inch Pokémon card. Full-art and borderless cards can be photographed, and centering will be left unmeasured when no border is there. Other games are not supported yet.")
                VStack(alignment: .leading, spacing: 8) {
                    Label("Take the card out of the sleeve, top loader, and binder page.", systemImage: "rectangle.portrait")
                    Label("Use a plain background that contrasts with the card.", systemImage: "square.dashed")
                    Label("Even light, with no glare across the borders.", systemImage: "sun.max")
                    Label("Hold the phone nearly square above the card.", systemImage: "camera")
                }
                .font(.subheadline)
                Toggle("The card is unsleeved, on a contrasting background.", isOn: $sleeveConfirmed)
                    .accessibilityIdentifier("sleeveToggle")
                Button("Take photos") {
                    step = .shoot(.front)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!sleeveConfirmed)
                .accessibilityIdentifier("startCaptureButton")
                Button("Practice with a sample image") {
                    Task { await loadSample() }
                }
                .accessibilityIdentifier("practiceSampleButton")
                Text("The sample is a drawn rectangle, not a real card, and it is not a grade.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func quality(_ side: CardSide) -> some View {
        let draft = side == .front ? front : back
        let issues = draft?.finding.issues ?? []
        return VStack(alignment: .leading, spacing: 16) {
            Text("\(side.title) photo")
                .font(.title2.bold())
            if issues.isEmpty {
                Label("Photo is usable", systemImage: "checkmark.circle")
                    .font(.headline)
                    .accessibilityIdentifier("photoUsable")
                    .accessibilityLabel("Photo is usable")
                Text("The card is in frame and the edges are clear enough to try a centering measurement.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Take another photo. Measuring from this one would be a guess.")
                    .foregroundStyle(.secondary)
                ForEach(issues, id: \.self) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title).font(.headline)
                        Text(issue.explanation).font(.subheadline)
                    }
                }
            }
            Spacer()
            if issues.isEmpty {
                Button("Continue to centering") { step = .centering(side) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("continueToCenteringButton")
            } else if isSample {
                Button("Continue anyway") { step = .centering(side) }
                    .buttonStyle(.bordered)
            } else {
                Button("Take another photo") { step = .shoot(side) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("retakePhotoButton")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func centering(_ side: CardSide) -> some View {
        if side == .front, let draft = front {
            CenteringAdjustView(side: side, original: draft.rgba, finding: frontBinding, warped: frontWarpedBinding) {
                step = back == nil ? .shoot(.back) : .quality(.back)
            }
        } else if side == .back, let draft = back {
            CenteringAdjustView(side: side, original: draft.rgba, finding: backBinding, warped: backWarpedBinding) {
                step = .summary
            }
        } else {
            ProgressView()
        }
    }

    private var summary: some View {
        SummaryView(
            front: front?.finding ?? .empty,
            back: back?.finding ?? .empty,
            frontImage: front.flatMap { ImageCoding.uiImage(from: $0.rgba) },
            backImage: back.flatMap { ImageCoding.uiImage(from: $0.rgba) },
            isSample: isSample,
            saveTitle: "Save on this iPhone",
            onSave: save
        )
    }

    private var frontBinding: Binding<SideFinding> {
        Binding(get: { front?.finding ?? .empty }, set: { front?.finding = $0 })
    }

    private var backBinding: Binding<SideFinding> {
        Binding(get: { back?.finding ?? .empty }, set: { back?.finding = $0 })
    }

    private var frontWarpedBinding: Binding<RGBAImage?> {
        Binding(get: { front?.warped }, set: { front?.warped = $0 })
    }

    private var backWarpedBinding: Binding<RGBAImage?> {
        Binding(get: { back?.warped }, set: { back?.warped = $0 })
    }

    private func accept(_ image: UIImage, side: CardSide) {
        step = .checking
        guard let rgba = ImageCoding.rgba(from: image) else {
            errorMessage = "That photo could not be read. Try another one."
            step = .shoot(side)
            return
        }
        let assessment = CardGeometryEngine.assess(rgba)
        let draft = SideDraft(rgba: rgba, warped: assessment.warped, finding: assessment.finding)
        if side == .front { front = draft } else { back = draft }
        step = .quality(side)
    }

    private func loadSample() async {
        isSample = true
        step = .checking
        let frontImage = SampleCard.front
        let backImage = SampleCard.back
        let frontResult = CardGeometryEngine.assess(frontImage)
        let backResult = CardGeometryEngine.assess(backImage)
        front = SideDraft(rgba: frontImage, warped: frontResult.warped, finding: frontResult.finding)
        back = SideDraft(rgba: backImage, warped: backResult.warped, finding: backResult.finding)
        step = .quality(.front)
    }

    private func save() {
        guard let front, let back else { return }
        do {
            let id = UUID()
            let frontName = "\(id.uuidString)-front.jpg"
            let backName = "\(id.uuidString)-back.jpg"
            guard let frontUI = ImageCoding.uiImage(from: front.rgba),
                  let backUI = ImageCoding.uiImage(from: back.rgba) else {
                errorMessage = "The photos could not be encoded."
                return
            }
            try ImageStore.saveJPEG(frontUI, name: frontName)
            try ImageStore.saveJPEG(backUI, name: backName)
            let record = AssessmentRecord(
                id: id,
                frontFileName: frontName,
                backFileName: backName,
                frontJSON: try JSONEncoder().encode(front.finding),
                backJSON: try JSONEncoder().encode(back.finding),
                isSample: isSample
            )
            modelContext.insert(record)
            dismiss()
        } catch {
            errorMessage = "The assessment could not be saved on this iPhone."
        }
    }
}

private enum FlowStep: Equatable {
    case prepare
    case shoot(CardSide)
    case checking
    case quality(CardSide)
    case centering(CardSide)
    case summary
}

private struct SideDraft {
    var rgba: RGBAImage
    var warped: RGBAImage?
    var finding: SideFinding
}
