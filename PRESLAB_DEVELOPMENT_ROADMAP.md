# PreSlab Development Roadmap

Audit date: November 9, 2026
Baseline: the current working tree, including pre-existing staged and unstaged changes
Validation policy: physical iPhone only; do not launch iOS simulators

## Executive assessment

PreSlab is a compact, native SwiftUI application with an appropriate local-first architecture. Its core flow is already present: camera or library input, Vision rectangle detection, perspective flattening, automatic artwork-border scanning, manual correction, front/back ratios, grading-baseline comparisons, SwiftData history, image-file persistence, comparison, and sharing.

The application has been extended incrementally rather than rebuilt. The strongest parts remain the separation of pixel geometry from SwiftUI, full-precision centering math, explicit unsupported states, and deterministic synthetic geometry tests. The principal release risk is now physical validation: real-card calibration for automatic border detection, blur/glare gates, repeatability, migration of an existing on-device store, and usability of the expanded workflow. The current heuristics must not be described as accurate until the physical-card study passes.

Phases 1–5 now have an implementation candidate in the working tree. Phase 5 is complete at its approved boundary: unconventional designs abstain or store an explicitly non-comparable visual reference, economics can be saved per assessment, professional outcomes can be reviewed and filtered, and a local versioned CollectorAtlas contract is documented without a live integration. Expensive image work is off the main actor; manual rescue and diagnostics are present; grading results distinguish sourced numeric rules from qualitative or unpublished rules; target selection and accessibility are improved; and the local collector workflow includes names, submission status, condition observations, search/filter/sort, PDF export, user-entered cost calculations, and actual grading outcomes. Physical-iPhone testing is the next gate.

## Implementation status at the phone-test checkpoint

| Phase | Implemented candidate | Still gated or intentionally deferred |
|---|---|---|
| 1 — measurement | Existing Vision detection and homography preserved; background analysis; manual no-card rescue; scanner diagnostics; safe save/delete; reset-to-automatic behavior; deterministic geometry/calculation tests | Real-card accuracy, glare/foil/blur calibration, repeatability, memory and latency profiling |
| 2 — standards | Dedicated rules engine retained; official-source audit recorded; unrounded boundary evaluation; qualitative/unpublished states; BGS 10 wording corrected; TAG limitations exposed | Re-verify sources before every release and execute boundary tests on the phone |
| 3 — results | Target grader/grade selection; specific failure explanations; source details; Dynamic Type and VoiceOver improvements; non-color status cues | Usability and full accessibility pass on a physical iPhone |
| 4 — workflow | Local names, shortlist status, front/back condition checklist, search, filter, sort, offline PDF, actual-save errors | Existing-store migration and share-sheet validation on the phone |
| 5 — advanced | Conservative unconventional-design provenance; visual-reference exclusion from grader rules; saved economics; outcome comparison/filtering; versioned local CollectorAtlas export contract | Automatic full-art measurement remains intentionally unsupported; no live CollectorAtlas integration |

## Repository and build baseline

- One Xcode project: `PreSlab.xcodeproj`.
- Targets: `PreSlab`, `PreSlabTests`, and `PreSlabUITests`.
- No package dependencies are declared.
- Swift 5 language mode with Swift 6.2.4 compiler and main-actor default isolation.
- Deployment target: iOS 26.2.
- Targeted device families currently include iPhone and iPad, although product copy consistently says iPhone.
- Persistence: SwiftData metadata plus JPEGs in Application Support.
- Test inventory: 68 Swift Testing cases and 9 XCTest UI-test methods.
- Current worktree was already substantially modified before this audit. It contains staged work across geometry, grading, persistence, views, tests, launch assets, and project configuration. Preserve it as user-owned work and create a known checkpoint before broader changes.
- macOS detects a plugged-in iPhone over USB. No simulator was launched.
- `xcodebuild`, `devicectl`, and `xctrace` terminate with signal 132 when they initialize Xcode project/device services on this host. Direct arm64 iOS type-checking succeeds for the app, unit-test sources, and UI-test sources. A signed build and actual test execution therefore remain unverified.

## Current architecture

