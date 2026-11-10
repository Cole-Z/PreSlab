import Foundation

/// A versioned, local-only interchange proposal. No CollectorAtlas network
/// connection exists; photographs and app-container file names are excluded.
nonisolated struct CollectorAtlasExportEnvelope: Codable, Equatable, Sendable {
    var format: String
    var formatVersion: Int
    var exportedAt: Date
    var photosIncluded: Bool
    var assessment: CollectorAtlasAssessmentPayload
}

nonisolated struct CollectorAtlasAssessmentPayload: Codable, Equatable, Sendable {
    var assessmentID: UUID
    var cardName: String
    var assessedAt: Date
    var submissionStatus: String
    var front: CollectorAtlasSidePayload
    var back: CollectorAtlasSidePayload
    var conditionObservations: [CollectorAtlasConditionPayload]
    var professionalOutcome: ProfessionalGradingOutcome?
    var gradingEconomics: GradingCostInputs?
}

nonisolated struct CollectorAtlasSidePayload: Codable, Equatable, Sendable {
    var leftShare: Double?
    var rightShare: Double?
    var topShare: Double?
    var bottomShare: Double?
    var measurementBasis: String?
    var gradingComparable: Bool
    var adjustedByUser: Bool
    var limitation: String?
}

nonisolated struct CollectorAtlasConditionPayload: Codable, Equatable, Sendable {
    var side: String
    var item: String
    var state: String
}

enum CollectorAtlasExportBuilder {
    static let format = "preslab.collectoratlas.assessment"
    static let currentVersion = 1

    static func make(record: AssessmentRecord, exportedAt: Date = .now) -> CollectorAtlasExportEnvelope {
        CollectorAtlasExportEnvelope(
            format: format,
            formatVersion: currentVersion,
            exportedAt: exportedAt,
            photosIncluded: false,
            assessment: CollectorAtlasAssessmentPayload(
                assessmentID: record.id,
                cardName: record.displayName,
                assessedAt: record.createdAt,
                submissionStatus: record.submissionStatus.rawValue,
                front: side(record.frontFinding),
                back: side(record.backFinding),
                conditionObservations: conditions(record.conditionChecklist),
                professionalOutcome: record.gradingOutcome,
                gradingEconomics: record.gradingCostInputs
            )
        )
    }

    static func encode(record: AssessmentRecord, exportedAt: Date = .now) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(make(record: record, exportedAt: exportedAt))
    }

    private static func side(_ finding: SideFinding) -> CollectorAtlasSidePayload {
        let ratios = finding.ratios
        return CollectorAtlasSidePayload(
            leftShare: ratios?.leftShare,
            rightShare: ratios.map { 1 - $0.leftShare },
            topShare: ratios?.topShare,
            bottomShare: ratios.map { 1 - $0.topShare },
            measurementBasis: finding.measurementBasis?.rawValue,
            gradingComparable: finding.hasGradingComparableCentering,
            adjustedByUser: finding.adjustedByUser,
            limitation: finding.limitation?.rawValue
        )
    }

    private static func conditions(_ checklist: ConditionChecklist) -> [CollectorAtlasConditionPayload] {
        CardSide.allCases.flatMap { side in
            checklist.recordedObservations(side: side).map { item, state in
                CollectorAtlasConditionPayload(side: side.rawValue, item: item.rawValue, state: state.rawValue)
            }
        }
    }
}
