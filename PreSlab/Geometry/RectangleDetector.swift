import Foundation
import Vision

nonisolated enum RectangleDetector {
    /// Largest rectangle near a trading-card aspect ratio. Pokémon cards are
    /// 2.5 by 3.5 inches, so the shorter side is about 0.71 of the longer side.
    static func detect(in image: RGBAImage) -> CardQuad? {
        guard let cgImage = image.cgImage() else { return nil }
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.60
        request.maximumAspectRatio = 0.84
        request.minimumSize = 0.20
        request.maximumObservations = 8
        request.minimumConfidence = 0.4
        request.quadratureTolerance = 35
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let best = (request.results ?? []).max(by: { area($0) < area($1) }) else {
            return nil
        }
        return CardQuad(
            topLeft: imagePoint(best.topLeft),
            topRight: imagePoint(best.topRight),
            bottomRight: imagePoint(best.bottomRight),
            bottomLeft: imagePoint(best.bottomLeft)
        )
    }

    /// Vision's origin is the bottom-left. The rest of the app uses top-left.
    private static func imagePoint(_ point: CGPoint) -> NormPoint {
        NormPoint(x: Double(point.x), y: Double(1 - point.y))
    }

    private static func area(_ observation: VNRectangleObservation) -> CGFloat {
        let box = observation.boundingBox
        return box.width * box.height
    }
}
