import SwiftUI

nonisolated enum GradingCalculatorCompany: String, CaseIterable, Identifiable {
    case psa
    case cgc
    case beckett
    case tag

    var id: Self { self }

    var shortName: String {
        switch self {
        case .psa: "PSA"
        case .cgc: "CGC"
        case .beckett: "BGS"
        case .tag: "TAG"
        }
    }

    var displayName: String {
        switch self {
        case .beckett: "Beckett (BGS)"
        default: shortName
        }
    }

    var defaultGradingFee: Double {
        switch self {
        case .psa: 39.99
        case .cgc: 20.00
        case .beckett: 34.95
        case .tag: 39.00
        }
    }

    var officialPricingURL: URL {
        switch self {
        case .psa: URL(string: "https://www.psacard.com/services")!
        case .cgc: URL(string: "https://www.cgcgrading.com/submit/services/")!
        case .beckett: URL(string: "https://www.beckett.com/submit/cards/service")!
        case .tag: URL(string: "https://taggrading.com/pages/pricing")!
        }
    }
}

struct GradingCostCalculatorView: View {
    var onSave: ((GradingCostInputs) throws -> Void)?

    @FocusState private var focusedField: CalculatorField?
    @State private var selectedCompany: GradingCalculatorCompany
    @State private var gradingFees: [GradingCalculatorCompany: Double]
    @State private var rawCardValue: Double?
    @State private var estimatedGradedValue: Double?
    @State private var shippingCost: Double?
    @State private var insuranceCost: Double?
    @State private var sellingFeePercent: Double?
    @State private var otherExpenses: Double?
    @State private var saveError: String?

