import SwiftUI

struct CenteringAdjustView: View {
    var side: CardSide
    var original: RGBAImage
    @Binding var finding: SideFinding
    @Binding var warped: RGBAImage?
    var onContinue: () -> Void

    @State private var mode: AdjustMode
    @State private var automatic: SideFinding
    @State private var automaticWarped: RGBAImage?
    @State private var artworkImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var draftInsets: BorderInsets
    @State private var artworkAdjustedByUser = false
    @State private var artworkTask: Task<Void, Never>?
    @State private var remeasurementTask: Task<Void, Never>?
    @State private var isRemeasuring = false

    init(side: CardSide, original: RGBAImage, finding: Binding<SideFinding>, warped: Binding<RGBAImage?>, onContinue: @escaping () -> Void) {
        self.side = side
        self.original = original
        self._finding = finding
        self._warped = warped
        self.onContinue = onContinue
        // Automatic card-edge detection happens before this screen. Always
        // open on the collector's actual task: placing the artwork borders.
        self._mode = State(initialValue: .artwork)
        self._automatic = State(initialValue: finding.wrappedValue)
        self._automaticWarped = State(initialValue: warped.wrappedValue)
        self._draftInsets = State(initialValue: finding.wrappedValue.insets ?? Self.defaultInsets)
        // Image conversion and warping belong in onAppear/commit, never init:
        // SwiftUI recreates this value whenever a handle updates the binding.
    }

