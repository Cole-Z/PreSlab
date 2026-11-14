# Proposed PreSlab → CollectorAtlas local export contract

Status: investigation complete; no live integration
Format identifier: `preslab.collectoratlas.assessment`
Format version: `1`
Reviewed: November 9, 2026

## Boundary

PreSlab does not connect to CollectorAtlas, create an account, upload images, or require a backend. `CollectorAtlasExportBuilder` defines a local JSON envelope so a future integration can be reviewed without coupling the current application to another service.

No import endpoint, URL scheme, authentication mechanism, or network transport is approved by this document.

## Version 1 contents

- Stable format identifier and integer schema version.
- Export timestamp and PreSlab assessment UUID.
- User-entered card name and local assessment date.
- Submission status.
- Full-precision front/back centering shares.
- Whether each measurement is eligible for grading-baseline comparison.
- Automatic printed-frame, manual printed-frame, or visual-reference provenance.
- Collector-entered condition observations.
- Optional professional grading outcome.
- Optional user-entered grading economics.

## Deliberate exclusions

- Front and back photographs.
- Application Support paths or image file names.
- Accounts, authentication tokens, device identifiers, analytics identifiers, or pricing data.
- A predicted grade, confidence score, market value, or assertion that a returned grade was predicted.

## Compatibility rules

1. Consumers must reject unknown format identifiers.
2. Consumers must inspect `formatVersion`; version 1 fields may only be interpreted according to this document.
3. New optional fields may be added compatibly. Renaming, removing, or changing the meaning of a field requires a new version.
4. `gradingComparable: false` must remain false downstream. In particular, a user-defined visual reference cannot be promoted to verified centering.
5. Dates are encoded as ISO 8601 and centering shares remain unrounded decimal fractions from 0 through 1.
6. A professional outcome is historical user-entered data, never evidence of a PreSlab grade prediction.

## Future approval gates

Before any live integration, separately approve the transport, explicit user consent, image policy, deletion behavior, identifier mapping, duplicate handling, failure recovery, and security review. Until then, the export model is a local interoperability proposal only.
