import Foundation
import Testing
@testable import PreSlab

private func measuredFinding() -> SideFinding {
    SideFinding(
        issues: [],
        quad: nil,
        insets: BorderInsets(left: 0.08, right: 0.12, top: 0.07, bottom: 0.05),
        adjustedByUser: false,
        unsupportedReason: nil
    )
}

@Test func shareTextRecordsRatiosAndVerdict() {
    let text = AssessmentShareText.make(front: measuredFinding(), back: .empty, createdAt: Date())
    #expect(text.contains("Centering recorded"))
    #expect(text.contains("Front: left/right 40/60, top/bottom 58/42"))
    #expect(text.contains("Back: not measured"))
}

@Test func shareTextNotesHandAdjustment() {
    var finding = measuredFinding()
    finding.adjustedByUser = true
    let text = AssessmentShareText.make(front: finding, back: .empty, createdAt: Date())
    #expect(text.contains("adjusted by hand"))
}

@Test func shareTextAlwaysCarriesTheDisclaimer() {
    let text = AssessmentShareText.make(front: .empty, back: .empty, createdAt: Date())
    #expect(text.contains("Inconclusive"))
    #expect(text.contains("This is not a professional grade"))
}
