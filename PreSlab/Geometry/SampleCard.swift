import Foundation

/// A drawn card on a dark background. It is a fixture for tests and the
/// in-app practice flow, not a photograph of a real card.
nonisolated enum SampleCard {
    static let cardWidth = 750
    static let cardHeight = 1050
    static let canvasWidth = 1000
    static let canvasHeight = 1400
    static let originX = 125
    static let originY = 175

    static let frontPixels = (left: 60, right: 90, top: 70, bottom: 50)
    static let backPixels = (left: 80, right: 70, top: 90, bottom: 60)

    static var front: RGBAImage { image(borders: frontPixels) }
    static var back: RGBAImage { image(borders: backPixels) }

    static var frontQuad: CardQuad { quad }
    static var backQuad: CardQuad { quad }

    static var quad: CardQuad {
        let left = Double(originX) / Double(canvasWidth - 1)
        let right = Double(originX + cardWidth - 1) / Double(canvasWidth - 1)
        let top = Double(originY) / Double(canvasHeight - 1)
        let bottom = Double(originY + cardHeight - 1) / Double(canvasHeight - 1)
        return .axisAligned(left: left, top: top, right: right, bottom: bottom)
    }

    static func image(borders: (left: Int, right: Int, top: Int, bottom: Int)) -> RGBAImage {
        RGBAImage(width: canvasWidth, height: canvasHeight) { x, y in
            let cardX = x - originX
            let cardY = y - originY
            guard cardX >= 0, cardY >= 0, cardX < cardWidth, cardY < cardHeight else {
                return (28, 28, 32, 255)
            }
            let onBorder = cardX < borders.left
                || cardX >= cardWidth - borders.right
                || cardY < borders.top
                || cardY >= cardHeight - borders.bottom
            if onBorder {
                return (236, 196, 46, 255)
            }
            return (18, 52, 96, 255)
        }
    }

    static func cardOnly(borders: (left: Int, right: Int, top: Int, bottom: Int)) -> RGBAImage {
        RGBAImage(width: cardWidth, height: cardHeight) { x, y in
            let onBorder = x < borders.left
                || x >= cardWidth - borders.right
                || y < borders.top
                || y >= cardHeight - borders.bottom
            if onBorder {
                return (236, 196, 46, 255)
            }
            return (18, 52, 96, 255)
        }
    }

    static func expectedInsets(_ borders: (left: Int, right: Int, top: Int, bottom: Int)) -> BorderInsets {
        BorderInsets(
            left: Double(borders.left) / Double(cardWidth),
            right: Double(borders.right) / Double(cardWidth),
            top: Double(borders.top) / Double(cardHeight),
            bottom: Double(borders.bottom) / Double(cardHeight)
        )
    }
}
