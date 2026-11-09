import CoreGraphics

/// The viewport changes; measurements always stay in normalized image coordinates.
nonisolated struct CardEditorTransform: Equatable {
    static let maximumScale: CGFloat = 6
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    func imageRect(base: CGRect) -> CGRect {
        CGRect(x: base.midX + offset.width - base.width * scale / 2,
               y: base.midY + offset.height - base.height * scale / 2,
               width: base.width * scale, height: base.height * scale)
    }

    func zoomed(to requestedScale: CGFloat, around anchor: CGPoint, base: CGRect) -> Self {
        let nextScale = min(Self.maximumScale, max(1, requestedScale))
        let ratio = nextScale / scale
        let nextOffset = CGSize(
            width: anchor.x - base.midX - (anchor.x - base.midX - offset.width) * ratio,
            height: anchor.y - base.midY - (anchor.y - base.midY - offset.height) * ratio
        )
        return Self(scale: nextScale, offset: nextOffset).bounded(base: base)
    }

    func panned(by translation: CGSize, base: CGRect) -> Self {
        Self(scale: scale, offset: CGSize(width: offset.width + translation.width,
                                         height: offset.height + translation.height)).bounded(base: base)
    }

    private func bounded(base: CGRect) -> Self {
        let xLimit = base.width * (scale - 1) / 2
        let yLimit = base.height * (scale - 1) / 2
        return Self(scale: scale, offset: CGSize(
            width: min(xLimit, max(-xLimit, offset.width)),
            height: min(yLimit, max(-yLimit, offset.height))))
    }
}

/// A gesture retains its starting value and image size, including the first
/// few points of movement before the recognizer begins. Repeated small drags
/// therefore work at every zoom level without accumulating a grab offset.
nonisolated struct CardEditorDrag {
    var start: NormPoint
    var imageSize: CGSize

    func point(translation: CGSize) -> NormPoint {
        NormPoint(x: start.x + translation.width / max(imageSize.width, 1),
                  y: start.y + translation.height / max(imageSize.height, 1))
    }
}