    private static let defaultInsets = BorderInsets(left: 0.08, right: 0.08, top: 0.08, bottom: 0.08)
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(side.title) centering").font(.title2.bold())
            Text(mode == .artwork
                 ? "Place the white crosshairs where the border meets the picture. If the yellow outline misses the card, adjust Card edges first."
                 : "Place the yellow crosshairs on the four card corners.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 60, alignment: .topLeading)

            Picker("What to adjust", selection: $mode) {
                Text("Artwork border").tag(AdjustMode.artwork)
                Text("Card edges").tag(AdjustMode.edges)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("adjustModePicker")

            Group {
                if mode == .artwork, let artworkImage {
                    ArtworkBorderEditor(image: artworkImage, insets: draftInsets, onChange: updateArtwork)
                } else if mode == .edges, let originalImage, let quad = finding.quad {
                    CardEdgeEditor(image: originalImage, quad: quad, onPreview: { finding.quad = $0 }, onCommit: remeasure)
                } else if mode == .artwork, finding.quad != nil {
                    ProgressView("Preparing editor…")
                } else {
                    ContentUnavailableView("Nothing to adjust", systemImage: "viewfinder", description: Text("The card edges were not found."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Keep this space stable when a line crosses the card outline.
            // A changing editor height moves the photo underneath an active drag.
            HStack {
                ratioColumn(title: "Left / right", value: finding.ratios?.horizontalText ?? "—", identifier: "centeringRatioHorizontal")
                ratioColumn(title: "Top / bottom", value: finding.ratios?.verticalText ?? "—", identifier: "centeringRatioVertical")
            }
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(finding.ratios == nil ? Color.orange : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                .accessibilityIdentifier(finding.ratios == nil ? "centeringUnsupported" : "centeringStatus")

            HStack {
                Button(automatic.insets == nil ? "Reset starting lines" : "Reset detected lines", action: restoreAutomatic)
                    .disabled(!finding.adjustedByUser || isRemeasuring)
                Spacer()
                Button(continueTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRemeasuring)
                    .accessibilityIdentifier("centeringContinueButton")
            }
        }
        .padding()
        .onAppear {
            if originalImage == nil { originalImage = ImageCoding.uiImage(from: original) }
            if artworkImage == nil { refreshArtworkImage() }
        }
        .onDisappear {
            artworkTask?.cancel()
            remeasurementTask?.cancel()
        }
    }

    private var statusMessage: String {
        if isRemeasuring {
            return "Updating the perspective-corrected measurement…"
        }
        if finding.ratios != nil {
            return finding.adjustedByUser ? "Printed frame adjusted by you. These ratios are not a grade." : "Printed frame detected from the photo. These ratios are not a grade."
        }
        if artworkAdjustedByUser && !draftInsets.isValidPlacement {
            return "Place white lines inside the yellow card outline, with artwork between them. Adjust Card edges if needed."
        }
        return "Move each white crosshair to the artwork border to measure this side."
    }

    private var continueTitle: String {
        guard finding.ratios != nil else { return "Leave centering unmeasured" }
        return "Use this centering"
    }

    private func updateArtwork(_ updated: BorderInsets) {
        // Preserve the actual editor position, including the photo margin.
        // Invalid placements have no measurement; clamping them would invent
        // a border width and snap the handle back when the finger lifts.
        draftInsets = updated
        finding.insets = updated.isValidPlacement ? updated : nil
        finding.adjustedByUser = true
        finding.measurementBasis = updated.isValidPlacement ? .manualPrintedFrame : nil
        finding.limitation = updated.isValidPlacement ? nil : .invalidGeometry
        finding.unsupportedReason = updated.isValidPlacement ? nil : "The artwork lines extend outside the card or overlap."
        artworkAdjustedByUser = true
    }

    private func ratioColumn(title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title.monospacedDigit()).accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshArtworkImage() {
        artworkTask?.cancel()
        guard let quad = finding.quad else {
            artworkImage = nil
            return
        }
        let source = original
        artworkTask = Task { @MainActor in
            let expanded = await Task.detached(priority: .userInitiated) {
                CardWarp.flattenExpanded(source, quad: quad)
            }.value
            guard !Task.isCancelled else { return }
            artworkImage = expanded.flatMap { ImageCoding.uiImage(from: $0) }
            artworkTask = nil
        }
    }

    private func restoreAutomatic() {
        remeasurementTask?.cancel()
        isRemeasuring = false
        finding = automatic
        draftInsets = automatic.insets ?? Self.defaultInsets
        artworkAdjustedByUser = false
        warped = automaticWarped
        refreshArtworkImage()
    }

    private func remeasure(quad: CardQuad) {
        remeasurementTask?.cancel()
        let kept = artworkAdjustedByUser && draftInsets.isValidPlacement ? draftInsets : nil
        let keptBasis: CenteringMeasurementBasis? = kept == nil ? nil : .manualPrintedFrame
        let source = original
        finding.quad = quad
        isRemeasuring = true
        remeasurementTask = Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                CardGeometryEngine.assess(
                    image: source,
                    quad: quad,
                    presetInsets: kept,
                    adjustedByUser: true,
                    presetBasis: keptBasis
                )
            }.value
            guard !Task.isCancelled else { return }
            finding = result.finding
            warped = result.warped
            if artworkAdjustedByUser {
                updateArtwork(draftInsets)
            } else {
                draftInsets = finding.insets ?? Self.defaultInsets
            }
            isRemeasuring = false
            remeasurementTask = nil
            refreshArtworkImage()
        }
    }

}

private enum AdjustMode { case artwork, edges }

private struct ArtworkBorderEditor: View {
    var image: UIImage
    var insets: BorderInsets
    var onChange: (BorderInsets) -> Void

    var body: some View {
        CardEditorCanvas(image: image) { fit, bounds, pinching in
            let pad = CGFloat(PaddedCardCoordinates.pad)
            Rectangle()
                .stroke(Color.yellow.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: fit.width * (1 - 2 * pad), height: fit.height * (1 - 2 * pad))
                .position(x: fit.midX, y: fit.midY)
                .allowsHitTesting(false)
            border(.left, fit: fit, bounds: bounds, pinching: pinching)
            border(.right, fit: fit, bounds: bounds, pinching: pinching)
            border(.top, fit: fit, bounds: bounds, pinching: pinching)
            border(.bottom, fit: fit, bounds: bounds, pinching: pinching)
        }
    }

    private func border(_ edge: ArtworkEdge, fit: CGRect, bounds: CGRect, pinching: Bool) -> some View {
        let value = insets[keyPath: edge.keyPath]
        let cardFraction = edge.isTrailing ? 1 - value : value
        return InsetLineView(vertical: edge.isVertical,
                             fraction: PaddedCardCoordinates.paddedFraction(fromCard: cardFraction),
                             fit: fit, bounds: bounds, pinching: pinching,
                             identifier: edge.rawValue + "BorderHandle",
                             label: edge.accessibilityLabel) { padded in
            var next = insets
            let card = PaddedCardCoordinates.cardFraction(fromPadded: padded)
            next[keyPath: edge.keyPath] = edge.isTrailing ? 1 - card : card
            onChange(next)
        }
    }
}

private enum ArtworkEdge: String {
    case left, right, top, bottom
    var isVertical: Bool { self == .left || self == .right }
    var isTrailing: Bool { self == .right || self == .bottom }
    var accessibilityLabel: String {
        switch self {
        case .left: "Left artwork border"
        case .right: "Right artwork border"
        case .top: "Top artwork border"
        case .bottom: "Bottom artwork border"
        }
    }
    var keyPath: WritableKeyPath<BorderInsets, Double> {
        switch self {
        case .left: \.left
        case .right: \.right
        case .top: \.top
        case .bottom: \.bottom
        }
    }
}

private struct InsetLineView: View {
    var vertical: Bool
    var fraction: Double
    var fit: CGRect
    var bounds: CGRect
    var pinching: Bool
    var identifier: String
    var label: String
    var onChange: (Double) -> Void
    @State private var drag: CardEditorDrag?
    @State private var interrupted = false
    @GestureState private var dragging = false

    var body: some View {
        // A line's handle stays reachable along its visible span when zoomed.
        let point = CGPoint(x: vertical ? fit.minX + fit.width * fraction : min(bounds.maxX - 24, max(24, fit.midX)),
                            y: vertical ? min(bounds.maxY - 24, max(24, fit.midY)) : fit.minY + fit.height * fraction)
        SpanGuides(point: point, bounds: bounds, vertical: vertical)
        CrosshairHandle(color: .white)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
            .accessibilityValue(String(format: "%.5f", fraction))
            .accessibilityAdjustableAction { direction in
                // One image pixel, independent of the current zoom.
                let delta = 1.0 / Double(vertical ? CardWarp.canonicalWidth : CardWarp.canonicalHeight)
                onChange(limited(fraction + (direction == .increment ? delta : -delta)))
            }
            // Attach the gesture before positioning, so the hit area remains
            // the 48pt handle rather than its full-size layout container.
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("cardEditor"))
                .updating($dragging) { _, state, _ in state = true }
                .onChanged { value in move(value.translation) }
                .onEnded { value in
                    move(value.translation)
                    drag = nil
                    interrupted = false
                })
            .position(point)
            .onChange(of: dragging) { _, active in if !active { drag = nil; interrupted = false } }
    }

    private func move(_ translation: CGSize) {
        if pinching { interrupted = true }
        guard !interrupted else { return }
        let origin = drag ?? CardEditorDrag(start: NormPoint(x: fraction, y: fraction), imageSize: fit.size)
        drag = origin
        let next = origin.point(translation: translation)
        onChange(limited(vertical ? next.x : next.y))
    }

    private func limited(_ value: Double) -> Double { min(1.08, max(-0.08, value)) }
}

private struct CardEdgeEditor: View {
    var image: UIImage
    var quad: CardQuad
    var onPreview: (CardQuad) -> Void
    var onCommit: (CardQuad) -> Void

