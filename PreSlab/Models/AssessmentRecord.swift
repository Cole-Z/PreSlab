import Foundation
import SwiftData

@Model
final class AssessmentRecord {
    var id: UUID
    var createdAt: Date
    var frontFileName: String
    var backFileName: String
    var frontJSON: Data
    var backJSON: Data
    var isSample: Bool
    /// Optional additive fields keep existing SwiftData stores lightweight-migratable.
    var cardName: String?
    var submissionStatusRaw: String?
    var conditionJSON: Data?
    var gradingOutcomeJSON: Data?
    var gradingCostJSON: Data?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        frontFileName: String,
        backFileName: String,
        frontJSON: Data,
        backJSON: Data,
        isSample: Bool,
        cardName: String? = nil,
        submissionStatusRaw: String? = nil,
        conditionJSON: Data? = nil,
        gradingOutcomeJSON: Data? = nil,
        gradingCostJSON: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.frontFileName = frontFileName
        self.backFileName = backFileName
        self.frontJSON = frontJSON
        self.backJSON = backJSON
        self.isSample = isSample
        self.cardName = cardName
        self.submissionStatusRaw = submissionStatusRaw
        self.conditionJSON = conditionJSON
        self.gradingOutcomeJSON = gradingOutcomeJSON
        self.gradingCostJSON = gradingCostJSON
    }

    var frontFinding: SideFinding {
        (try? JSONDecoder().decode(SideFinding.self, from: frontJSON)) ?? .empty
    }

    var backFinding: SideFinding {
        (try? JSONDecoder().decode(SideFinding.self, from: backJSON)) ?? .empty
    }

    var displayName: String {
        let trimmed = cardName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled card" : trimmed
    }

    var submissionStatus: SubmissionStatus {
        get { submissionStatusRaw.flatMap(SubmissionStatus.init(rawValue:)) ?? .considering }
        set { submissionStatusRaw = newValue.rawValue }
    }

    var conditionChecklist: ConditionChecklist {
        get {
            guard let conditionJSON else { return .empty }
            return (try? JSONDecoder().decode(ConditionChecklist.self, from: conditionJSON)) ?? .empty
        }
        set { conditionJSON = try? JSONEncoder().encode(newValue) }
    }

    var gradingOutcome: ProfessionalGradingOutcome? {
        get {
            guard let gradingOutcomeJSON else { return nil }
            return try? JSONDecoder().decode(ProfessionalGradingOutcome.self, from: gradingOutcomeJSON)
        }
        set {
            if let newValue {
                gradingOutcomeJSON = try? JSONEncoder().encode(newValue)
            } else {
                gradingOutcomeJSON = nil
            }
        }
    }

    var gradingCostInputs: GradingCostInputs? {
        get {
            guard let gradingCostJSON else { return nil }
            return try? JSONDecoder().decode(GradingCostInputs.self, from: gradingCostJSON)
        }
        set {
            if let newValue {
                gradingCostJSON = try? JSONEncoder().encode(newValue)
            } else {
                gradingCostJSON = nil
            }
        }
    }
}
