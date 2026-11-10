import Foundation
import Testing
@testable import PreSlab

@Test func legacyAssessmentMetadataHasSafeDefaults() throws {
    let finding = try JSONEncoder().encode(SideFinding.empty)
    let record = AssessmentRecord(
        frontFileName: "front.jpg",
        backFileName: "back.jpg",
        frontJSON: finding,
        backJSON: finding,
        isSample: false
    )
    #expect(record.displayName == "Untitled card")
    #expect(record.submissionStatus == .considering)
    #expect(record.conditionChecklist == .empty)
    #expect(record.gradingOutcome == nil)
    #expect(record.gradingCostInputs == nil)
}

@Test func conditionChecklistRoundTripsThroughAssessmentRecord() throws {
    var checklist = ConditionChecklist.empty
    checklist.set(.visibleIssue, for: .cornerWhitening, side: .front)
    checklist.set(.noVisibleIssue, for: .scratches, side: .back)
    let finding = try JSONEncoder().encode(SideFinding.empty)
    let record = AssessmentRecord(
        frontFileName: "front.jpg",
        backFileName: "back.jpg",
        frontJSON: finding,
        backJSON: finding,
        isSample: false
    )
    record.conditionChecklist = checklist
    #expect(record.conditionChecklist.state(for: .cornerWhitening, side: .front) == .visibleIssue)
    #expect(record.conditionChecklist.state(for: .scratches, side: .back) == .noVisibleIssue)
    #expect(record.conditionChecklist.state(for: .dents, side: .front) == .notInspected)
}

@Test func gradingCostCalculatorUsesUserEnteredEconomics() {
    let inputs = GradingCostInputs(
        rawCardValue: 100,
        estimatedGradedValue: 250,
        gradingCost: 25,
        shippingCost: 10,
        insuranceCost: 5,
        sellingFeePercent: 12,
        otherExpenses: 10
    )
    #expect(inputs.totalInvestment == 150)
    #expect(inputs.submissionCosts == 50)
    #expect(inputs.sellingFees == 30)
    #expect(inputs.estimatedProceeds == 220)
    #expect(inputs.potentialProfitOrLoss == 70)
    #expect(abs((inputs.breakEvenResaleValue ?? 0) - 170.4545) < 0.001)
}

@Test func gradingCalculatorCompanyDefaultsAndOfficialLinksAreConfigured() {
    #expect(GradingCalculatorCompany.psa.defaultGradingFee == 39.99)
    #expect(GradingCalculatorCompany.cgc.defaultGradingFee == 20.00)
    #expect(GradingCalculatorCompany.beckett.defaultGradingFee == 34.95)
    #expect(GradingCalculatorCompany.tag.defaultGradingFee == 39.00)
    #expect(GradingCalculatorCompany.psa.officialPricingURL.absoluteString == "https://www.psacard.com/services")
    #expect(GradingCalculatorCompany.cgc.officialPricingURL.absoluteString == "https://www.cgcgrading.com/submit/services/")
    #expect(GradingCalculatorCompany.beckett.officialPricingURL.absoluteString == "https://www.beckett.com/submit/cards/service")
    #expect(GradingCalculatorCompany.tag.officialPricingURL.absoluteString == "https://taggrading.com/pages/pricing")
}

@Test func gradingCostValidationRejectsImpossibleInputs() {
    var inputs = GradingCostInputs()
    inputs.shippingCost = -1
    #expect(!inputs.isValid)
    #expect(inputs.validationMessage?.contains("at or above zero") == true)

    inputs.shippingCost = 0
    inputs.sellingFeePercent = 101
    #expect(!inputs.isValid)
    #expect(inputs.validationMessage?.contains("between 0% and 100%") == true)
}

@Test func gradingCostsRoundTripThroughAssessmentRecord() throws {
    let finding = try JSONEncoder().encode(SideFinding.empty)
    let record = AssessmentRecord(frontFileName: "front.jpg", backFileName: "back.jpg", frontJSON: finding, backJSON: finding, isSample: false)
    let inputs = GradingCostInputs(rawCardValue: 25, estimatedGradedValue: 75, gradingCost: 20, shippingCost: 5, insuranceCost: 2, sellingFeePercent: 10, otherExpenses: 3)
    record.gradingCostInputs = inputs
    #expect(record.gradingCostInputs == inputs)
}

@Test func professionalOutcomeRoundTripsWithoutBecomingAPrediction() throws {
    let finding = try JSONEncoder().encode(SideFinding.empty)
    let record = AssessmentRecord(frontFileName: "front.jpg", backFileName: "back.jpg", frontJSON: finding, backJSON: finding, isSample: false)
    let outcome = ProfessionalGradingOutcome(company: "PSA", gradeReceived: "9", submissionDate: .distantPast, returnDate: .now, notes: "Recorded after return")
    record.gradingOutcome = outcome
    #expect(record.gradingOutcome == outcome)
}

@Test func collectorAtlasEnvelopeIsVersionedAndExcludesPhotos() throws {
    let measured = SideFinding(
        issues: [],
        quad: nil,
        insets: BorderInsets(left: 0.04, right: 0.06, top: 0.05, bottom: 0.05),
        adjustedByUser: false,
        unsupportedReason: nil
    )
    let encodedFinding = try JSONEncoder().encode(measured)
    let record = AssessmentRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        createdAt: Date(timeIntervalSince1970: 100),
        frontFileName: "private-front.jpg",
        backFileName: "private-back.jpg",
        frontJSON: encodedFinding,
        backJSON: encodedFinding,
        isSample: false,
        cardName: "Local card"
    )
    let data = try CollectorAtlasExportBuilder.encode(record: record, exportedAt: Date(timeIntervalSince1970: 200))
    let text = String(decoding: data, as: UTF8.self)
    let envelope = try JSONDecoder.iso8601.decode(CollectorAtlasExportEnvelope.self, from: data)
    #expect(envelope.format == "preslab.collectoratlas.assessment")
    #expect(envelope.formatVersion == 1)
    #expect(!envelope.photosIncluded)
    #expect(envelope.assessment.front.gradingComparable)
    #expect(!text.contains("private-front.jpg"))
    #expect(!text.contains("private-back.jpg"))
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
