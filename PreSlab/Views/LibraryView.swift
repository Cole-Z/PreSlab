import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var records: [AssessmentRecord]

    @State private var path = NavigationPath()
    @State private var comparing = false
    @State private var selected: Set<UUID> = []
    @State private var persistenceError: String?
    @State private var searchText = ""
    @State private var statusFilter: SubmissionStatus?
    @State private var graderFilter: GraderProfile?
    @State private var outcomeFilter: OutcomeFilter = .all
    @State private var sort: LibrarySort = .newest

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
                case .stubTest:
                    StubTestView()
                case .costCalculator:
                    GradingCostCalculatorView()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search card names")
        .alert("Library update failed", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "")
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
            Button("Grading cost calculator") { path.append(Route.costCalculator) }
                .accessibilityIdentifier("gradingCalculatorButton")
        }
    }

    private var list: some View {
        Group {
            if displayedRecords.isEmpty {
                ContentUnavailableView(
                    "No matching assessments",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Change the search or filters to show more cards.")
                )
            } else {
                List {
                    ForEach(displayedRecords) { record in
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
        }
    }

    private func row(_ record: AssessmentRecord) -> some View {
        HStack(spacing: 12) {
            if comparing {
                Image(systemName: selected.contains(record.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(record.id) ? Color.accentColor : Color.secondary)
            }
            AssessmentThumbnail(fileName: record.frontFileName)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayName).font(.headline)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Front + back · \(AssessmentVerdict.decide(front: record.frontFinding, back: record.backFinding).title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(record.submissionStatus.title, systemImage: record.submissionStatus.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let outcome = record.gradingOutcome {
                    Label("\(outcome.company) \(outcome.gradeReceived) returned", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                Menu {
                    Picker("Submission status", selection: $statusFilter) {
                        Text("All statuses").tag(nil as SubmissionStatus?)
                        ForEach(SubmissionStatus.allCases) { status in
                            Text(status.title).tag(Optional(status))
                        }
                    }
                    Picker("Compatible baseline", selection: $graderFilter) {
                        Text("Any grader").tag(nil as GraderProfile?)
                        ForEach(GraderProfile.allCases) { grader in
                            Text(grader.title).tag(Optional(grader))
                        }
                    }
                    Picker("Sort", selection: $sort) {
                        ForEach(LibrarySort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("Professional outcome", selection: $outcomeFilter) {
                        ForEach(OutcomeFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if statusFilter != nil || graderFilter != nil || outcomeFilter != .all {
                        Button("Clear filters") {
                            statusFilter = nil
                            graderFilter = nil
                            outcomeFilter = .all
                        }
                    }
                    Divider()
                    Button {
                        path.append(Route.costCalculator)
                    } label: {
                        Label("Grading cost calculator", systemImage: "dollarsign.circle")
                    }
                } label: {
                    Image(systemName: statusFilter == nil && graderFilter == nil && outcomeFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter and sort assessments")
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

    private var displayedRecords: [AssessmentRecord] {
        records
            .filter { record in
                let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || record.displayName.localizedCaseInsensitiveContains(searchText)
                let matchesStatus = statusFilter == nil || record.submissionStatus == statusFilter
                let matchesOutcome = outcomeFilter.matches(record.gradingOutcome)
                let matchesGrader: Bool
                if let graderFilter {
                    matchesGrader = CenteringComparisonEngine.evaluate(
                        grader: graderFilter,
                        category: .tcg,
                        frontFinding: record.frontFinding,
                        backFinding: record.backFinding
                    ).highestCompatible != nil
                } else {
                    matchesGrader = true
                }
                return matchesSearch && matchesStatus && matchesOutcome && matchesGrader
            }
            .sorted(by: sort.areInIncreasingOrder)
    }

    private func detail(_ record: AssessmentRecord) -> some View {
        AssessmentDetailView(record: record) {
                if delete(record) {
                    path.removeLast()
                }
        }
    }

    @discardableResult
    private func delete(_ record: AssessmentRecord) -> Bool {
        let frontFileName = record.frontFileName
        let backFileName = record.backFileName
        modelContext.delete(record)
        do {
            try modelContext.save()
            ImageStore.delete(frontFileName)
            ImageStore.delete(backFileName)
            selected.remove(record.id)
            return true
        } catch {
            modelContext.rollback()
            persistenceError = "The assessment is still in your library and its photos were not removed. Please try again."
            return false
        }
    }
}

private enum OutcomeFilter: String, CaseIterable, Identifiable {
    case all
    case recorded
    case notRecorded

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Any outcome"
        case .recorded: "Outcome recorded"
        case .notRecorded: "No outcome recorded"
        }
    }

    func matches(_ outcome: ProfessionalGradingOutcome?) -> Bool {
        switch self {
        case .all: true
        case .recorded: outcome != nil
        case .notRecorded: outcome == nil
        }
    }
}

private struct AssessmentThumbnail: View {
    var fileName: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
            }
        }
        .frame(width: 46, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
        .task(id: fileName) {
            image = nil
            let name = fileName
            let thumbnail = await Task.detached(priority: .utility) {
                ImageStore.thumbnail(name)
            }.value
            guard !Task.isCancelled else { return }
            image = thumbnail.map { UIImage(cgImage: $0) }
        }
    }
}

private enum Route: Hashable {
    case capture(sample: Bool)
    case detail(UUID)
    case compare(UUID, UUID)
    case stubTest
    case costCalculator
}

private enum LibrarySort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .name: "Card name"
        case .status: "Submission status"
        }
    }

    func areInIncreasingOrder(_ lhs: AssessmentRecord, _ rhs: AssessmentRecord) -> Bool {
        switch self {
        case .newest: return lhs.createdAt > rhs.createdAt
        case .oldest: return lhs.createdAt < rhs.createdAt
        case .name: return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        case .status:
            if lhs.submissionStatus.rawValue == rhs.submissionStatus.rawValue {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.submissionStatus.rawValue < rhs.submissionStatus.rawValue
        }
    }
}
