import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var records: [AssessmentRecord]

    @State private var path = NavigationPath()
    @State private var comparing = false
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if records.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("PreSlab")
            .toolbar { toolbar }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .capture(let sample):
                    CaptureFlowView(startsWithSample: sample)
                case .detail(let id):
                    if let record = records.first(where: { $0.id == id }) {
                        detail(record)
                    }
                case .compare(let first, let second):
                    if let a = records.first(where: { $0.id == first }),
                       let b = records.first(where: { $0.id == second }) {
                        CompareView(first: a, second: b)
                    }
                }
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No assessments yet", systemImage: "rectangle.portrait.on.rectangle.portrait")
        } description: {
            Text("Photograph a standard-size Pokémon card to measure centering. This is not a grade.")
        } actions: {
            Button("Photograph a card") { path.append(Route.capture(sample: false)) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("newAssessmentButton")
            Button("Practice with a sample image") { path.append(Route.capture(sample: true)) }
                .accessibilityIdentifier("practiceSampleButton")
        }
    }

    private var list: some View {
        List {
            ForEach(records) { record in
                Button {
                    if comparing {
                        toggle(record.id)
                    } else {
                        path.append(Route.detail(record.id))
                    }
                } label: {
                    row(record)
                }
                .accessibilityIdentifier("assessmentRow")
                .swipeActions {
                    Button("Delete", role: .destructive) { delete(record) }
                }
            }
        }
    }

    private func row(_ record: AssessmentRecord) -> some View {
        HStack(spacing: 12) {
            if comparing {
                Image(systemName: selected.contains(record.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(record.id) ? Color.accentColor : Color.secondary)
            }
            if let image = ImageStore.load(record.frontFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                Text(AssessmentVerdict.decide(front: record.frontFinding, back: record.backFinding).title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if record.isSample {
                    Text("Sample image").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !records.isEmpty {
                Button(comparing ? "Done" : "Compare") {
                    comparing.toggle()
                    selected.removeAll()
                }
                .accessibilityIdentifier("compareToggle")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if comparing {
                Button("Compare two") {
                    let ids = Array(selected)
                    guard ids.count == 2 else { return }
                    path.append(Route.compare(ids[0], ids[1]))
                    comparing = false
                    selected.removeAll()
                }
                .disabled(selected.count != 2)
                .accessibilityIdentifier("compareSelectedButton")
            } else if !records.isEmpty {
                Button("Sample") { path.append(Route.capture(sample: true)) }
                    .accessibilityIdentifier("practiceSampleButton")
                Button("New") { path.append(Route.capture(sample: false)) }
                    .accessibilityIdentifier("newAssessmentButton")
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < 2 {
            selected.insert(id)
        }
    }

    private func detail(_ record: AssessmentRecord) -> some View {
        SummaryView(
            front: record.frontFinding,
            back: record.backFinding,
            frontImage: ImageStore.load(record.frontFileName),
            backImage: ImageStore.load(record.backFileName),
            isSample: record.isSample,
            onDelete: {
                delete(record)
                path.removeLast()
            }
        )
        .navigationTitle("Assessment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete(_ record: AssessmentRecord) {
        ImageStore.delete(record.frontFileName)
        ImageStore.delete(record.backFileName)
        modelContext.delete(record)
    }
}

private enum Route: Hashable {
    case capture(sample: Bool)
    case detail(UUID)
    case compare(UUID, UUID)
}
