import Foundation

nonisolated enum GraderProfile: String, CaseIterable, Identifiable, Sendable {
    case psa, bgs, cgc, tag
    var id: String { rawValue }
    var title: String {
        switch self {
        case .psa: "PSA"
        case .bgs: "BGS"
        case .cgc: "CGC"
        case .tag: "TAG"
        }
    }
    var sourceURL: URL {
        switch self {
        case .psa: URL(string: "https://www.psacard.com/gradingstandards#cards")!
        case .bgs: URL(string: "https://beckett.com/grading")!
        case .cgc: URL(string: "https://www.cgccards.com/card-grading/grading-scale/?scale=standard")!
        case .tag: URL(string: "https://taggrading.com/pages/rubric")!
        }
    }
}

nonisolated enum CardCategory: String, CaseIterable, Identifiable, Sendable {
    case tcg, sports
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tcg: "TCG"
        case .sports: "Sports / non-sports"
        }
    }
    var mattersForGrader: Bool { true }
}

nonisolated enum FaceThreshold: Equatable, Sendable {
    case numeric(maxImbalance: Double, approximate: Bool)
    case sliver
    case notPublished
    case qualitative(String)

    var numericLimit: Double? {
        if case .numeric(let v, _) = self { return v }
        return nil
    }
    var isSliver: Bool { if case .sliver = self { return true }; return false }
    var qualitativeText: String? {
        if case .qualitative(let text) = self { return text }
        return nil
    }
    var isPublished: Bool {
        switch self {
        case .numeric, .sliver: true
        case .notPublished, .qualitative: false
        }
    }
}

nonisolated struct CenteringStandardRow: Identifiable, Equatable, Sendable {
    var id: String
    var grader: GraderProfile
    var category: CardCategory?
    var gradeLabel: String
    var gradeValue: Double
    var front: FaceThreshold
    var back: FaceThreshold
    /// When front/back scope is not separately published (CGC), this holds the literal statement.
    var sharedLimit: Double?
    var sharedScopeUnresolved: Bool
    var scoreBand: String?
    var note: String?

    init(grader: GraderProfile, category: CardCategory? = nil, gradeLabel: String, gradeValue: Double,
         front: FaceThreshold, back: FaceThreshold, sharedLimit: Double? = nil,
         sharedScopeUnresolved: Bool = false, scoreBand: String? = nil, note: String? = nil) {
        self.id = "\(grader.rawValue)-\(category?.rawValue ?? "any")-\(gradeLabel)"
        self.grader = grader
        self.category = category
        self.gradeLabel = gradeLabel
        self.gradeValue = gradeValue
        self.front = front
        self.back = back
        self.sharedLimit = sharedLimit
        self.sharedScopeUnresolved = sharedScopeUnresolved
        self.scoreBand = scoreBand
        self.note = note
    }
}

