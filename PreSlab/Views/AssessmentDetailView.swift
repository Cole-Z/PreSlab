import SwiftData
import SwiftUI

struct AssessmentDetailView: View {
    var record: AssessmentRecord
    var onDelete: () -> Void

    @State private var showOrganizer = false
    @State private var showCosts = false

    var body: some View {
        SummaryView(
            front: record.frontFinding,
            back: record.backFinding,
            frontImage: ImageStore.load(record.frontFileName),
            backImage: ImageStore.load(record.backFileName),
            isSample: record.isSample,
            onDelete: onDelete,
            createdAt: record.createdAt,
            cardName: record.displayName,
            conditionChecklist: record.conditionChecklist,
            gradingOutcome: record.gradingOutcome,
            gradingCostInputs: record.gradingCostInputs
        )
        .navigationTitle(record.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCosts = true
                } label: {
                    Image(systemName: "dollarsign.circle")
                }
                .accessibilityLabel("Grading economics")
                .accessibilityIdentifier("assessmentCostsButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Organize") { showOrganizer = true }
                    .accessibilityIdentifier("organizeAssessmentButton")
            }
        }
        .sheet(isPresented: $showOrganizer) {
            AssessmentOrganizerView(record: record)
        }
        .sheet(isPresented: $showCosts) {
            NavigationStack {
                GradingCostCalculatorView(initialInputs: record.gradingCostInputs) { inputs in
                    record.gradingCostInputs = inputs
                    do {
                        try modelContext.save()
                        showCosts = false
                    } catch {
                        modelContext.rollback()
                        throw error
                    }
                }
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
}

private struct AssessmentOrganizerView: View {
    var record: AssessmentRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var status: SubmissionStatus
    @State private var checklist: ConditionChecklist
    @State private var recordsOutcome: Bool
    @State private var outcomeCompany: String
    @State private var outcomeGrade: String
    @State private var outcomeSubmissionDate: Date
    @State private var outcomeReturnDate: Date
    @State private var outcomeNotes: String
    @State private var saveError: String?

    init(record: AssessmentRecord) {
        self.record = record
        _name = State(initialValue: record.cardName ?? "")
        _status = State(initialValue: record.submissionStatus)
        _checklist = State(initialValue: record.conditionChecklist)
        let outcome = record.gradingOutcome
        _recordsOutcome = State(initialValue: outcome != nil)
        _outcomeCompany = State(initialValue: outcome?.company ?? "")
        _outcomeGrade = State(initialValue: outcome?.gradeReceived ?? "")
        _outcomeSubmissionDate = State(initialValue: outcome?.submissionDate ?? record.createdAt)
        _outcomeReturnDate = State(initialValue: outcome?.returnDate ?? .now)
        _outcomeNotes = State(initialValue: outcome?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Card name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("cardNameField")
                    Picker("Submission status", selection: $status) {
                        ForEach(SubmissionStatus.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                    .accessibilityIdentifier("submissionStatusPicker")
                }

                Section {
                    Text("These are your visual observations, not professional grades. Record only what you can see in the photos or on the card.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Condition checklist")
                }

                ForEach(CardSide.allCases, id: \.self) { side in
                    Section(side.title) {
                        ForEach(ConditionCategory.allCases) { category in
                            DisclosureGroup(category.title) {
                                ForEach(ConditionItem.allCases.filter { $0.category == category }) { item in
                                    Picker(item.title, selection: conditionBinding(item, side: side)) {
                                        ForEach(ConditionState.allCases) { state in
                                            Text(state.title).tag(state)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Record returned grade", isOn: $recordsOutcome)
                    if recordsOutcome {
                        TextField("Grading company", text: $outcomeCompany)
                            .textInputAutocapitalization(.characters)
                        TextField("Grade received", text: $outcomeGrade)
                            .keyboardType(.decimalPad)
                        DatePicker("Submission date", selection: $outcomeSubmissionDate, displayedComponents: .date)
                        DatePicker("Return date", selection: $outcomeReturnDate, in: outcomeSubmissionDate..., displayedComponents: .date)
                        TextField("Optional notes", text: $outcomeNotes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                } header: {
                    Text("Actual professional outcome")
                } footer: {
                    Text("Recorded after professional grading. It does not mean PreSlab predicted the final grade.")
                }
            }
            .navigationTitle("Organize assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(recordsOutcome && (cleanedOutcomeCompany.isEmpty || cleanedOutcomeGrade.isEmpty))
                        .accessibilityIdentifier("saveOrganizerButton")
                }
            }
            .alert("Could not save", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func conditionBinding(_ item: ConditionItem, side: CardSide) -> Binding<ConditionState> {
        Binding(
            get: { checklist.state(for: item, side: side) },
            set: { checklist.set($0, for: item, side: side) }
        )
    }

    private func save() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        record.cardName = cleaned.isEmpty ? nil : cleaned
        record.submissionStatus = status
        record.conditionChecklist = checklist
        if recordsOutcome {
            record.gradingOutcome = ProfessionalGradingOutcome(
                company: cleanedOutcomeCompany,
                gradeReceived: cleanedOutcomeGrade,
                submissionDate: outcomeSubmissionDate,
                returnDate: outcomeReturnDate,
                notes: outcomeNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            record.gradingOutcome = nil
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "Your changes were not saved. Please try again."
        }
    }

    private var cleanedOutcomeCompany: String {
        outcomeCompany.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedOutcomeGrade: String {
        outcomeGrade.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