    init(initialInputs: GradingCostInputs? = nil, onSave: ((GradingCostInputs) throws -> Void)? = nil) {
        self.onSave = onSave

        var fees = Dictionary(uniqueKeysWithValues: GradingCalculatorCompany.allCases.map {
            ($0, $0.defaultGradingFee)
        })
        let company = initialInputs.map { inputs in
            GradingCalculatorCompany.allCases.first {
                abs($0.defaultGradingFee - inputs.gradingCost) < 0.005
            } ?? .psa
        } ?? .psa
        if let initialInputs {
            fees[company] = initialInputs.gradingCost
        }

        _selectedCompany = State(initialValue: company)
        _gradingFees = State(initialValue: fees)
        _rawCardValue = State(initialValue: initialInputs?.rawCardValue)
        _estimatedGradedValue = State(initialValue: initialInputs?.estimatedGradedValue)
        _shippingCost = State(initialValue: initialInputs?.shippingCost)
        _insuranceCost = State(initialValue: initialInputs?.insuranceCost)
        _sellingFeePercent = State(initialValue: initialInputs?.sellingFeePercent)
        _otherExpenses = State(initialValue: initialInputs?.otherExpenses)
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var gradingFee: Binding<Double> {
        Binding(
            get: { gradingFees[selectedCompany] ?? selectedCompany.defaultGradingFee },
            set: { gradingFees[selectedCompany] = $0 }
        )
    }

    private var inputs: GradingCostInputs {
        GradingCostInputs(
            rawCardValue: rawCardValue ?? 0,
            estimatedGradedValue: estimatedGradedValue ?? 0,
            gradingCost: gradingFee.wrappedValue,
            shippingCost: shippingCost ?? 0,
            insuranceCost: insuranceCost ?? 0,
            sellingFeePercent: sellingFeePercent ?? 0,
            otherExpenses: otherExpenses ?? 0
        )
    }

    private var hasBothMarketValues: Bool {
        rawCardValue != nil && estimatedGradedValue != nil
    }

    private var omittedOptionalFields: [String] {
        var fields: [String] = []
        if shippingCost == nil { fields.append("shipping") }
        if insuranceCost == nil { fields.append("insurance") }
        if otherExpenses == nil { fields.append("other expenses") }
        if sellingFeePercent == nil { fields.append("selling fees") }
        return fields
    }

    var body: some View {
        Form {
            Section {
                Picker("Grading company", selection: $selectedCompany) {
                    ForEach(GradingCalculatorCompany.allCases) { company in
                        Text(company.shortName).tag(company)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("gradingCompanyPicker")

                moneyField("Estimated grading fee", value: gradingFee, focused: .gradingFee)
                    .accessibilityIdentifier("gradingFeeField")

                Button("Restore \(selectedCompany.shortName) default") {
                    gradingFees[selectedCompany] = selectedCompany.defaultGradingFee
                }

                Link("View Official Pricing & Submission", destination: selectedCompany.officialPricingURL)

                Text("Estimated grading fee. Actual prices vary by service tier, declared value, and provider. Additional charges may apply.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Grading service")
            }

            Section {
                optionalMoneyField("Raw card value", value: $rawCardValue, focused: .rawCardValue)
                    .accessibilityIdentifier("rawCardValueField")
                optionalMoneyField("Estimated graded value", value: $estimatedGradedValue, focused: .estimatedGradedValue)
                    .accessibilityIdentifier("estimatedGradedValueField")
            } header: {
                Text("Values")
            } footer: {
                Text("Enter your own estimates. PreSlab does not identify cards, retrieve prices, or guarantee a grade.")
            }

            Section {
                optionalMoneyField("Shipping cost", value: $shippingCost, focused: .shippingCost)
                optionalMoneyField("Insurance cost", value: $insuranceCost, focused: .insuranceCost)
                optionalMoneyField("Other expenses", value: $otherExpenses, focused: .otherExpenses)
                HStack {
                    Text("Selling fees")
                    Spacer()
                    TextField("Not entered", value: $sellingFeePercent, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .sellingFeePercent)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Optional expenses")
            } footer: {
                if omittedOptionalFields.isEmpty {
                    Text("All optional expense fields have been entered. Enter 0 to confirm no cost.")
                } else {
                    Text("Not included: \(omittedOptionalFields.joined(separator: ", ")). Enter 0 to confirm no cost.")
                }
            }

            Section("Estimate") {
                resultRow("Submission-only costs", value: inputs.submissionCosts)
                resultRow("Total economic basis", value: rawCardValue == nil ? nil : inputs.totalInvestment)
                resultRow("Estimated selling fees", value: estimatedGradedValue == nil ? nil : inputs.sellingFees)
                resultRow("Estimated proceeds", value: estimatedGradedValue == nil ? nil : inputs.estimatedProceeds)
                resultRow(
                    "Break-even resale value",
                    value: rawCardValue == nil ? nil : inputs.breakEvenResaleValue,
                    unavailableText: rawCardValue == nil ? "Needs input" : "Unavailable at 100% fees"
                )
                resultRow("Potential profit / loss", value: hasBothMarketValues ? inputs.potentialProfitOrLoss : nil, emphasized: true)

                if !hasBothMarketValues {
                    Label(
                        "Enter raw and estimated graded values to calculate potential profit. Known submission costs remain shown.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Total economic basis includes the raw card value plus submission costs. This calculator uses only your entries and does not predict a professional grade or future selling price.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let validationMessage = inputs.validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            if onSave != nil {
                Section {
                    Button("Save with assessment", action: save)
                        .frame(maxWidth: .infinity)
                        .disabled(!inputs.isValid)
                        .accessibilityIdentifier("saveGradingCostsButton")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Grading calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .accessibilityIdentifier("dismissCalculatorKeyboardButton")
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

    private func moneyField(_ title: String, value: Binding<Double>, focused field: CalculatorField) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
            Text(currencyCode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func optionalMoneyField(_ title: String, value: Binding<Double?>, focused field: CalculatorField) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Not entered", value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
            Text(currencyCode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resultRow(
        _ title: String,
        value: Double?,
        emphasized: Bool = false,
        unavailableText: String = "Needs input"
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Text(value, format: .currency(code: currencyCode))
                    .monospacedDigit()
                    .fontWeight(emphasized ? .bold : .regular)
            } else {
                Text(unavailableText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        guard inputs.isValid else { return }
        do {
            try onSave?(inputs)
        } catch {
            saveError = "Your grading-cost estimates were not saved. Please try again."
        }
    }
}

private enum CalculatorField: Hashable {
    case gradingFee
    case rawCardValue
    case estimatedGradedValue
    case shippingCost
    case insuranceCost
    case otherExpenses
    case sellingFeePercent
}
