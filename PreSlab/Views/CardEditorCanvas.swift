import SwiftUI

/// Only the image and its coordinate transform zoom. Handles remain 48pt
/// touch targets and guides remain thin enough to see the border beneath.
struct CardEditorCanvas<Overlay: View>: View {
    var image: UIImage
    @ViewBuilder var overlay: (CGRect, CGRect, Bool) -> Overlay

    @State private var transform = CardEditorTransform()
    @State private var panStart: CardEditorTransform?
    @State private var pinchStart: CardEditorTransform?
    @State private var panInterrupted = false
    @GestureState private var panning = false
    @GestureState private var pinching = false

    var body: some View {
        GeometryReader { geo in
            let canvasSize = CGSize(width: geo.size.width, height: max(0, geo.size.height - 48))
            let bounds = CGRect(origin: .zero, size: canvasSize)
            let base = fittedRect(in: canvasSize)
            let fit = transform.imageRect(base: base)
            VStack(spacing: 4) {
                ZStack {
                    // A sibling behind the handles owns panning. Dragging a handle
                    // never also drags the image. Decorative layers ignore touches.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(coordinateSpace: .named("cardEditor"))
                            .updating($panning) { _, state, _ in state = true }
                            .onChanged { value in
                                if pinching { panInterrupted = true }
                                guard !panInterrupted else { return }
                                let start = panStart ?? transform
                                panStart = start
                                transform = start.panned(by: value.translation, base: base)
                            }
                            .onEnded { _ in panStart = nil; panInterrupted = false })
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: fit.width, height: fit.height)
                        .position(x: fit.midX, y: fit.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    overlay(fit, bounds, pinching)
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .coordinateSpace(name: "cardEditor")
                .clipped()
                .contentShape(Rectangle())
                .accessibilityIdentifier("cardEditorCanvas")
                .simultaneousGesture(MagnifyGesture()
                    .updating($pinching) { _, state, _ in state = true }
                    .onChanged { value in
                        let start = pinchStart ?? transform
                        pinchStart = start
                        let anchor = CGPoint(x: value.startAnchor.x * canvasSize.width,
                                             y: value.startAnchor.y * canvasSize.height)
                        transform = start.zoomed(to: start.scale * value.magnification, around: anchor, base: base)
                    }
                    .onEnded { _ in pinchStart = nil })
                .onChange(of: panning) { _, active in
                    if !active { panStart = nil; panInterrupted = false }
                }
                .onChange(of: pinching) { _, active in if !active { pinchStart = nil } }
                .onChange(of: geo.size) { _, _ in
                    transform = CardEditorTransform()
                    panStart = nil
                    pinchStart = nil
                }
                controls(base: base)
            }
        }
    }

    private func controls(base: CGRect) -> some View {
        HStack(spacing: 12) {
            Text("Pinch to zoom · Drag photo to pan")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                transform = transform.zoomed(to: transform.scale / 1.5, around: CGPoint(x: base.midX, y: base.midY), base: base)
            } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("Zoom out")
                .accessibilityIdentifier("centeringZoomOut")
                .disabled(transform.scale <= 1)
            Text(String(format: "%.1f×", transform.scale))
                .font(.caption.monospacedDigit())
                .accessibilityIdentifier("centeringZoomLevel")
            Button {
                transform = transform.zoomed(to: transform.scale * 1.5, around: CGPoint(x: base.midX, y: base.midY), base: base)
            } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("Zoom in")
                .accessibilityIdentifier("centeringZoomIn")
                .disabled(transform.scale >= CardEditorTransform.maximumScale)
            Button("Reset") { transform = CardEditorTransform() }
                .font(.caption)
                .accessibilityLabel("Reset zoom")
                .accessibilityIdentifier("centeringResetZoom")
                .disabled(transform.scale == 1)
        }
        .buttonStyle(.borderless)
        .frame(minHeight: 44)
        .background(.background)
    }

    private func fittedRect(in size: CGSize) -> CGRect {
        let padded = CGRect(origin: .zero, size: size).insetBy(dx: 36, dy: 36)
        guard padded.width > 0, padded.height > 0 else { return .zero }
        let fit = aspectFitRect(content: image.size, in: padded.size)
        return fit.offsetBy(dx: padded.minX, dy: padded.minY)
    }
}
