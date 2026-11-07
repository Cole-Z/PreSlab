import CoreGraphics
import Foundation

/// Maps one plane to another. `h` is row-major 3×3 with the last element normalized to 1.
nonisolated struct Homography: Sendable, Equatable {
    var h: [Double]

    func apply(x: Double, y: Double) -> (Double, Double)? {
        let denominator = h[6] * x + h[7] * y + h[8]
        guard abs(denominator) > 1e-10 else { return nil }
        return ((h[0] * x + h[1] * y + h[2]) / denominator,
                (h[3] * x + h[4] * y + h[5]) / denominator)
    }

    /// Direct linear transform with Hartley normalization, so pixel-sized
    /// coordinates do not swamp the solver.
    static func mapping(from source: [(Double, Double)], to destination: [(Double, Double)]) -> Homography? {
        guard source.count == 4, destination.count == 4 else { return nil }
        let srcNorm = PointNormalizer(source)
        let dstNorm = PointNormalizer(destination)
        let src = source.map { srcNorm.apply($0) }
        let dst = destination.map { dstNorm.apply($0) }

        var matrix = Array(repeating: Array(repeating: 0.0, count: 8), count: 8)
        var rhs = Array(repeating: 0.0, count: 8)
        for index in 0..<4 {
            let (x, y) = src[index]
            let (u, v) = dst[index]
            let row = index * 2
            matrix[row] = [x, y, 1, 0, 0, 0, -u * x, -u * y]
            rhs[row] = u
            matrix[row + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y]
            rhs[row + 1] = v
        }
        guard let solved = LinearSolver.solve(matrix, rhs) else { return nil }
        let normalized = [
            [solved[0], solved[1], solved[2]],
            [solved[3], solved[4], solved[5]],
            [solved[6], solved[7], 1.0],
        ]
        let composed = matmul(dstNorm.inverse, matmul(normalized, srcNorm.forward))
        guard abs(composed[2][2]) > 1e-12 else { return nil }
        let scale = composed[2][2]
        return Homography(h: composed.flatMap { row in row.map { $0 / scale } })
    }
}

nonisolated struct PointNormalizer: Sendable {
    var forward: [[Double]]
    var inverse: [[Double]]

    init(_ points: [(Double, Double)]) {
        let count = Double(points.count)
        let cx = points.map(\.0).reduce(0, +) / count
        let cy = points.map(\.1).reduce(0, +) / count
        let meanDistance = points.map { hypot($0.0 - cx, $0.1 - cy) }.reduce(0, +) / count
        let scale = meanDistance < 1e-9 ? 1 : (2.0.squareRoot() / meanDistance)
        let tx = -cx * scale
        let ty = -cy * scale
        forward = [[scale, 0, tx], [0, scale, ty], [0, 0, 1]]
        let inverseScale = 1 / scale
        inverse = [[inverseScale, 0, -tx * inverseScale], [0, inverseScale, -ty * inverseScale], [0, 0, 1]]
    }

    func apply(_ point: (Double, Double)) -> (Double, Double) {
        (forward[0][0] * point.0 + forward[0][2], forward[1][1] * point.1 + forward[1][2])
    }
}

nonisolated enum LinearSolver {
    static func solve(_ matrix: [[Double]], _ rhs: [Double]) -> [Double]? {
        let n = rhs.count
        var a = matrix
        var b = rhs
        for column in 0..<n {
            var pivot = column
            var best = abs(a[column][column])
            for row in (column + 1)..<n where abs(a[row][column]) > best {
                best = abs(a[row][column])
                pivot = row
            }
            if best < 1e-12 { return nil }
            if pivot != column {
                a.swapAt(pivot, column)
                b.swapAt(pivot, column)
            }
            let divisor = a[column][column]
            for index in column..<n { a[column][index] /= divisor }
            b[column] /= divisor
            for row in 0..<n where row != column {
                let factor = a[row][column]
                if factor == 0 { continue }
                for index in column..<n {
                    a[row][index] -= factor * a[column][index]
                }
                b[row] -= factor * b[column]
            }
        }
        return b
    }
}

nonisolated func matmul(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
    var result = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
    for row in 0..<3 {
        for column in 0..<3 {
            result[row][column] = a[row][0] * b[0][column] + a[row][1] * b[1][column] + a[row][2] * b[2][column]
        }
    }
    return result
}