```text
AppRootView / AppStartup
    -> SwiftData ModelContainer
    -> LibraryView
        -> CaptureFlowView
            -> CameraCaptureView or PhotosPicker
            -> upright, size-limited RGBAImage
            -> RectangleDetector (Vision outer quadrilateral)
            -> PhotoQuality geometry checks
            -> CardWarp (homography/perspective correction)
            -> PhotoQuality appearance checks
            -> BorderScanner (automatic internal artwork borders)
            -> CenteringAdjustView / CardEditorCanvas (manual correction)
            -> SummaryView / CenteringBaselinesView
            -> AssessmentRecord + ImageStore
        -> saved detail, compare, share, delete
```

### Architecture observations

- Geometry types are value types and `Sendable`; this supports deterministic tests and background processing.
- Perspective correction is already implemented with a normalized homography and bilinear sampling. The original RGBA image remains available for the card-edge editor.
- Measurement logic is separate from the grading comparison and presentation layers.
- Grading standards and evaluation are separate from UI code.
- SwiftData stores serialized `SideFinding` payloads rather than modeling each measurement field. This preserves a small schema but makes future migrations and querying harder.
- Images are stored locally and are only shared through an explicit share action.
- A developer-only condition-observation harness remains local and uses canned responses. The former server POST implementation and local-network permission have been removed. No card-image upload or paid inference path is present.

## Existing functionality inventory

| Area | Current implementation | Preserve |
|---|---|---|
| Camera | Back wide-angle camera, framing guide, tap focus, focus wait, optional torch | Yes |
| Photo library | Native `PhotosPicker` import | Yes |
| Sample workflow | Synthetic front/back card used by practice and tests | Yes |
| Outer-edge detection | `VNDetectRectanglesRequest`, card-aspect filtering, largest candidate | Yes; tune only with evidence |
| Perspective correction | Four-corner homography into a 750×1050 canonical card | Yes |
| Inner-border detection | Luminance-gradient scan from four edges with median consistency checks | Yes; calibrate before expanding claims |
| Image validation | Card presence, size, cutoff, skew, blur, and glare heuristics | Yes; thresholds are uncalibrated |
| Manual correction | Separate artwork-border and card-corner modes; pan, zoom, reset, 48-point handles | Yes |
| Measurement | Full-precision left/right and top/bottom normalization; rounding only in display strings | Yes |
| Front/back | Independent findings and photos; missing measurements stay missing | Yes |
| Grading comparison | PSA, BGS, CGC, and TAG rows with numeric, qualitative, unpublished, and invalid states | Yes; re-verify official sources each release |
| Results | Ratios, target-grade baseline, expandable details, disclaimers, sources, offline PDF | Yes |
| Persistence | SwiftData assessment record plus local front/back JPEGs; optional additive workflow fields | Yes; validate migration on device |
| History | Reopen, delete, compare, rename, status, search, filter, sort, condition notes, outcome | Yes |
| Privacy | On-device measurement; no account required | Yes |

## Automatic detection and measurement audit

### Outer card detection

`RectangleDetector` normalizes the input image upright before Vision sees it. Vision searches for up to eight rectangles with a 0.60–0.84 aspect ratio, a minimum 20% image size, 0.4 confidence, and 35-degree quadrature tolerance. The largest observation wins.

Risks:

- Candidate selection uses area alone. A larger background rectangle can beat the card.
- Vision confidence, expected card ratio, edge margin, and centrality are not combined into a score.
- A complete Vision miss now offers a centered standard-card starting quadrilateral for explicit manual rescue; its usability still needs phone validation.
- Detection quality has no persisted confidence or diagnostic metadata.

Do not replace Vision yet. First collect real misses, then consider a ranked-candidate score and a manual fallback.

### Perspective correction

`CardWarp` maps the four detected corners to the canonical 2.5:3.5 card plane. This is the correct incremental foundation for perspective-safe border measurement. Excessive skew is rejected before an automatic measurement. Manual corner edits trigger a new warp. Original images are retained.

Risks:

- Bilinear sampling clamps points outside the source image. A manually overscanned corner can create repeated edge pixels in the expanded editor.
- Homography correctness has synthetic coverage but not real-photo accuracy measurements.
- Canonical output dimensions are fixed, which is acceptable for standard-size cards but should be documented as a product constraint.

### Internal border scanning

`BorderScanner` samples the central 60% of each side, searches the first 22% of depth for the strongest luminance transition, and accepts the median position when strength and deviation thresholds pass.

Strengths:

- Simple, deterministic, offline, and testable.
- Returns unsupported instead of inventing a full-art measurement.
- Uses perspective-corrected geometry.

Risks:

