import Foundation

nonisolated enum SubmissionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case considering
    case readyToSubmit
    case notSubmitting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .considering: "Considering grading"
        case .readyToSubmit: "Ready to submit"
        case .notSubmitting: "Not submitting"
        }
    }

    var symbol: String {
        switch self {
        case .considering: "questionmark.folder"
        case .readyToSubmit: "shippingbox"
        case .notSubmitting: "archivebox"
        }
    }
}

nonisolated enum ConditionState: String, Codable, CaseIterable, Identifiable, Sendable {
    case notInspected
    case noVisibleIssue
    case possibleIssue
    case visibleIssue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notInspected: "Not inspected"
        case .noVisibleIssue: "No visible issue observed"
        case .possibleIssue: "Possible issue"
        case .visibleIssue: "Visible issue"
        }
    }
}

nonisolated enum ConditionCategory: String, CaseIterable, Identifiable, Sendable {
    case corners
    case edges
    case surface

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated enum ConditionItem: String, Codable, CaseIterable, Identifiable, Sendable {
    case cornerDamage
    case cornerBending
    case cornerWhitening
    case edgeWhitening
    case edgeChipping
    case roughEdges
    case scratches
    case printLines
    case dents
    case indentations
    case otherSurfaceDefect

    var id: String { rawValue }

    var category: ConditionCategory {
        switch self {
        case .cornerDamage, .cornerBending, .cornerWhitening: .corners
        case .edgeWhitening, .edgeChipping, .roughEdges: .edges
        case .scratches, .printLines, .dents, .indentations, .otherSurfaceDefect: .surface
        }
    }

    var title: String {
        switch self {
        case .cornerDamage: "Visible damage"
        case .cornerBending: "Bending"
        case .cornerWhitening: "Whitening"
        case .edgeWhitening: "Whitening"
        case .edgeChipping: "Chipping"
        case .roughEdges: "Rough edges"
        case .scratches: "Scratches"
        case .printLines: "Print lines"
        case .dents: "Dents"
        case .indentations: "Indentations"
        case .otherSurfaceDefect: "Other visible defects"
        }
    }
}

nonisolated struct ConditionChecklist: Codable, Equatable, Sendable {
    private var frontValues: [String: ConditionState] = [:]
    private var backValues: [String: ConditionState] = [:]

    static let empty = ConditionChecklist()

    func state(for item: ConditionItem, side: CardSide) -> ConditionState {
        values(for: side)[item.rawValue] ?? .notInspected
    }

    mutating func set(_ state: ConditionState, for item: ConditionItem, side: CardSide) {
        if side == .front {
            frontValues[item.rawValue] = state
        } else {
            backValues[item.rawValue] = state
        }
    }

    func recordedObservations(side: CardSide) -> [(ConditionItem, ConditionState)] {
        ConditionItem.allCases.compactMap { item in
            let state = state(for: item, side: side)
            return state == .notInspected ? nil : (item, state)
        }
    }

    private func values(for side: CardSide) -> [String: ConditionState] {
        side == .front ? frontValues : backValues
    }
}

nonisolated struct ProfessionalGradingOutcome: Codable, Equatable, Sendable {
    var company: String
    var gradeReceived: String
    var submissionDate: Date
    var returnDate: Date
    var notes: String
}

nonisolated struct GradingCostInputs: Codable, Equatable, Sendable {
    var rawCardValue: Double = 0
    var estimatedGradedValue: Double = 0
    var gradingCost: Double = 0
    var shippingCost: Double = 0
    var insuranceCost: Double = 0
    var sellingFeePercent: Double = 0
    var otherExpenses: Double = 0

    var submissionCosts: Double {
        safe(gradingCost) + safe(shippingCost) + safe(insuranceCost) + safe(otherExpenses)
    }

    var totalInvestment: Double {
        safe(rawCardValue) + submissionCosts
    }

    var sellingFees: Double {
        safe(estimatedGradedValue) * min(100, safe(sellingFeePercent)) / 100
    }

    var estimatedProceeds: Double { safe(estimatedGradedValue) - sellingFees }
    var potentialProfitOrLoss: Double { estimatedProceeds - totalInvestment }

    var breakEvenResaleValue: Double? {
        let retainedShare = 1 - min(100, safe(sellingFeePercent)) / 100
        guard retainedShare > 0 else { return nil }
        return totalInvestment / retainedShare
    }

    var validationMessage: String? {
        let amounts = [rawCardValue, estimatedGradedValue, gradingCost, shippingCost, insuranceCost, otherExpenses]
        if amounts.contains(where: { !$0.isFinite || $0 < 0 }) {
            return "Values and costs must be finite numbers at or above zero."
        }
        if !sellingFeePercent.isFinite || !(0...100).contains(sellingFeePercent) {
            return "Selling fees must be between 0% and 100%."
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    private func safe(_ value: Double) -> Double {
        value.isFinite ? max(0, value) : 0
    }
}