nonisolated enum CardWarp {
    static let canonicalWidth = 750
    static let canonicalHeight = 1050

    /// Pulls the quadrilateral in `image` into a flat 2.5:3.5 card.
    static func flatten(_ image: RGBAImage, quad: CardQuad, width: Int = canonicalWidth, height: Int = canonicalHeight) -> RGBAImage? {
        let destination = quad.pixelPoints(width: image.width, height: image.height)
            .map { (Double($0.x), Double($0.y)) }
        let source: [(Double, Double)] = [
            (0, 0),
            (Double(width - 1), 0),
            (Double(width - 1), Double(height - 1)),
            (0, Double(height - 1)),
        ]
        guard let homography = Homography.mapping(from: source, to: destination) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                guard let sample = homography.apply(x: Double(x), y: Double(y)) else { return nil }
                let color = bilinear(image, sample.0, sample.1)
                let index = (y * width + x) * 4
                pixels[index] = color.0
                pixels[index + 1] = color.1
                pixels[index + 2] = color.2
                pixels[index + 3] = color.3
            }
        }
        return RGBAImage(width: width, height: height, pixels: pixels)
    }

    /// Paints `card` into a new image so that the card's corners land on `quad`.
    /// Tests use this to build a known perspective photo.
    static func composite(card: RGBAImage, canvasWidth: Int, canvasHeight: Int, quad: CardQuad, background: (UInt8, UInt8, UInt8) = (28, 28, 32)) -> RGBAImage? {
        let canvasCorners = quad.pixelPoints(width: canvasWidth, height: canvasHeight)
            .map { (Double($0.x), Double($0.y)) }
        let cardCorners: [(Double, Double)] = [
            (0, 0),
            (Double(card.width - 1), 0),
            (Double(card.width - 1), Double(card.height - 1)),
            (0, Double(card.height - 1)),
        ]
        guard let homography = Homography.mapping(from: canvasCorners, to: cardCorners) else { return nil }
        var pixels = [UInt8](repeating: 0, count: canvasWidth * canvasHeight * 4)
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let color: (UInt8, UInt8, UInt8, UInt8)
                if let sample = homography.apply(x: Double(x), y: Double(y)),
                   sample.0 >= -0.5, sample.1 >= -0.5,
                   sample.0 <= Double(card.width) - 0.5, sample.1 <= Double(card.height) - 0.5 {
                    color = bilinear(card, sample.0, sample.1)
                } else {
                    color = (background.0, background.1, background.2, 255)
                }
                let index = (y * canvasWidth + x) * 4
                pixels[index] = color.0
                pixels[index + 1] = color.1
                pixels[index + 2] = color.2
                pixels[index + 3] = color.3
            }
        }
        return RGBAImage(width: canvasWidth, height: canvasHeight, pixels: pixels)
    }

    private static func bilinear(_ image: RGBAImage, _ x: Double, _ y: Double) -> (UInt8, UInt8, UInt8, UInt8) {
        let maxX = Double(image.width - 1)
        let maxY = Double(image.height - 1)
        let clampedX = min(max(x, 0), maxX)
        let clampedY = min(max(y, 0), maxY)
        let x0 = Int(clampedX)
        let y0 = Int(clampedY)
        let x1 = min(x0 + 1, image.width - 1)
        let y1 = min(y0 + 1, image.height - 1)
        let tx = Float(clampedX - Double(x0))
        let ty = Float(clampedY - Double(y0))
        let p00 = image.pixel(x0, y0)
        let p10 = image.pixel(x1, y0)
        let p01 = image.pixel(x0, y1)
        let p11 = image.pixel(x1, y1)
        func channel(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt8 {
            let top = Float(a) + (Float(b) - Float(a)) * tx
            let bottom = Float(c) + (Float(d) - Float(c)) * tx
            return UInt8(min(255, max(0, top + (bottom - top) * ty)))
        }
        return (channel(p00.0, p10.0, p01.0, p11.0),
                channel(p00.1, p10.1, p01.1, p11.1),
                channel(p00.2, p10.2, p01.2, p11.2),
                255)
    }
}