- The strongest luminance transition may be artwork or text rather than the printed frame.
- Saturation/color information, edge continuity, opposing-side agreement, and uncertainty are not used.
- One fixed threshold may behave differently on yellow, silver, dark, foil, vintage, and reflective borders.
- Per-side rejection diagnostics now expose weak edges and inconsistent scan rows to tests and future UI work, but no calibrated user-facing uncertainty score is claimed.

### Centering math

`CenteringRatios` correctly computes each share from opposing border widths:

- left = left / (left + right)
- right = right / (left + right)
- top = top / (top + bottom)
- bottom = bottom / (top + bottom)

The stored values remain `Double`; display formatting performs the rounding. The grading engine compares unrounded imbalance values. Zero-width borders remain valid when the opposing border has width; a zero/zero axis is unmeasured.

## Prioritized issues and technical risks

### Critical — release blockers

1. **No real-card accuracy or repeatability baseline.** Synthetic tests validate math, not Vision/lighting/foil behavior. Run the documented 20–30 card study before accuracy claims or threshold-based UX is finalized.
2. **Uncalibrated photo-quality thresholds.** Blur and glare thresholds can reject usable photos or admit bad ones. Record false-stop and missed-stop rates before tuning.
3. **Grading sources can change.** The current numeric rules were reviewed against official sources and recorded in `docs/centering-standards.md`, but the verification date must be refreshed before each release rather than treating the values as permanent.
4. **Physical-device build/test execution is blocked in this environment.** Direct source type-checking passes, but no signed build or test suite has run during this audit.

### High

1. **Automatic rectangle selection is area-only.** Background rectangles may be selected over a card.
2. **Capture and import recovery requires device evidence.** Actionable errors, capture state, and manual no-card rescue are implemented but not yet exercised on the phone.
3. **Background analysis requires profiling.** Initial assessment, sample generation, expanded editor warp, and manual corner remeasurement run away from the main actor; responsiveness and cancellation behavior still need device validation.
4. **Large uncommitted baseline.** The mixture of staged and unstaged work makes regression attribution difficult. Create a checkpoint after phone validation.

### Medium

1. **Migration has not been executed against the user's existing store.** New workflow fields are additive and optional with safe defaults, but only an install-over-build phone test can validate the actual SwiftData lightweight migration.
2. **Memory pressure is unmeasured.** The flow can retain two normalized originals, two canonical warps, expanded editor images, and UIKit images. Profile on the supported phone.
3. **Expanded-warp overscan clamps source pixels.** This can be visually misleading near photo boundaries.
4. **Default target includes iPad.** Confirm whether PreSlab is iPhone-only or whether iPad layouts and camera behavior are supported.
5. **Accessibility remains a human-test item.** Handle names, custom adjustment actions, image labels, and flexible status layout are improved, but VoiceOver and largest Dynamic Type still require device review.
6. **Manual continuation is intentionally narrow.** A complete rectangle miss can be rescued manually; blur, glare, cutoff, and severe-perspective failures still request a better image to avoid misleading measurements.

### Low

1. The template test was replaced during this pass with a meaningful camera-default test.
2. Historical planning documents retain hosted-inference proposals only behind explicit superseded notices. They are not active roadmap scope.

## Changes made during this audit

- Moved initial card assessment and synthetic-sample generation off the main actor.
- Moved expanded artwork-editor warping and manual-corner remeasurement off the main actor.
- Cached and reused the original automatic warp when resetting manual changes.
- Disabled completion while a manual perspective remeasurement is pending.
- Added camera capture-in-progress state and actionable camera/library errors.
- Changed the torch default from on to off to avoid manufacturing glare.
- Made assessment saves explicit and removed newly written images when insertion/save fails.
- Made library deletion commit metadata before deleting image files.
- Added explicit manual rescue after a complete rectangle-detection miss.
- Added per-side automatic border-scan diagnostics and deterministic tests.
- Removed the server-backed condition observer and local-network permission; the developer harness is canned and local only.
- Audited grader rules against official sources, retained full-precision comparisons, and exposed qualitative/unpublished limitations.
- Added target-grade selection, source detail, and accessibility improvements to results.
- Added additive local collector metadata, organizer controls, search/filter/sort, condition observations, offline PDF export, cost calculations, and actual-outcome tracking.
- Removed an existing concurrency warning by making pure RGBA-to-`UIImage` conversion nonisolated.
- Replaced the empty template unit test with a camera-default regression test.