    var body: some View {
        CardEditorCanvas(image: image) { fit, bounds, pinching in
            corner(\.topLeft, "cornerTopLeft", "Top-left card corner", fit, bounds, pinching)
            corner(\.topRight, "cornerTopRight", "Top-right card corner", fit, bounds, pinching)
            corner(\.bottomRight, "cornerBottomRight", "Bottom-right card corner", fit, bounds, pinching)
            corner(\.bottomLeft, "cornerBottomLeft", "Bottom-left card corner", fit, bounds, pinching)
        }
    }

    private func corner(_ keyPath: WritableKeyPath<CardQuad, NormPoint>, _ identifier: String, _ label: String, _ fit: CGRect, _ bounds: CGRect, _ pinching: Bool) -> some View {
        CornerHandleView(current: quad[keyPath: keyPath], fit: fit, bounds: bounds, pinching: pinching, identifier: identifier, label: label) { point, commit in
            var next = quad
            next[keyPath: keyPath] = point
            if commit { onCommit(next) } else { onPreview(next) }
        }
    }
}

private struct CornerHandleView: View {
    var current: NormPoint
    var fit: CGRect
    var bounds: CGRect
    var pinching: Bool
    var identifier: String
    var label: String
    var onMove: (NormPoint, Bool) -> Void
    @State private var drag: CardEditorDrag?
    @State private var interrupted = false
    @GestureState private var dragging = false

