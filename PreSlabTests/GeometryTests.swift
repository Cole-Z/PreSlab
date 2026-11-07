import Testing
import UIKit
@testable import PreSlab

@Test func colorRoundTripKeepsRedOnTheFirstChannel() throws {
    let image = RGBAImage(width: 4, height: 4) { _, _ in (220, 10, 20, 255) }
    let copy = RGBAImage.from(cgImage: try #require(image.cgImage()))
    #expect(copy != nil)
    let pixel = copy!.pixel(1, 1)
    #expect(pixel.0 == 220)
    #expect(pixel.1 == 10)
    #expect(pixel.2 == 20)
}

@Test func ratiosUseLeftAndTopShares() {
    let insets = BorderInsets(left: 60.0 / 750, right: 90.0 / 750, top: 70.0 / 1050, bottom: 50.0 / 1050)
    let ratios = CenteringRatios(insets: insets)
    #expect(ratios.horizontalText == "40/60")
    #expect(ratios.verticalText == "58/42")
}

@Test func movingTheLeftBorderChangesTheRatio() {
    var insets = SampleCard.expectedInsets(SampleCard.frontPixels)
    let before = CenteringRatios(insets: insets).leftShare
    insets.left += 0.02
    let after = CenteringRatios(insets: insets.clamped()).leftShare
    #expect(after > before + 0.01)
}

@Test func borderScanRecoversKnownWidths() throws {
    let card = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    let result = BorderScanner.scan(card)
    guard case .measured(let insets) = result else {
        Issue.record("Expected a measurement, got \(result)")
        return
    }
    let expected = SampleCard.expectedInsets(SampleCard.frontPixels)
    #expect(abs(insets.left - expected.left) * 100 <= 2)
    #expect(abs(insets.right - expected.right) * 100 <= 2)
    #expect(abs(insets.top - expected.top) * 100 <= 2)
    #expect(abs(insets.bottom - expected.bottom) * 100 <= 2)
}

@Test func uniformCardIsNotMeasured() {
    let image = RGBAImage(width: 400, height: 560) { _, _ in (200, 180, 40, 255) }
    guard case .unsupported = BorderScanner.scan(image) else {
        Issue.record("A borderless fill should not produce a centering ratio")
        return
    }
}

@Test func noisyCardIsNotMeasured() {
    let image = RGBAImage(width: 400, height: 560) { x, y in
        let noise = UInt8(truncatingIfNeeded: (x * 17 + y * 31) % 180)
        return (noise, UInt8(truncatingIfNeeded: Int(noise) + 20), noise, 255)
    }
    guard case .unsupported = BorderScanner.scan(image) else {
        Issue.record("Uneven texture should not produce a centering ratio")
        return
    }
}

@Test func perspectiveWarpRecoversKnownBorders() throws {
    let card = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    let quad = CardQuad(
        topLeft: NormPoint(x: 0.12, y: 0.08),
        topRight: NormPoint(x: 0.86, y: 0.12),
        bottomRight: NormPoint(x: 0.90, y: 0.90),
        bottomLeft: NormPoint(x: 0.08, y: 0.86)
    )
    let photo = try #require(CardWarp.composite(card: card, canvasWidth: 1000, canvasHeight: 1400, quad: quad))
    let flat = try #require(CardWarp.flatten(photo, quad: quad))
    guard case .measured(let insets) = BorderScanner.scan(flat) else {
        Issue.record("Warped card should still have a measurable border")
        return
    }
    let expected = CenteringRatios(insets: SampleCard.expectedInsets(SampleCard.frontPixels))
    let actual = CenteringRatios(insets: insets)
    #expect(abs(actual.leftShare - expected.leftShare) * 100 <= 2)
    #expect(abs(actual.topShare - expected.topShare) * 100 <= 2)
}

@Test func qualityGateRejectsATinyCutOffAndSteepQuad() {
    let image = RGBAImage(width: 1000, height: 1400) { _, _ in (20, 20, 20, 255) }
    let tiny = CardQuad.axisAligned(left: 0.4, top: 0.4, right: 0.55, bottom: 0.55)
    #expect(PhotoQuality.geometricIssues(image: image, quad: tiny).contains(.tooSmall))

    let clipped = CardQuad.axisAligned(left: 0.0, top: 0.1, right: 0.7, bottom: 0.9)
    #expect(PhotoQuality.geometricIssues(image: image, quad: clipped).contains(.edgeCutOff))

    let steep = CardQuad(
        topLeft: NormPoint(x: 0.4, y: 0.1),
        topRight: NormPoint(x: 0.6, y: 0.1),
        bottomRight: NormPoint(x: 0.9, y: 0.9),
        bottomLeft: NormPoint(x: 0.1, y: 0.9)
    )
    #expect(PhotoQuality.geometricIssues(image: image, quad: steep).contains(.tooSkewed))
}

@Test func sharpCardPassesBlurAndAWhitePatchFailsGlare() {
    let sharp = SampleCard.cardOnly(borders: SampleCard.frontPixels)
    #expect(PhotoQuality.edgeStrength(sharp) >= PhotoQuality.blurEdgeStrengthMinimum)
    let soft = boxBlur(sharp, radius: 6)
    #expect(PhotoQuality.edgeStrength(soft) < PhotoQuality.blurEdgeStrengthMinimum)

    var glared = sharp
    let patch = sharp.width * sharp.height / 8
    for index in 0..<patch {
        let pixel = index * 4
        glared.pixels[pixel] = 255
        glared.pixels[pixel + 1] = 255
        glared.pixels[pixel + 2] = 255
    }
    #expect(PhotoQuality.glareFraction(glared) > PhotoQuality.glareFractionLimit)
    #expect(PhotoQuality.glareFraction(sharp) < PhotoQuality.glareFractionLimit)
}

@Test func samplePhotoProducesFrontRatiosWithinTwoPoints() throws {
    let assessment = CardGeometryEngine.assess(SampleCard.front)
    #expect(assessment.finding.issues.isEmpty)
    let ratios = try #require(assessment.finding.ratios)
    #expect(ratios.horizontalText == "40/60" || withinTwoPoints(ratios.leftShare, 0.40))
    #expect(withinTwoPoints(ratios.topShare, 70.0 / 120.0))
}

@Test func frontWithoutAMeasurementIsInconclusive() {
    let front = SideFinding(issues: [], quad: nil, insets: nil, adjustedByUser: false, unsupportedReason: "none")
    let back = front
    #expect(AssessmentVerdict.decide(front: front, back: back) == .inconclusive)
}

@Test func measuredFrontIsRecordedWithoutAGrade() {
    let insets = SampleCard.expectedInsets(SampleCard.frontPixels)
    let front = SideFinding(issues: [], quad: nil, insets: insets, adjustedByUser: false, unsupportedReason: nil)
    let verdict = AssessmentVerdict.decide(front: front, back: .empty)
    #expect(verdict == .centeringRecorded)
    #expect(!AssessmentVerdict.gradeDisclaimer.lowercased().contains("psa"))
}

private func withinTwoPoints(_ share: Double, _ expected: Double) -> Bool {
    abs(share - expected) * 100 <= 2
}

private func boxBlur(_ image: RGBAImage, radius: Int) -> RGBAImage {
    let width = image.width
    let height = image.height
    var horizontal = image.pixels
    for y in 0..<height {
        for x in 0..<width {
            var red = 0, green = 0, blue = 0, count = 0
            for xx in max(0, x - radius)...min(width - 1, x + radius) {
                let pixel = image.pixel(xx, y)
                red += Int(pixel.0)
                green += Int(pixel.1)
                blue += Int(pixel.2)
                count += 1
            }
            let index = (y * width + x) * 4
            horizontal[index] = UInt8(red / count)
            horizontal[index + 1] = UInt8(green / count)
            horizontal[index + 2] = UInt8(blue / count)
            horizontal[index + 3] = 255
        }
    }
    let passed = RGBAImage(width: width, height: height, pixels: horizontal)
    return RGBAImage(width: width, height: height) { x, y in
        var red = 0, green = 0, blue = 0, count = 0
        for yy in max(0, y - radius)...min(height - 1, y + radius) {
            let pixel = passed.pixel(x, yy)
            red += Int(pixel.0)
            green += Int(pixel.1)
            blue += Int(pixel.2)
            count += 1
        }
        return (UInt8(red / count), UInt8(green / count), UInt8(blue / count), 255)
    }
}
