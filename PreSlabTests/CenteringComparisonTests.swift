import Testing
@testable import PreSlab

private func face(_ h: Double, _ v: Double) -> FaceImbalance { FaceImbalance(horizontal: h, vertical: v) }
private func row(_ c: CenteringComparison, _ label: String) -> CenteringRowResult {
    c.rows.first { $0.row.gradeLabel == label }!
}

@Test func crossCompanyBaseline() {
    let f = face(58, 58), b = face(70, 70)
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: f, back: b)
    #expect(row(psa, "9 Mint").state == .compatible)
    #expect(row(psa, "10 Gem Mint").state == .outsideBaseline)
    let bgs = CenteringComparisonEngine.evaluate(grader: .bgs, category: .tcg, front: f, back: b)
    #expect(row(bgs, "8 NM-MT").state == .compatible)
    #expect(row(bgs, "9 Mint").state == .outsideBaseline)
}

@Test func tagCategorySeparation() {
    let f = face(54, 54), b = face(68, 68)
    let sports = CenteringComparisonEngine.evaluate(grader: .tag, category: .sports, front: f, back: b)
    #expect(row(sports, "Gem Mint 10").state == .compatible)
    let tcg = CenteringComparisonEngine.evaluate(grader: .tag, category: .tcg, front: f, back: b)
    #expect(row(tcg, "Gem Mint 10").state == .outsideBaseline)
}

@Test func directionMirrorIsIdentical() {
    #expect(FaceImbalance.imbalance(a: 58, b: 42) == FaceImbalance.imbalance(a: 42, b: 58))
    let a = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(58, 58), back: face(70, 70))
    let b = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(58, 58), back: face(70, 70))
    #expect(a.rows.map(\.state) == b.rows.map(\.state))
}

@Test func oneBadAxisFails() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(54, 61), back: face(60, 60))
    #expect(row(psa, "9 Mint").state == .outsideBaseline)
}

@Test func exactThresholdPSA10() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(55, 55), back: face(75, 75))
    #expect(row(psa, "10 Gem Mint").state == .compatible)
    #expect(row(psa, "10 Gem Mint").detail.contains("approximate"))
}

@Test func thresholdUncertaintyIsBorderline() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(55, 55), back: face(75, 75), uncertainty: 1)
    #expect(row(psa, "10 Gem Mint").state == .borderlineUncertain)
}

@Test func noRoundingRescue() {
    // 55.04 stored unrounded must not pass nominal 55 by display rounding
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(55.04, 55.04), back: face(70, 70))
    #expect(row(psa, "10 Gem Mint").state == .outsideBaseline)
}

@Test func missingBackIsNotFiftyFifty() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(55, 55), back: nil)
    #expect(row(psa, "10 Gem Mint").state == .missingMeasurement)
    #expect(psa.highestCompatible == nil)
}

@Test func cgcTCGUnknownIsNotSportsPass() {
    let cgc = CenteringComparisonEngine.evaluate(grader: .cgc, category: .tcg, front: face(60, 60), back: face(90, 90))
    #expect(row(cgc, "9").state == .insufficientPublishedInformation)
}

@Test func cgcPristineScopeUnresolved() {
    let cgc = CenteringComparisonEngine.evaluate(grader: .cgc, category: .tcg, front: face(50, 50), back: face(50, 50))
    #expect(row(cgc, "Pristine 10").state == .insufficientPublishedInformation)
}

@Test func cgcSports8ScopeUnresolved() {
    let cgc = CenteringComparisonEngine.evaluate(grader: .cgc, category: .sports, front: face(65, 65), back: face(65, 65))
    #expect(row(cgc, "8").state == .insufficientPublishedInformation)
}

@Test func tagSliverNeedsQualitativeReview() {
    let tag = CenteringComparisonEngine.evaluate(grader: .tag, category: .sports, front: face(60, 60), back: face(90, 90))
    #expect(row(tag, "8").state == .qualitativeReviewRequired)
}

@Test func bgs100IsNumericTagSliverIsNot() {
    let bgs = CenteringComparisonEngine.evaluate(grader: .bgs, category: .sports, front: face(80, 80), back: face(99, 99))
    #expect(row(bgs, "4 VG-EX").state == .compatible)
    #expect(row(bgs, "4 VG-EX").detail.contains("100/0"))
    let tag = CenteringComparisonEngine.evaluate(grader: .tag, category: .sports, front: face(85, 85), back: face(99, 99))
    #expect(row(tag, "4").state == .qualitativeReviewRequired)
}

