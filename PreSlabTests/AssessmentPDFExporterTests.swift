import Testing
import UIKit
@testable import PreSlab

@Test @MainActor func pdfExportContainsAPDFHeader() {
    let image = ImageCoding.uiImage(from: SampleCard.front)
    let data = AssessmentPDFExporter.pdfData(
        cardName: "Test card",
        createdAt: Date(timeIntervalSince1970: 0),
        front: CardGeometryEngine.assess(SampleCard.front).finding,
        back: CardGeometryEngine.assess(SampleCard.back).finding,
        frontImage: image,
        backImage: nil,
        checklist: .empty
    )
    #expect(data.starts(with: Data("%PDF".utf8)))
}
