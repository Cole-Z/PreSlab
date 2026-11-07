import SwiftUI

struct CenteringAdjustView: View {
    var side: CardSide
    var original: RGBAImage
    @Binding var finding: SideFinding
    @Binding var warped: RGBAImage?
    var onContinue: () -> Void

    @State private var mode: AdjustMode = .artwork
    @State private var automatic: SideFinding

    init(side: CardSide, original: RGBAImage, finding: Binding<SideFinding>, warped: Binding<RGBAImage?>, onContinue: @escaping () -> Void) {
        self.side = side
        self.original = original
        self._finding = finding
        self._warped = warped
        self.onContinue = onContinue
        self._automatic = State(initialValue: finding.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(side.title) centering")
                .font(.title2.bold())
            Text("Drag each handle onto its line: white circles to the middle of the yellow border, yellow circles to the card corners. The ratios describe the borders in this photo. They are not a grade.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("What to adjust", selection: $mode) {
                Text("Artwork border").tag(AdjustMode.artwork)
                Text("Card edges").tag(AdjustMode.edges)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("adjustModePicker")

            Group {
                if mode == .artwork, let warped, let uiImage = ImageCoding.uiImage(from: warped) {
                    ArtworkBorderEditor(image: uiImage, insets: artworkInsets) { updated in
                        finding.insets = updated.clamped()
                        finding.adjustedByUser = true
                        finding.unsupportedReason = nil
                    }
                } else if mode == .edges, let uiImage = ImageCoding.uiImage(from: original), let quad = finding.quad {
                    CardEdgeEditor(image: uiImage, quad: quad, onPreview: { updated in
                        finding.quad = updated
                    }, onCommit: { updated in
                        remeasure(quad: updated)
                    })
                } else {
                    ContentUnavailableView("Nothing to adjust", systemImage: "viewfinder", description: Text("The card edges were not found."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ratioBlock

            if finding.adjustedByUser {
                Text("Adjusted by you")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("adjustedByYou")
            } else if finding.insets != nil {
                Text("Detected from the photo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Reset detected lines") { restoreAutomatic() }
                    .disabled(!finding.adjustedByUser)
                Spacer()
                Button(continueTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("centeringContinueButton")
            }
        }
        .padding()
    }

    private var artworkInsets: BorderInsets {
        finding.insets ?? BorderInsets(left: 0.08, right: 0.08, top: 0.08, bottom: 0.08)
    }

    private var continueTitle: String {
        finding.insets == nil ? "Leave centering unmeasured" : "Use this centering"
    }

    @ViewBuilder
    private var ratioBlock: some View {
        if let ratios = finding.ratios {
            HStack {
                ratioColumn(title: "Left / right", value: ratios.horizontalText, identifier: "centeringRatioHorizontal")
                ratioColumn(title: "Top / bottom", value: ratios.verticalText, identifier: "centeringRatioVertical")
            }
        } else {
            Text(finding.unsupportedReason ?? "Centering was not measured.")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("centeringUnsupported")
            Button("Place borders manually") {
                finding.insets = artworkInsets.clamped()
                finding.adjustedByUser = true
                finding.unsupportedReason = nil
                mode = .artwork
            }
        }
    }

    private func ratioColumn(title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title.monospacedDigit()).accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restoreAutomatic() {
        finding = automatic
        if let quad = automatic.quad {
            warped = CardWarp.flatten(original, quad: quad)
        }
    }

    private func remeasure(quad: CardQuad) {
        let kept = finding.adjustedByUser && mode == .artwork ? finding.insets : nil
        let result = CardGeometryEngine.assess(
            image: original,
            quad: quad,
            presetInsets: kept,
            adjustedByUser: true
        )
        finding = result.finding
        warped = result.warped
    }
}

private enum AdjustMode { case artwork, edges }

private struct ArtworkBorderEditor: View {
    var image: UIImage
    var insets: BorderInsets
    var onChange: (BorderInsets) -> Void

    var body: some View {
        GeometryReader { geo in
            let fit = aspectFitRect(content: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                insetLine(orientation: .vertical, fraction: insets.left, fit: fit, identifier: "leftBorderHandle") { fraction in
                    var next = insets
                    next.left = fraction
                    onChange(next)
                }
                insetLine(orientation: .vertical, fraction: 1 - insets.right, fit: fit, identifier: "rightBorderHandle") { fraction in
                    var next = insets
                    next.right = 1 - fraction
                    onChange(next)
                }
                insetLine(orientation: .horizontal, fraction: insets.top, fit: fit, identifier: "topBorderHandle") { fraction in
                    var next = insets
                    next.top = fraction
                    onChange(next)
                }
                insetLine(orientation: .horizontal, fraction: 1 - insets.bottom, fit: fit, identifier: "bottomBorderHandle") { fraction in
                    var next = insets
                    next.bottom = 1 - fraction
                    onChange(next)
                }
            }
            .coordinateSpace(name: "artwork")
        }
    }

    private enum LineOrientation { case vertical, horizontal }

    private func insetLine(orientation: LineOrientation, fraction: Double, fit: CGRect, identifier: String, update: @escaping (Double) -> Void) -> some View {
        let x = orientation == .vertical ? fit.minX + fit.width * fraction : fit.midX
        let y = orientation == .horizontal ? fit.minY + fit.height * fraction : fit.midY
        return Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.7), lineWidth: 1))
            .frame(width: 18, height: 18)
            .padding(10)
            .position(x: x, y: y)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(identifier)
            .accessibilityAdjustableAction { direction in
                let delta = direction == .increment ? 0.01 : -0.01
                if orientation == .vertical {
                    update(min(0.95, max(0.02, fraction + delta)))
                } else {
                    update(min(0.95, max(0.02, fraction + delta)))
                }
            }
            .gesture(DragGesture(coordinateSpace: .named("artwork")).onChanged { value in
                if orientation == .vertical {
                    let next = (value.location.x - fit.minX) / max(fit.width, 1)
                    update(next)
                } else {
                    let next = (value.location.y - fit.minY) / max(fit.height, 1)
                    update(next)
                }
            })
    }
}

private struct CardEdgeEditor: View {
    var image: UIImage
    var quad: CardQuad
    var onPreview: (CardQuad) -> Void
    var onCommit: (CardQuad) -> Void

    var body: some View {
        GeometryReader { geo in
            let fit = aspectFitRect(content: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                cornerHandle(quad.topLeft, fit: fit, identifier: "cornerTopLeft") { point in
                    var next = quad
                    next.topLeft = point
                    return next
                }
                cornerHandle(quad.topRight, fit: fit, identifier: "cornerTopRight") { point in
                    var next = quad
                    next.topRight = point
                    return next
                }
                cornerHandle(quad.bottomRight, fit: fit, identifier: "cornerBottomRight") { point in
                    var next = quad
                    next.bottomRight = point
                    return next
                }
                cornerHandle(quad.bottomLeft, fit: fit, identifier: "cornerBottomLeft") { point in
                    var next = quad
                    next.bottomLeft = point
                    return next
                }
            }
            .coordinateSpace(name: "edges")
        }
    }

    private func cornerHandle(_ current: NormPoint, fit: CGRect, identifier: String, update: @escaping (NormPoint) -> CardQuad) -> some View {
        Circle()
            .fill(Color.yellow)
            .overlay(Circle().stroke(Color.black.opacity(0.7), lineWidth: 1))
            .frame(width: 18, height: 18)
            .padding(10)
            .position(x: fit.minX + fit.width * current.x, y: fit.minY + fit.height * current.y)
            .accessibilityIdentifier(identifier)
            .gesture(
                DragGesture(coordinateSpace: .named("edges"))
                    .onChanged { value in
                        onPreview(update(point(from: value.location, fit: fit)))
                    }
                    .onEnded { value in
                        onCommit(update(point(from: value.location, fit: fit)))
                    }
            )
    }

    private func point(from location: CGPoint, fit: CGRect) -> NormPoint {
        NormPoint(
            x: min(1, max(0, (location.x - fit.minX) / max(fit.width, 1))),
            y: min(1, max(0, (location.y - fit.minY) / max(fit.height, 1)))
        )
    }
}