    var body: some View {
        let point = CGPoint(x: fit.minX + fit.width * current.x, y: fit.minY + fit.height * current.y)
        SpanGuides(point: point, bounds: bounds, vertical: nil)
        CrosshairHandle(color: .yellow)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
            .accessibilityValue(String(format: "%.5f,%.5f", current.x, current.y))
            .accessibilityAction(named: "Move left") { nudge(dx: -0.001, dy: 0) }
            .accessibilityAction(named: "Move right") { nudge(dx: 0.001, dy: 0) }
            .accessibilityAction(named: "Move up") { nudge(dx: 0, dy: -0.001) }
            .accessibilityAction(named: "Move down") { nudge(dx: 0, dy: 0.001) }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("cardEditor"))
                .updating($dragging) { _, state, _ in state = true }
                .onChanged { value in move(value.translation, commit: false) }
                .onEnded { value in
                    move(value.translation, commit: true)
                    drag = nil
                    interrupted = false
                })
            .position(point)
            .onChange(of: dragging) { _, active in
                if !active {
                    // Gesture cancellation still commits the last visible quad,
                    // keeping the artwork image in sync with its card corners.
                    if drag != nil { onMove(current, true) }
                    drag = nil
                    interrupted = false
                }
            }
    }

    private func move(_ translation: CGSize, commit: Bool) {
        if pinching { interrupted = true }
        guard !interrupted else {
            if commit, drag != nil { onMove(current, true) }
            return
        }
        let origin = drag ?? CardEditorDrag(start: current, imageSize: fit.size)
        drag = origin
        let next = origin.point(translation: translation)
        // Render and store the same bounded point, including on release.
        onMove(NormPoint(x: min(1.08, max(-0.08, next.x)), y: min(1.08, max(-0.08, next.y))), commit)
    }

    private func nudge(dx: Double, dy: Double) {
        onMove(
            NormPoint(
                x: min(1.08, max(-0.08, current.x + dx)),
                y: min(1.08, max(-0.08, current.y + dy))
            ),
            true
        )
    }
}

private struct SpanGuides: View {
    var point: CGPoint
    var bounds: CGRect
    var vertical: Bool?

    var body: some View {
        Group {
            guide(from: CGPoint(x: point.x, y: bounds.minY), to: CGPoint(x: point.x, y: bounds.maxY), bright: vertical == true)
            guide(from: CGPoint(x: bounds.minX, y: point.y), to: CGPoint(x: bounds.maxX, y: point.y), bright: vertical == false)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func guide(from: CGPoint, to: CGPoint, bright: Bool) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.white.opacity(bright ? 0.9 : 0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        .shadow(color: .black.opacity(0.8), radius: 1)
    }
}

private struct CrosshairHandle: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: 2).frame(width: 18, height: 18)
            Rectangle().fill(color).frame(width: 28, height: 1)
            Rectangle().fill(color).frame(width: 1, height: 28)
        }
        .shadow(color: .black.opacity(0.9), radius: 1)
        .frame(width: 48, height: 48)
        .contentShape(Rectangle())
    }
}
