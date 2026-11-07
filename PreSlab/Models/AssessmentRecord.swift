import Foundation
import SwiftData

@Model
final class AssessmentRecord {
    var id: UUID
    var createdAt: Date
    var frontFileName: String
    var backFileName: String
    var frontJSON: Data
    var backJSON: Data
    var isSample: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        frontFileName: String,
        backFileName: String,
        frontJSON: Data,
        backJSON: Data,
        isSample: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.frontFileName = frontFileName
        self.backFileName = backFileName
        self.frontJSON = frontJSON
        self.backJSON = backJSON
        self.isSample = isSample
    }

    var frontFinding: SideFinding {
        (try? JSONDecoder().decode(SideFinding.self, from: frontJSON)) ?? .empty
    }

    var backFinding: SideFinding {
        (try? JSONDecoder().decode(SideFinding.self, from: backJSON)) ?? .empty
    }
}