These changes intentionally leave the core Vision detector, automatic border heuristic, manual controls, sample workflow, and grading-engine separation intact. The SwiftData record gained only optional additive fields so legacy rows have safe defaults.

## Recommended implementation phases

Complexity estimates assume one experienced iOS engineer and exclude time needed to collect human test data.

| Phase | Scope | Complexity | Estimated engineering time | Gate |
|---|---|---:|---:|---|
| 0 | Audit, roadmap, baseline checklist | S | 0.5–1 day | Documents reviewed |
| 1A | Responsiveness, capture errors, safe save, deterministic math tests | M | 1–2 days | Physical-device smoke pass |
| 1B | 20–30 card calibration study and issue corpus | L | 2–4 days plus data collection | Error/repeatability bar met |
| 1C | Evidence-driven detector/scanner/quality tuning; manual rescue policy | L | 3–7 days | Holdout images and device regression pass |
| 2 | Primary-source standards audit, rules cleanup, threshold tests | M–L | 2–4 days | Every numeric rule sourced |
| 3 | Results hierarchy, target selection, accessibility/Dynamic Type | M | 2–4 days | Usability and accessibility pass |
| 4 | Naming, shortlist status, condition notes, search/filter/export, migration | L | 5–10 days | Existing-store migration test |
| 5 | Full-art feasibility, cost calculator, actual outcomes | L/Research | Separate projects | Core measurement stable |

## Phase 1 implementation proposal

### Completed or already present

- Preserve Vision rectangle detection and manual handles.
- Preserve and test the existing homography-based perspective correction.
- Keep unrounded measurement values through grading comparison.
- Distinguish capture, card detection, border detection, and ready-to-review states.
- Keep original images and allow reset to the automatic result.
- Prevent heavy geometry work from blocking the UI.

### Next after phone smoke testing

1. Build a versioned calibration fixture manifest containing image name, lighting, card type, physical border widths, expected ratios, automatic/manual result, and notes.
2. Run the baseline checklist on the connected iPhone and collect timing, detection, false-quality-stop, and correction data.
3. Add candidate scoring to `RectangleDetector` only if the collected misses show area-only ranking is a cause.
4. Extend the existing border-scan diagnostics with outer-quad confidence and quality metrics only if the calibration corpus shows they help explain failures. Keep the data local and do not show a fake confidence percentage.
5. Tune `BorderScanner` using training fixtures and validate against a separate holdout set. Candidate incremental features are color-gradient support, robust row consensus, opposing-side agreement, and explicit ambiguity detection.
6. Validate the explicit `.noCard` manual-rescue action and centered starting quadrilateral with users; keep retake as the primary action.
7. Add tests for multiple rotations, mirrored imbalance direction, perspective severity boundaries, low light, glare placement, scanner ambiguity, cancellation, and independent front/back edits.
8. Profile peak memory, warp duration, and UI responsiveness on the oldest supported iPhone.

### Phase 1 acceptance evidence

- Automatic detection still works on the existing sample and on the good-photo real-card set.
- Manual artwork and outer-edge adjustments remain usable at 1× and zoomed scales.
- Front and back remain independent through save/reopen.
- Deterministic math and geometry tests execute, not merely type-check.
- Real standard-border cards meet the agreed median and 95th-percentile error bar.
- Full-art/borderless cards rarely receive a false confident measurement.
- Bad-photo guidance is actionable and manual continuation is available where approved.
- Existing assessments remain readable.

## Relevant source files