@Test func halfGradeGapsNoInterpolation() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(55, 55), back: face(75, 75))
    #expect(row(psa, "8.5").state == .insufficientPublishedInformation)
    let bgs = CenteringComparisonEngine.evaluate(grader: .bgs, category: .tcg, front: face(55, 55), back: face(60, 60))
    #expect(row(bgs, "8.5").state == .insufficientPublishedInformation)
}

@Test func psaLeewayNotAutoPass() {
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(65, 65), back: face(80, 80))
    let r = row(psa, "9 Mint")
    #expect(r.state == .outsideBaseline)
    #expect(r.detail.contains("discretionary"))
    #expect(r.detail.contains("not auto-applied"))
}

@Test func bgsPristineLabelsAreNotDistinguished() {
    let bgs = CenteringComparisonEngine.evaluate(grader: .bgs, category: .tcg, front: face(50, 50), back: face(55, 55))
    #expect(row(bgs, "10 Pristine").state == .compatible)
    #expect(row(bgs, "10 Pristine").detail.contains("cannot distinguish"))
    #expect(!bgs.summaryText.contains("Black Label"))
    #expect(!bgs.summaryText.contains("Gold Label"))
}

@Test func qualitativePublishedCriteriaRequireQualitativeReview() {
    let cgc = CenteringComparisonEngine.evaluate(grader: .cgc, category: .tcg, front: face(55, 55), back: face(75, 75))
    #expect(row(cgc, "Mint+ 9.5").state == .qualitativeReviewRequired)
}

@Test func invalidSavedBackGeometryIsNotTreatedAsMissing() {
    let front = SideFinding(issues: [], quad: nil, insets: BorderInsets(left: 0.05, right: 0.05, top: 0.05, bottom: 0.05), adjustedByUser: false, unsupportedReason: nil)
    let back = SideFinding(issues: [], quad: nil, insets: BorderInsets(left: -0.1, right: 0.1, top: 0.05, bottom: 0.05), adjustedByUser: true, unsupportedReason: nil)
    let psa = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, frontFinding: front, backFinding: back)
    #expect(psa.rows.allSatisfy { $0.state == .invalidMeasurement })
}

@Test func tagScoreBandNotAssignedFromCentering() {
    let tag = CenteringComparisonEngine.evaluate(grader: .tag, category: .sports, front: face(54, 54), back: face(68, 68))
    let r = row(tag, "Gem Mint 10")
    #expect(r.state == .compatible)
    #expect(r.detail.contains("not a centering score"))
    #expect(!tag.summaryText.contains("950"))
}

@Test func invalidGeometryRejected() {
    #expect(FaceImbalance.imbalance(a: -1, b: 10) == nil)
    #expect(FaceImbalance.imbalance(a: 0, b: 0) == nil)
    let bad = CenteringComparisonEngine.evaluate(grader: .psa, category: .tcg, front: face(30, 30), back: face(60, 60))
    #expect(bad.rows.allSatisfy { $0.state == .invalidMeasurement })
}

@Test func magikarpCaseBackAtCardEdgeIsMissingNotFiftyFifty() {
    // Front 61/39, 53/47 as in the reported Magikarp; back lines left on the card edge (0/0).
    let front = SideFinding(issues: [], quad: nil, insets: BorderInsets(left: 0.061, right: 0.039, top: 0.053, bottom: 0.047), adjustedByUser: true, unsupportedReason: nil)
    let back = SideFinding(issues: [], quad: nil, insets: BorderInsets(left: 0, right: 0, top: 0, bottom: 0), adjustedByUser: true, unsupportedReason: nil)
    let tag = CenteringComparisonEngine.evaluate(grader: .tag, category: .tcg, frontFinding: front, backFinding: back)
    #expect(row(tag, "9").state == .outsideBaseline)
    #expect(row(tag, "8.5").state == .missingMeasurement)
    #expect(tag.highestCompatible == nil)
    #expect(tag.blockerSummary != nil)
}

@Test func unknownHigherRowIsNotCeiling() {
    // CGC TCG: Gem Mint 10 assessable, Pristine/Mint+ unresolved above it
    let cgc = CenteringComparisonEngine.evaluate(grader: .cgc, category: .tcg, front: face(55, 55), back: face(75, 75))
    #expect(cgc.highestCompatible?.row.gradeLabel == "Gem Mint 10")
    #expect(cgc.unresolvedHigherRows.contains { $0.row.gradeLabel == "Pristine 10" })
    #expect(!cgc.summaryText.lowercased().contains("ceiling"))
}
