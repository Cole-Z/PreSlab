import Foundation
import Testing
import UIKit
@testable import PreSlab

@Test func cropBuilderCoversNineLabeledRegions() {
    let card = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    let crops = ObservationCropBuilder.build(from: card)
    #expect(crops.map(\.region) == ["topLeft", "topRight", "bottomRight", "bottomLeft", "topEdge", "rightEdge", "bottomEdge", "leftEdge", "center"])
    for crop in crops {
        #expect(!crop.jpeg.isEmpty)
        let image = UIImage(data: crop.jpeg)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }
}

@Test func regionPrefixMarksTheCardSide() {
    let card = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    let crops = ObservationCropBuilder.buildRegions(from: card, prefix: "back-")
    #expect(crops.count == 9)
    #expect(crops.allSatisfy { $0.region.hasPrefix("back-") })
}

@Test func tinyImageYieldsNoCropsWithoutCrashing() {
    let image = RGBAImage(width: 20, height: 20) { _, _ in (200, 180, 40, 255) }
    let crops = ObservationCropBuilder.build(from: image)
    #expect(crops.isEmpty)
}

@Test func stubObserverAnswersEveryCropWithALimitation() async throws {
    let card = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    let crops = ObservationCropBuilder.build(from: card)
    let observations = try await StubConditionObserver().observe(crops: crops)
    #expect(observations.count == crops.count)
    for observation in observations {
        #expect(!observation.statement.isEmpty)
        #expect(!observation.limitation.isEmpty)
    }
}
