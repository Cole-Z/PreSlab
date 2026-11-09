import Testing
import CoreGraphics
@testable import PreSlab

@Test func zoomKeepsThePointUnderThePinchAnchor() {
    let base = CGRect(x: 40, y: 40, width: 300, height: 420)
    let anchor = CGPoint(x: 100, y: 130)
    let zoom = CardEditorTransform().zoomed(to: 4, around: anchor, base: base)
    let rect = zoom.imageRect(base: base)
    #expect(abs((anchor.x - rect.minX) / rect.width - (anchor.x - base.minX) / base.width) < 1e-9)
    #expect(abs((anchor.y - rect.minY) / rect.height - (anchor.y - base.minY) / base.height) < 1e-9)
}

@Test func zoomMakesTheSameFingerMovementMorePrecise() {
    let start = NormPoint(x: 0.1, y: 0.2)
    let normal = CardEditorDrag(start: start, imageSize: CGSize(width: 200, height: 280))
    let enlarged = CardEditorDrag(start: start, imageSize: CGSize(width: 1200, height: 1680))
    let translation = CGSize(width: 6, height: 6)
    #expect(abs(normal.point(translation: translation).x - start.x - 0.03) < 1e-9)
    #expect(abs(enlarged.point(translation: translation).x - start.x - 0.005) < 1e-9)
    // Short movements are retained; recognition must not swallow the first
    // few points of each repeated precision adjustment.
    #expect(enlarged.point(translation: CGSize(width: 1, height: 0)).x > start.x)
}

@Test func panningKeepsPhotoReachableAndResetZoomRecentersIt() {
    let base = CGRect(x: 36, y: 36, width: 200, height: 280)
    let zoom = CardEditorTransform().zoomed(to: 6, around: CGPoint(x: base.midX, y: base.midY), base: base)
    let pan = zoom.panned(by: CGSize(width: 10000, height: -10000), base: base)
    let rect = pan.imageRect(base: base)
    #expect(rect.minX == base.minX)
    #expect(rect.maxY == base.maxY)
    let reset = pan.zoomed(to: 1, around: CGPoint(x: 10, y: 10), base: base)
    #expect(reset.imageRect(base: base) == base)
}

@Test func marginAndCrossedArtworkLinesDoNotProduceRatios() {
    let margin = BorderInsets(left: -0.02, right: 0.08, top: 0.08, bottom: 0.08)
    let crossed = BorderInsets(left: 0.6, right: 0.6, top: 0.08, bottom: 0.08)
    for insets in [margin, crossed] {
        let finding = SideFinding(issues: [], quad: .fullImage, insets: insets, adjustedByUser: true, unsupportedReason: nil)
        #expect(finding.ratios == nil)
    }
    #expect(margin.left == -0.02) // Validation never moves the editor's line.
}

@Test func paddedOutlineMatchesPerspectiveCardCorners() throws {
    let quad = CardQuad(topLeft: NormPoint(x: 0.3, y: 0.15), topRight: NormPoint(x: 0.7, y: 0.2),
                        bottomRight: NormPoint(x: 0.9, y: 0.9), bottomLeft: NormPoint(x: 0.1, y: 0.8))
    let expanded = try #require(PaddedCardCoordinates.expandedQuad(quad))
    let mapping = try #require(Homography.mapping(from: [(0, 0), (1, 0), (1, 1), (0, 1)],
                                                 to: expanded.points.map { ($0.x, $0.y) }))
    let p = PaddedCardCoordinates.pad
    let corners = [(p, p), (1 - p, p), (1 - p, 1 - p), (p, 1 - p)]
    for (padded, expected) in zip(corners, quad.points) {
        let actual = try #require(mapping.apply(x: padded.0, y: padded.1))
        #expect(abs(actual.0 - expected.x) < 1e-9)
        #expect(abs(actual.1 - expected.y) < 1e-9)
    }
}
