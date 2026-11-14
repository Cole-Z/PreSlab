# Full-art and borderless centering feasibility

Status: investigation only — unsupported for automatic centering
Reviewed: November 9, 2026

## Decision

PreSlab must continue to leave full-art, alternate-art, borderless, asymmetric, and nonstandard-frame cards unmeasured when it cannot find a stable printed reference. An outer card rectangle alone does not reveal where artwork was intended to sit on the stock.

No support claim should be added by card name, set, rarity, or visual style without a repeatable reference geometry for that design. Manual lines can document a collector-selected visual reference, but that result must remain labeled visual-only and cannot be represented as an official centering measurement. The Phase 5 implementation defaults failed automatic scans to **Visual only** and excludes those ratios from every grading-company comparison. A collector must explicitly select **Printed frame** to assert that a real frame exists but automatic detection missed it.

## Why the current scanner abstains

The current `BorderScanner` expects one stable transition near each card edge. Full-art designs commonly contain texture, foil, text, energy symbols, artwork, or intentional asymmetry in that search region. Selecting the strongest transition can measure an artwork feature rather than a printed frame.

Perspective correction solves camera geometry; it does not create a missing design reference.

## Evidence required before support

1. Define the intended reference for each candidate design family using manufacturer layout evidence or an independently repeatable geometric feature.
2. Assemble at least 30 cards per design family, with duplicate photos under varied lighting and perspective.
3. Establish ground truth without using PreSlab's result.
4. Measure false-reference rate, median error, 95th-percentile error, and repeatability on a holdout set.
5. Demonstrate that unsupported designs abstain instead of receiving a plausible but incorrect ratio.
6. Review wording so a design-relative measurement is not confused with a grading-company rule.

## Potential local-only research paths

- Template registration for a narrowly identified set/design, provided templates can be sourced and licensed locally.
- Symmetry or repeated-layout anchors when the printed design actually supplies them.
- User-defined reference lines saved explicitly as manual observations.
- On-device Vision/Core Image feature matching, evaluated against the same holdout requirements.

These are research options, not roadmap commitments. No hosted inference, card-image upload, pricing service, or CollectorAtlas dependency is required or approved.

## Stop condition

If a design family lacks a defensible intended reference, PreSlab should say that centering cannot be determined for that design. Abstention is the correct product behavior.