| Responsibility | Files |
|---|---|
| App startup | `PreSlab/PreSlabApp.swift`, `PreSlab/Views/AppRootView.swift`, `PreSlab/Persistence/AppStartup.swift` |
| Capture/import | `PreSlab/Views/CameraCaptureView.swift`, `PreSlab/Views/CaptureFlowView.swift` |
| Pixel model/orientation | `PreSlab/Geometry/RGBAImage.swift`, `PreSlab/Persistence/ImageStore.swift` |
| Outer detection | `PreSlab/Geometry/RectangleDetector.swift`, `PreSlab/Geometry/CardQuad.swift` |
| Perspective | `PreSlab/Geometry/Homography.swift`, `PreSlab/Geometry/CardGeometryEngine.swift` |
| Quality | `PreSlab/Geometry/PhotoQuality.swift` |
| Inner borders | `PreSlab/Geometry/BorderScanner.swift` |
| Manual editor | `PreSlab/Views/CenteringAdjustView.swift`, `PreSlab/Views/CardEditorCanvas.swift`, `PreSlab/Geometry/CardEditorTransform.swift` |
| Measurements | `PreSlab/Models/SideFinding.swift`, `PreSlab/Geometry/CardQuad.swift` |
| Grading rules | `PreSlab/Grading/CenteringStandards.swift`, `PreSlab/Grading/CenteringComparison.swift`, `docs/centering-standards.md` |
| Results/compare | `PreSlab/Views/SummaryView.swift`, `PreSlab/Views/CenteringBaselinesView.swift`, `PreSlab/Views/CompareView.swift` |
| Persistence/history | `PreSlab/Models/AssessmentRecord.swift`, `PreSlab/Persistence/ImageStore.swift`, `PreSlab/Views/LibraryView.swift` |
| Collector workflow | `PreSlab/Models/CollectorWorkflow.swift`, `PreSlab/Views/AssessmentDetailView.swift`, `PreSlab/Views/GradingCostCalculatorView.swift` |
| Future local interchange | `PreSlab/Models/CollectorAtlasExport.swift`, `docs/collectoratlas-export-contract.md` |
| PDF export | `PreSlab/Models/AssessmentPDFExporter.swift`, `PreSlab/Views/SummaryView.swift` |
| Tests | `PreSlabTests/GeometryTests.swift`, `PreSlabTests/CardEditorTests.swift`, `PreSlabTests/CenteringComparisonTests.swift`, `PreSlabTests/CollectorWorkflowTests.swift`, `PreSlabTests/AssessmentPDFExporterTests.swift`, `PreSlabUITests/CenteringEditorUITests.swift`, `PreSlabUITests/PreSlabUITests.swift` |
| Local developer harness | `PreSlab/Seams/ObservationCrops.swift`, `PreSlab/Seams/FutureSeams.swift`, `PreSlab/Views/StubTestView.swift` |

## Testing strategy

### Deterministic tests

- Formula tests must inspect unrounded values around exact grading thresholds.
- Synthetic card fixtures should vary all four border widths independently.
- Homography tests should cover rotation, mild and near-limit perspective, and corner order/convexity.
- Scanner tests should include uniform, noisy, low-contrast, multiple-transition, asymmetric, and borderless images.
- Persistence tests should cover store reopen, legacy JSON decoding, save failure cleanup, and future migrations.
- Rules tests should cover exact threshold, just inside/outside, missing face, unknown rule, qualitative rule, and no rounding rescue.

### Physical-iPhone tests

- Camera permission denied/allowed, tap focus, capture, torch, and photo-library failure paths.
- Responsiveness while checking a photo and after moving a card corner.
- Front/back capture, save, kill/relaunch, reopen, compare, share, and delete.
- Dynamic Type, VoiceOver, Reduce Motion, rotation policy, low storage, and memory pressure.
- No simulator is required or permitted for this project session.

### Calibration study

- Record physical border ground truth before viewing the app result.
- Include yellow-border, silver-border, vintage, dark-border, foil/reflective, full-art, deliberately blurred, glared, cut-off, sleeved, rotated, and perspective-distorted photos.
- Report outer detection rate, automatic inner-border rate, manual-correction frequency, median and p95 absolute ratio error, repeatability, false quality stops, and bad-photo misses.
- Use a holdout set for the final measurement. Do not tune and report on the same images.

## Product-owner decisions needed

Resolved in this pass: the live upload implementation and local-network permission were removed; a complete Vision miss now offers an explicit manual starting box; and current grading sources were audited and remain visible with limitations.

1. Is the supported product iPhone-only? If yes, remove iPad from the target; if no, add an iPad validation matrix.
2. Should any quality failure beyond a total rectangle miss be manually overridable? The current candidate still blocks cutoff, small-card, excessive-skew, blur, and glare cases.
3. What physical-iPhone model and iOS version define the oldest performance target?

The economics ambiguity is resolved in the UI by showing **submission-only costs** separately while including raw-card value in **total economic basis**.

## Stop point

The next useful step is human testing on the plugged-in iPhone using `PRESLAB_BASELINE_VALIDATION_CHECKLIST.md`. The app, 68 unit-test cases, and 9 UI-test methods type-check against the arm64 iPhoneOS 26.2 SDK, but the Xcode command-line service crash prevented a signed build or test execution. Detector tuning and any claim of automatic full-art support should wait for phone evidence; a live CollectorAtlas integration remains out of scope.