nonisolated enum CenteringStandards {
    static let version = "2026-11-09"
    static let checkedDate = "November 9, 2026"
    static let resultLabel = "Highest published baseline-compatible centering guideline"
    static let disclaimer = "Centering fits the published baseline below; this is not an overall grade prediction. Corners, edges, surface, and other factors are independent."

    static func rows(grader: GraderProfile, category: CardCategory) -> [CenteringStandardRow] {
        switch grader {
        case .psa: psaRows
        case .bgs: bgsRows
        case .cgc: category == .tcg ? cgcTCGRows : cgcSportsRows
        case .tag: category == .tcg ? tagTCGRows : tagSportsRows
        }
    }

    private static func n(_ v: Double, approx: Bool = false) -> FaceThreshold { .numeric(maxImbalance: v, approximate: approx) }
    private static let np: FaceThreshold = .notPublished

    // MARK: PSA — sources P, P-data (see docs/centering-standards.md §3)
    static let psaRows: [CenteringStandardRow] = [
        .init(grader: .psa, gradeLabel: "10 Gem Mint", gradeValue: 10, front: n(55, approx: true), back: n(75)),
        .init(grader: .psa, gradeLabel: "9 Mint", gradeValue: 9, front: n(60, approx: true), back: n(90)),
        .init(grader: .psa, gradeLabel: "8.5", gradeValue: 8.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "8 NM-MT", gradeValue: 8, front: n(65, approx: true), back: n(90)),
        .init(grader: .psa, gradeLabel: "7.5", gradeValue: 7.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "7 NM", gradeValue: 7, front: n(70, approx: true), back: n(90)),
        .init(grader: .psa, gradeLabel: "6.5", gradeValue: 6.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "6 EX-MT", gradeValue: 6, front: n(80), back: n(90)),
        .init(grader: .psa, gradeLabel: "5.5", gradeValue: 5.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "5 EX", gradeValue: 5, front: n(85), back: n(90)),
        .init(grader: .psa, gradeLabel: "4.5", gradeValue: 4.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "4 VG-EX", gradeValue: 4, front: n(85), back: n(90)),
        .init(grader: .psa, gradeLabel: "3.5", gradeValue: 3.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "3 VG", gradeValue: 3, front: n(90), back: n(90)),
        .init(grader: .psa, gradeLabel: "2.5", gradeValue: 2.5, front: np, back: np, note: "No separately published numerical centering threshold."),
        .init(grader: .psa, gradeLabel: "2 Good", gradeValue: 2, front: n(90), back: n(90)),
        .init(grader: .psa, gradeLabel: "1.5 Fair", gradeValue: 1.5, front: n(90, approx: true), back: n(90, approx: true)),
        .init(grader: .psa, gradeLabel: "1 Poor", gradeValue: 1, front: np, back: np),
    ]

    // MARK: BGS — sources B, B-data (§4). Not BVG/BCCG.
    static let bgsRows: [CenteringStandardRow] = [
        .init(grader: .bgs, gradeLabel: "10 Pristine", gradeValue: 10, front: n(50), back: n(55), note: "This is centering compatibility only. Centering cannot distinguish Black Label from Gold Label or establish either overall label."),
        .init(grader: .bgs, gradeLabel: "9.5 Gem Mint", gradeValue: 9.5, front: n(55), back: n(60)),
        .init(grader: .bgs, gradeLabel: "9 Mint", gradeValue: 9, front: n(55), back: n(70)),
        .init(grader: .bgs, gradeLabel: "8.5", gradeValue: 8.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "8 NM-MT", gradeValue: 8, front: n(60), back: n(80)),
        .init(grader: .bgs, gradeLabel: "7.5", gradeValue: 7.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "7 NM", gradeValue: 7, front: n(65), back: n(90), note: "Diamond cut: very slight allowed (qualitative)."),
        .init(grader: .bgs, gradeLabel: "6.5", gradeValue: 6.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "6 EX-MT", gradeValue: 6, front: n(70), back: n(95), note: "Diamond cut: slight allowed (qualitative)."),
        .init(grader: .bgs, gradeLabel: "5.5", gradeValue: 5.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "5 EX", gradeValue: 5, front: n(75), back: n(95), note: "Diamond cut: slight allowed (qualitative)."),
        .init(grader: .bgs, gradeLabel: "4.5", gradeValue: 4.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "4 VG-EX", gradeValue: 4, front: n(80), back: n(100), note: "Diamond cut: moderate allowed (qualitative). Back published as 100/0."),
        .init(grader: .bgs, gradeLabel: "3.5", gradeValue: 3.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "3 VG", gradeValue: 3, front: n(85), back: n(100), note: "Diamond cut: moderate allowed (qualitative). Back published as 100/0."),
        .init(grader: .bgs, gradeLabel: "2.5", gradeValue: 2.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "2 Good", gradeValue: 2, front: n(90), back: n(100), note: "Diamond cut: noticeable allowed (qualitative). Back: 100/0 or offcut."),
        .init(grader: .bgs, gradeLabel: "1.5", gradeValue: 1.5, front: np, back: np, note: "No separately published numerical centering threshold. Do not interpolate."),
        .init(grader: .bgs, gradeLabel: "1 Poor", gradeValue: 1, front: .qualitative("100/0 or offcut on front or back (combined)"), back: .qualitative("Combined front-or-back statement"), note: "Combined face wording requires interpretation review; not two independent thresholds. Diamond cut: heavy allowed."),
    ]

    // MARK: CGC (§5)
    private static var cgcTop: [CenteringStandardRow] {
        [
            .init(grader: .cgc, gradeLabel: "Pristine 10", gradeValue: 10.5, front: np, back: np, sharedLimit: 50, sharedScopeUnresolved: true, note: "Published: “The centering is 50/50.” Face scope not separately specified — do not invent a back requirement."),
            .init(grader: .cgc, gradeLabel: "Gem Mint 10", gradeValue: 10, front: n(55, approx: true), back: n(75)),
            .init(grader: .cgc, gradeLabel: "Mint+ 9.5", gradeValue: 9.5, front: .qualitative("Exceptional centering / eye appeal"), back: .qualitative("Exceptional centering / eye appeal"), note: "Qualitative only; no numerical threshold."),
        ]
    }

    static var cgcTCGRows: [CenteringStandardRow] {
        cgcTop + [
            .init(grader: .cgc, category: .tcg, gradeLabel: "9", gradeValue: 9, front: np, back: np, note: "No numerical TCG ratio published. Sports/non-sports numbers do not apply automatically to TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "8.5", gradeValue: 8.5, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "8", gradeValue: 8, front: np, back: np, note: "Sports/non-sports ratio omitted intentionally for TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "7.5", gradeValue: 7.5, front: np, back: np, note: "Sports/non-sports ratio omitted intentionally for TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "7", gradeValue: 7, front: np, back: np, note: "Sports/non-sports ratio omitted intentionally for TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "6.5", gradeValue: 6.5, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "6", gradeValue: 6, front: np, back: np, note: "Sports/non-sports ratio omitted intentionally for TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "5.5", gradeValue: 5.5, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "5", gradeValue: 5, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "4.5", gradeValue: 4.5, front: np, back: np, note: "Sports/non-sports ratio omitted intentionally for TCG."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "4", gradeValue: 4, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "3.5", gradeValue: 3.5, front: np, back: np, sharedLimit: 90, sharedScopeUnresolved: true, note: "“May have 90/10 centering” — face scope unspecified."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "3", gradeValue: 3, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "2.5", gradeValue: 2.5, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "2", gradeValue: 2, front: np, back: np),
            .init(grader: .cgc, category: .tcg, gradeLabel: "1.5", gradeValue: 1.5, front: np, back: np, note: "The card may be miscut (qualitative)."),
            .init(grader: .cgc, category: .tcg, gradeLabel: "1", gradeValue: 1, front: np, back: np),
        ]
    }

    static var cgcSportsRows: [CenteringStandardRow] {
        cgcTop + [
            .init(grader: .cgc, category: .sports, gradeLabel: "9", gradeValue: 9, front: n(60), back: n(90)),
            .init(grader: .cgc, category: .sports, gradeLabel: "8.5", gradeValue: 8.5, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "8", gradeValue: 8, front: np, back: np, sharedLimit: 65, sharedScopeUnresolved: true, note: "Published 65/35 or better; separate back figure and face scope not explicitly repeated."),
            .init(grader: .cgc, category: .sports, gradeLabel: "7.5", gradeValue: 7.5, front: np, back: np, sharedLimit: 65, sharedScopeUnresolved: true, note: "Published 65/35 allowed; face scope unresolved."),
            .init(grader: .cgc, category: .sports, gradeLabel: "7", gradeValue: 7, front: np, back: np, sharedLimit: 70, sharedScopeUnresolved: true, note: "Published 70/30 or better; face scope unresolved."),
            .init(grader: .cgc, category: .sports, gradeLabel: "6.5", gradeValue: 6.5, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "6", gradeValue: 6, front: np, back: np, sharedLimit: 75, sharedScopeUnresolved: true, note: "Published no worse than 75/25; face scope unresolved."),
            .init(grader: .cgc, category: .sports, gradeLabel: "5.5", gradeValue: 5.5, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "5", gradeValue: 5, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "4.5", gradeValue: 4.5, front: np, back: np, sharedLimit: 85, sharedScopeUnresolved: true, note: "Published 85/15; face scope unresolved."),
            .init(grader: .cgc, category: .sports, gradeLabel: "4", gradeValue: 4, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "3.5", gradeValue: 3.5, front: np, back: np, sharedLimit: 90, sharedScopeUnresolved: true, note: "“May have 90/10 centering” — face scope unspecified."),
            .init(grader: .cgc, category: .sports, gradeLabel: "3", gradeValue: 3, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "2.5", gradeValue: 2.5, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "2", gradeValue: 2, front: np, back: np),
            .init(grader: .cgc, category: .sports, gradeLabel: "1.5", gradeValue: 1.5, front: np, back: np, note: "The card may be miscut (qualitative)."),
            .init(grader: .cgc, category: .sports, gradeLabel: "1", gradeValue: 1, front: np, back: np),
        ]
    }

    // MARK: TAG (§6) — SLIVER is qualitative, never 100/0.
    private static func tagRow(_ label: String, _ v: Double, _ band: String, _ f: FaceThreshold, _ b: FaceThreshold, category: CardCategory) -> CenteringStandardRow {
        .init(grader: .tag, category: category, gradeLabel: label, gradeValue: v, front: f, back: b, scoreBand: band, note: "Overall TAG score band \(band) maps overall score to grade; it is not a centering score.")
    }

    static var tagSportsRows: [CenteringStandardRow] {
        let c = CardCategory.sports; let s: FaceThreshold = .sliver
        return [
            tagRow("Pristine 10", 10.5, "990–1000", n(51, approx: true), n(54.5, approx: true), category: c),
            tagRow("Gem Mint 10", 10, "950–989", n(55, approx: true), n(70, approx: true), category: c),
            tagRow("9", 9, "900–949", n(60, approx: true), n(90, approx: true), category: c),
            tagRow("8.5", 8.5, "850–899", n(62.5, approx: true), n(95, approx: true), category: c),
            tagRow("8", 8, "800–849", n(65, approx: true), s, category: c),
            tagRow("7.5", 7.5, "750–799", n(67.5, approx: true), s, category: c),
            tagRow("7", 7, "700–749", n(70, approx: true), s, category: c),
            tagRow("6.5", 6.5, "650–699", n(72.5, approx: true), s, category: c),
            tagRow("6", 6, "600–649", n(75, approx: true), s, category: c),
            tagRow("5.5", 5.5, "550–599", n(77.5, approx: true), s, category: c),
            tagRow("5", 5, "500–549", n(80, approx: true), s, category: c),
            tagRow("4.5", 4.5, "450–499", n(82.5, approx: true), s, category: c),
            tagRow("4", 4, "400–449", n(85, approx: true), s, category: c),
            tagRow("3.5", 3.5, "350–399", n(87.5, approx: true), s, category: c),
            tagRow("3", 3, "300–349", n(90, approx: true), s, category: c),
            tagRow("2.5", 2.5, "250–299", n(92.5, approx: true), s, category: c),
            tagRow("2", 2, "200–249", n(95, approx: true), s, category: c),
            tagRow("1.5", 1.5, "150–199", n(98.33, approx: true), s, category: c),
            tagRow("1", 1, "100–149", s, s, category: c),
        ]
    }

    static var tagTCGRows: [CenteringStandardRow] {
        let c = CardCategory.tcg; let s: FaceThreshold = .sliver
        return [
            tagRow("Pristine 10", 10.5, "990–1000", n(51, approx: true), n(52, approx: true), category: c),
            tagRow("Gem Mint 10", 10, "950–989", n(55, approx: true), n(65, approx: true), category: c),
            tagRow("9", 9, "900–949", n(60, approx: true), n(75, approx: true), category: c),
            tagRow("8.5", 8.5, "850–899", n(62.5, approx: true), n(85, approx: true), category: c),
            tagRow("8", 8, "800–849", n(65, approx: true), n(95, approx: true), category: c),
            tagRow("7.5", 7.5, "750–799", n(67.5, approx: true), s, category: c),
            tagRow("7", 7, "700–749", n(70, approx: true), s, category: c),
            tagRow("6.5", 6.5, "650–699", n(72.5, approx: true), s, category: c),
            tagRow("6", 6, "600–649", n(75, approx: true), s, category: c),
            tagRow("5.5", 5.5, "550–599", n(77.5, approx: true), s, category: c),
            tagRow("5", 5, "500–549", n(80, approx: true), s, category: c),
            tagRow("4.5", 4.5, "450–499", n(82.5, approx: true), s, category: c),
            tagRow("4", 4, "400–449", n(85, approx: true), s, category: c),
            tagRow("3.5", 3.5, "350–399", n(87.5, approx: true), s, category: c),
            tagRow("3", 3, "300–349", n(90, approx: true), s, category: c),
            tagRow("2.5", 2.5, "250–299", n(92.5, approx: true), s, category: c),
            tagRow("2", 2, "200–249", n(95, approx: true), s, category: c),
            tagRow("1.5", 1.5, "150–199", n(98.33, approx: true), s, category: c),
            tagRow("1", 1, "100–149", s, s, category: c),
        ]
    }
}
