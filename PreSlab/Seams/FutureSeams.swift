import Foundation

/// A local test seam for evaluating condition-observation UI with canned data.
/// PreSlab does not call a hosted model or turn observations into a grade.
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

/// Dormant interfaces retained only to keep future research outside view code.
/// They have no implementation or runtime entry point. Card identity, price
/// lookup, scraping, and backend services are not approved product scope.
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
