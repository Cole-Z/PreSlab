# Phase 5 completion report

Completed: November 9, 2026
Validation target: physical iPhone only

## Delivered

### Unconventional designs

- Every measured side records automatic printed-frame, manual printed-frame, or user-defined visual-reference provenance.
- A failed automatic frame scan defaults manual lines to **Visual only**.
- Visual-only ratios remain available for collector documentation but are excluded from PSA, BGS, CGC, and TAG comparisons, verdicts, filters, and compatibility claims.
- Unsupported-design and unstable-reference results are called out explicitly.
- Synthetic coverage includes uniform, noisy, and asymmetric artwork transitions.

This completes the approved investigation safely; it does not claim automatic full-art or borderless support.

### Grading economics

- The calculator separately shows raw-card value, submission-only costs, total economic basis, selling fees, proceeds, break-even value, and potential profit/loss.
- Invalid negative, non-finite, and out-of-range fee values are rejected.
- Inputs can be saved locally with an assessment, reopened, displayed in results, and included in the offline PDF.
- No pricing service, scraping, inferred value, or guaranteed grade is used.

### Professional outcomes

- Company, returned grade, submission date, return date, and notes remain local.
- Results show the original front/back centering measurements next to the returned outcome with a non-prediction disclaimer.
- Library rows identify returned outcomes and history can filter assessments with or without an outcome.

### CollectorAtlas investigation

- `CollectorAtlasExportBuilder` creates a versioned local JSON envelope containing assessment metadata, full-precision measurements, provenance, observations, optional outcome, and optional economics.
- Photographs, image paths, device identifiers, accounts, tokens, and network transport are deliberately excluded.
- `collectoratlas-export-contract.md` defines compatibility and future approval gates.
- No live CollectorAtlas integration exists.

## Validation performed

- The complete app type-checks against the arm64 iPhoneOS 26.2 SDK.
- All 68 Swift Testing cases type-check with the Testing macro plugin.
- All 9 XCTest UI-test methods type-check with the iPhoneOS XCTest overlay.
- No simulator was launched.

The Xcode command-line project/device services still terminate before a signed build or test execution, so the physical-iPhone checklist remains the acceptance gate.
