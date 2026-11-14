import Foundation
import UIKit

@MainActor
enum AssessmentPDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 36

    static func writePDF(
        cardName: String,
        createdAt: Date,
        front: SideFinding,
        back: SideFinding,
        frontImage: UIImage?,
        backImage: UIImage?,
        checklist: ConditionChecklist,
        outcome: ProfessionalGradingOutcome? = nil,
        costs: GradingCostInputs? = nil
    ) throws -> URL {
        let data = pdfData(
            cardName: cardName,
            createdAt: createdAt,
            front: front,
            back: back,
            frontImage: frontImage,
            backImage: backImage,
            checklist: checklist,
            outcome: outcome,
            costs: costs
        )
        let safeName = sanitizedFileName(cardName)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-PreSlab-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func pdfData(
        cardName: String,
        createdAt: Date,
        front: SideFinding,
        back: SideFinding,
        frontImage: UIImage?,
        backImage: UIImage?,
        checklist: ConditionChecklist,
        outcome: ProfessionalGradingOutcome? = nil,
        costs: GradingCostInputs? = nil
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            context.beginPage()
            fillPageBackground()
            drawOverview(
                cardName: cardName,
                createdAt: createdAt,
                front: front,
                back: back,
                frontImage: frontImage,
                backImage: backImage,
                outcome: outcome,
                costs: costs
            )
            let hasConditionNotes = CardSide.allCases.contains {
                !checklist.recordedObservations(side: $0).isEmpty
            }
            if hasConditionNotes {
                context.beginPage()
                fillPageBackground()
                drawConditionChecklist(checklist, cardName: cardName)
            }
        }
    }

    private static func drawOverview(
        cardName: String,
        createdAt: Date,
        front: SideFinding,
        back: SideFinding,
        frontImage: UIImage?,
        backImage: UIImage?,
        outcome: ProfessionalGradingOutcome?,
        costs: GradingCostInputs?
    ) {
        var y = margin
        y += drawText(cardName, at: y, font: .boldSystemFont(ofSize: 24), color: .black)
        y += drawText("PreSlab centering assessment", at: y + 2, font: .systemFont(ofSize: 15), color: .darkGray)
        y += drawText(createdAt.formatted(date: .long, time: .shortened), at: y + 2, font: .systemFont(ofSize: 11), color: .darkGray)

        y += 12
        y += drawText(measurementLine("Front", finding: front), at: y, font: .monospacedSystemFont(ofSize: 12, weight: .medium), color: .black)
        y += drawText(measurementLine("Back", finding: back), at: y + 2, font: .monospacedSystemFont(ofSize: 12, weight: .medium), color: .black)

        let imageTop = y + 14
        let imageWidth = (page.width - margin * 2 - 18) / 2
        let imageHeight: CGFloat = 280
        drawImage(frontImage, title: "Front", in: CGRect(x: margin, y: imageTop, width: imageWidth, height: imageHeight))
        drawImage(backImage, title: "Back", in: CGRect(x: margin + imageWidth + 18, y: imageTop, width: imageWidth, height: imageHeight))

        y = imageTop + imageHeight + 20
        y += drawText("Published centering compatibility", at: y, font: .boldSystemFont(ofSize: 14), color: .black)
        for grader in GraderProfile.allCases {
            let comparison = CenteringComparisonEngine.evaluate(
                grader: grader,
                category: .tcg,
                frontFinding: front,
                backFinding: back
            )
            let line: String
            if let compatible = comparison.highestCompatible {
                line = "\(grader.title): \(compatible.row.gradeLabel) centering baseline fits"
            } else {
                line = "\(grader.title): no published baseline confirmed"
            }
            y += drawText(line, at: y + 2, font: .systemFont(ofSize: 11), color: .black)
        }

        if let outcome {
            let company = outcome.company.isEmpty ? "Professional grader" : outcome.company
            let grade = outcome.gradeReceived.isEmpty ? "grade not entered" : outcome.gradeReceived
            y += drawText("Recorded outcome: \(company) \(grade)", at: y + 10, font: .boldSystemFont(ofSize: 11), color: .black)
        }

        if let costs {
            y += drawText("Saved economics: submission costs \(currency(costs.submissionCosts)); total basis \(currency(costs.totalInvestment)); potential P/L \(currency(costs.potentialProfitOrLoss))", at: y + 8, font: .systemFont(ofSize: 10), color: .black)
        }

        _ = drawText(
            "Centering compatibility is not a professional grade. Corners, edges, surface, print quality, authenticity, alterations, and grader discretion can change the final result.",
            at: y + 14,
            font: .systemFont(ofSize: 10),
            color: .darkGray
        )
    }

    private static func drawConditionChecklist(_ checklist: ConditionChecklist, cardName: String) {
        var y = margin
        y += drawText("\(cardName) — condition observations", at: y, font: .boldSystemFont(ofSize: 20), color: .black)
        y += drawText("Collector-entered observations only; not an automated or professional grade.", at: y + 4, font: .systemFont(ofSize: 11), color: .darkGray)
        for side in CardSide.allCases {
            y += 16
            y += drawText(side.title, at: y, font: .boldSystemFont(ofSize: 15), color: .black)
            for (item, state) in checklist.recordedObservations(side: side) {
                y += drawText("\(item.category.title) · \(item.title): \(state.title)", at: y + 3, font: .systemFont(ofSize: 11), color: .black)
            }
        }
    }

    private static func measurementLine(_ label: String, finding: SideFinding) -> String {
        guard let ratios = finding.ratios else { return "\(label): not measured" }
        let source = finding.measurementBasis?.title ?? (finding.adjustedByUser ? "manual" : "automatic")
        return "\(label): L/R \(ratios.horizontalText) · T/B \(ratios.verticalText) · \(source)"
    }

    private static func drawImage(_ image: UIImage?, title: String, in bounds: CGRect) {
        drawText(title, x: bounds.minX, width: bounds.width, at: bounds.minY, font: .boldSystemFont(ofSize: 12), color: .black)
        let photoBounds = CGRect(x: bounds.minX, y: bounds.minY + 18, width: bounds.width, height: bounds.height - 18)
        guard let image else {
            drawText("No image", x: photoBounds.minX, width: photoBounds.width, at: photoBounds.midY, font: .systemFont(ofSize: 11), color: .darkGray)
            return
        }
        let scale = min(photoBounds.width / image.size.width, photoBounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = CGRect(x: photoBounds.midX - size.width / 2, y: photoBounds.midY - size.height / 2, width: size.width, height: size.height)
        image.draw(in: rect)
    }

    @discardableResult
    private static func drawText(_ text: String, x: CGFloat = 36, width: CGFloat = 540, at y: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let height = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height.rounded(.up)
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: height), withAttributes: attributes)
        return height
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Assessment" : String(result.prefix(60))
    }

    private static func fillPageBackground() {
        UIColor.white.setFill()
        UIRectFill(page)
    }

    private static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
