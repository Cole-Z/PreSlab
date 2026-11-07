import Foundation

/// Later AI observations. A statement has to name what the photo cannot show.
/// Nothing in this milestone calls a model or turns observations into a grade.
nonisolated protocol ConditionObserver: Sendable {
    func observe(crops: [ObservationCrop]) async throws -> [ConditionObservation]
}

nonisolated struct ObservationCrop: Sendable {
    var region: String
    var jpeg: Data
}

nonisolated struct ConditionObservation: Sendable {
    var region: String
    var statement: String
    var limitation: String
}

/// Exists so a future calibrated range has somewhere to live other than the view.
/// The only result this milestone allows is "not enough evidence."
nonisolated protocol GradeEstimator: Sendable {
    func estimate(front: SideFinding, back: SideFinding, observations: [ConditionObservation]) -> GradeEstimate
}

nonisolated enum GradeEstimate: Sendable {
    case insufficientEvidence(reason: String)
}

/// Card identity and price stay out of the condition result. Scrydex is not
/// called from the app; a later backend would implement PriceLookup after
/// written permission to display prices.
nonisolated protocol CardCatalog: Sendable {
    func identify(frontJPEG: Data) async throws -> String?
}

nonisolated protocol PriceLookup: Sendable {
    func lookup(cardID: String) async throws -> PriceQuote?
}

nonisolated struct PriceQuote: Sendable {
    var source: String
    var fetchedOn: Date
    var rawMarket: Decimal?
    var gradedMarket: Decimal?
    var currency: String
}
