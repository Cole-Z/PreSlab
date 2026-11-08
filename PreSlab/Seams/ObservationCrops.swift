import Foundation
import UIKit

/// Builds the labeled crops a future observation model would inspect.
/// Pure geometry plus JPEG encoding; no network, no model, no key.
nonisolated enum ObservationCropBuilder {
    /// Nine crops: four corners, four edge midpoints, and the center.
    /// The center covers surface wear a corner-only set would miss.
    static func build(from warped: RGBAImage) -> [ObservationCrop] {
        buildRegions(from: warped, prefix: "")
    }

    static func buildRegions(from warped: RGBAImage, prefix: String) -> [ObservationCrop] {
        let width = Double(warped.width)
        let height = Double(warped.height)
        let corner = min(width, height) * 0.30
        let strip = min(width, height) * 0.20
        let middle = min(width, height) * 0.40
        let specs: [(String, CGRect)] = [
            ("topLeft", CGRect(x: 0, y: 0, width: corner, height: corner)),
            ("topRight", CGRect(x: width - corner, y: 0, width: corner, height: corner)),
            ("bottomRight", CGRect(x: width - corner, y: height - corner, width: corner, height: corner)),
            ("bottomLeft", CGRect(x: 0, y: height - corner, width: corner, height: corner)),
            ("topEdge", CGRect(x: width / 2 - corner / 2, y: 0, width: corner, height: strip)),
            ("rightEdge", CGRect(x: width - strip, y: height / 2 - corner / 2, width: strip, height: corner)),
            ("bottomEdge", CGRect(x: width / 2 - corner / 2, y: height - strip, width: corner, height: strip)),
            ("leftEdge", CGRect(x: 0, y: height / 2 - corner / 2, width: strip, height: corner)),
            ("center", CGRect(x: width / 2 - middle / 2, y: height / 2 - middle / 2, width: middle, height: middle)),
        ]
        var crops: [ObservationCrop] = []
        for (region, rect) in specs {
            guard let cut = crop(warped, to: rect),
                  let jpeg = ImageCoding.uiImage(from: cut)?.jpegData(compressionQuality: 0.8),
                  !jpeg.isEmpty
            else { continue }
            crops.append(ObservationCrop(region: prefix + region, jpeg: jpeg))
        }
        return crops
    }

    private static func crop(_ image: RGBAImage, to rect: CGRect) -> RGBAImage? {
        let x0 = max(0, Int(rect.minX.rounded(.down)))
        let y0 = max(0, Int(rect.minY.rounded(.down)))
        let x1 = min(image.width, Int(rect.maxX.rounded(.up)))
        let y1 = min(image.height, Int(rect.maxY.rounded(.up)))
        guard x1 - x0 >= 8, y1 - y0 >= 8 else { return nil }
        var pixels = [UInt8](repeating: 0, count: (x1 - x0) * (y1 - y0) * 4)
        for y in y0..<y1 {
            for x in x0..<x1 {
                let source = ((y * image.width) + x) * 4
                let target = (((y - y0) * (x1 - x0)) + (x - x0)) * 4
                pixels[target] = image.pixels[source]
                pixels[target + 1] = image.pixels[source + 1]
                pixels[target + 2] = image.pixels[source + 2]
                pixels[target + 3] = image.pixels[source + 3]
            }
        }
        return RGBAImage(width: x1 - x0, height: y1 - y0, pixels: pixels)
    }
}

/// Dev-only stand-in behind the `ConditionObserver` seam. Returns one canned
/// observation per crop so the crop pipeline runs end to end without a
/// network call, a key, or spend. Never treat its statements as model output.
nonisolated struct StubConditionObserver: ConditionObserver {
    func observe(crops: [ObservationCrop]) async throws -> [ConditionObservation] {
        crops.map { crop in
            ConditionObservation(
                region: crop.region,
                statement: "Stub observation for \(crop.region). No model looked at this crop.",
                limitation: "Everything: a stub cannot see wear, print defects, glare, or alterations."
            )
        }
    }
}
