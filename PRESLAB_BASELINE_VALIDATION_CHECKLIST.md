# PreSlab Physical-iPhone Baseline Validation Checklist

Date: __________  Tester: __________  App commit/checkpoint: __________
iPhone model: __________  iOS version: __________  Available storage: __________

Use the plugged-in iPhone only. Do not launch or select an iOS Simulator.

## Build and installation

- [ ] Open `PreSlab.xcodeproj` in Xcode.
- [ ] Select the plugged-in iPhone as the run destination.
- [ ] Confirm the selected scheme is `PreSlab` and configuration is Debug.
- [ ] Build succeeds without new warnings.
- [ ] Install and launch succeed on the iPhone.
- [ ] Record any signing/provisioning error verbatim: ____________________
- [ ] Run the `PreSlabTests` unit-test target on the iPhone.
- [ ] Run the `PreSlabUITests` target on the iPhone if time permits.
- [ ] Record executed/passed/failed/skipped counts: ____________________

Environment note from the audit: command-line Xcode project/device services exited with signal 132 before building. Direct arm64 iOS source and test-target type-checking passed. A successful Xcode GUI device build is still required.

## Startup and existing data

- [ ] Launch screen transitions cleanly into the library.
- [ ] Startup remains responsive while the SwiftData store opens.
- [ ] Existing saved assessments remain visible.
- [ ] Open at least one pre-existing assessment; both images and measurements load.
- [ ] Force-quit and relaunch; the library remains intact.
- [ ] If store opening fails, the app shows retry and does not replace data with an empty library.

## Sample-card smoke test

- [ ] Tap **Practice with a sample image**.
- [ ] “Checking the photo” appears without freezing navigation/animation.
- [ ] Front quality reports usable.
- [ ] Front automatic artwork lines and ratios appear.
- [ ] Expected sample front is approximately left/right 40/60 and top/bottom 58/42.
- [ ] Pinch to zoom and drag to pan; ratios do not change.
- [ ] Move one white artwork line; only the intended measurement changes.
- [ ] Switch to **Card edges** and move one yellow corner.
- [ ] An updating message appears; the UI remains responsive.
- [ ] Switch back to **Artwork border**; the perspective-corrected image updates.
- [ ] **Reset detected lines** restores the original automatic geometry promptly.
- [ ] Continue through the back and summary.
- [ ] Save, reopen, compare, share, and delete the sample assessment.

## Camera and photo library

- [ ] On first use, the camera permission explanation is clear.
- [ ] Denying camera permission leaves **Choose from library** usable.
- [ ] Allowing camera permission shows the back-camera preview.
- [ ] Torch starts off.
- [ ] Torch toggle works and does not remain on after leaving capture.
- [ ] Tap the card in preview; focus settles.
- [ ] The capture button cannot be triggered twice while a photo is processing.
- [ ] A successful capture advances to **Checking the photo**.
- [ ] A failed/unreadable camera or library image shows an actionable alert rather than doing nothing.
- [ ] Library imports honor image orientation for portrait, landscape-left, and landscape-right source photos.

## Real-card happy path

Use an unsleeved standard-border Pokémon card on a plain contrasting background.

- [ ] Capture the entire front with a small margin and even light.
- [ ] Capture processing does not visibly freeze the app.
- [ ] The outer yellow card outline matches all four physical corners.
- [ ] The four white lines match the artwork-border transitions.
- [ ] Record automatic front left/right: ______ / ______
- [ ] Record automatic front top/bottom: ______ / ______
- [ ] Correct any outer corners and record whether the result visibly improved: __________
- [ ] Correct any artwork lines and record the final ratios: ____________________
- [ ] Repeat for the back.
- [ ] Front edits do not alter back measurements and vice versa.
- [ ] Summary clearly identifies hand-adjusted sides.
- [ ] Grading text says compatible/baseline and never guarantees a professional grade.
- [ ] Save, force-quit, relaunch, and reopen; photos, ratios, and adjustment flags match.

## Quality and fallback cases

For each case, record whether the app stopped the image, measured it, or required manual correction.

| Case | Expected | Actual | Pass |
|---|---|---|---|
| Card too small | Actionable move-closer guidance | | [ ] |
| One edge cut off | Actionable reframe guidance | | [ ] |
| Steep perspective | Actionable square-up guidance | | [ ] |
| Intentional blur | Blur guidance; no confident automatic measurement | | [ ] |
| Large glare patch | Glare guidance; no confident automatic measurement | | [ ] |
| Dark but sharp photo | Does not reject solely for darkness if edges remain usable | | [ ] |
| Rotated card | Outer rectangle and corrected orientation remain coherent | | [ ] |
| Full-art/borderless card | Inner border remains unmeasured | | [ ] |
| Reflective/foil card | No false confident border; note behavior | | [ ] |
| Background with a rectangle | Card wins over background, or failure is clear | | [ ] |
| Vision misses a visible card | **Place card edges manually** opens a usable starting quad | | [ ] |

## Manual editor usability

- [ ] White artwork-border guides and yellow card-edge guides are visually distinct.
- [ ] All handles are easy to acquire with one finger.
- [ ] Small drags are retained after finger release.
- [ ] Zoom buttons, pinch zoom, pan, and reset work without moving measurements unintentionally.
- [ ] Lines may reach a near-zero border without snapping toward 50/50.
- [ ] Lines outside/crossing the card invalidate the measurement instead of clamping to a plausible ratio.
- [ ] Completion is disabled while a corner remeasurement is pending.
- [ ] Reset restores both the original lines and the corresponding flattened image.
- [ ] When no stable printed frame is detected, **Visual only** is selected by default.
- [ ] A visual-only reference may display saved ratios but is labeled documentation-only and produces no grading-company compatibility.
- [ ] Choosing **Printed frame** is explicit and warns that it should only be used for a real printed frame automatic detection missed.

## Persistence and history

- [ ] Saving produces one library row and returns to the library.
- [ ] Two saved assessments can be selected and compared.
- [ ] Front thumbnails load without a long scrolling hitch.
- [ ] Share sheet works offline and includes front/back ratios and disclaimer.
- [ ] Deleting removes the row and does not affect another assessment.
- [ ] Existing assessments survive app update/reinstall-over-build. Do not uninstall, because uninstalling removes local data.

## Grading standards and results

- [ ] Select PSA, BGS, CGC, and TAG; each remains available.
- [ ] Select a specific target grade and verify the result names the measurement that fits, fails, is missing, or requires qualitative review.
- [ ] Confirm BGS 10 says centering alone cannot establish or distinguish Black Label and Gold Label.
- [ ] Confirm TAG text does not claim to reproduce TAG's proprietary overall score.
- [ ] Open each official source link and verify it loads.
- [ ] Confirm results consistently say **centering compatibility/baseline**, never that a professional grade is guaranteed.
- [ ] Test a value immediately below, at, and immediately above a displayed threshold using the sample/manual editor.

## Collector workflow

- [ ] Open a saved assessment and tap **Organize**.
- [ ] Give the card a name, select each submission status in turn, and save.
- [ ] Record different front and back condition observations; uninspected items remain absent from the summary.
- [ ] Force-quit and reopen; name, status, and observations persist.
- [ ] Search by a partial card name.
- [ ] Filter by each submission status and at least one compatible grading-company baseline.
- [ ] Sort by newest, oldest, card name, and status.
- [ ] Export a PDF while offline; it is readable in both light and dark device appearances and includes both photos, measurements, limitations, and entered observations.
- [ ] Record an actual grading company, returned grade, dates, and notes; confirm the original front/back measurements appear beside it and it is labeled as an outcome rather than a prediction.
- [ ] Filter history by **Outcome recorded** and **No outcome recorded**.
- [ ] Open a saved assessment's grading calculator and verify submission-only costs, total economic basis, selling fees, break-even, and profit/loss with hand-calculated values.
- [ ] Save economics with an assessment, force-quit, reopen, and confirm the values and PDF export persist.
- [ ] Confirm no account, network request, price scraping, or external image upload is required.

## Accessibility and layout

- [ ] Test the largest Dynamic Type setting; critical instructions and buttons remain visible.
- [ ] Test VoiceOver on capture, quality, editor handles, summary, and saved rows.
- [ ] Compatibility states are understandable without relying only on color.
- [ ] Reduce Motion removes nonessential startup animation.
- [ ] Light and dark appearance maintain readable contrast, even though dark is the intended identity.
- [ ] Rotate to each supported iPhone orientation and record layout defects: ____________________

## Responsiveness and stability

- [ ] Record time from capture to quality result: ______ seconds.
- [ ] Record time from manual corner release to updated editor: ______ seconds.
- [ ] Repeat front/back processing five times; no crash or progressive slowdown.
- [ ] Rapidly leave capture while analysis is running; no stale result appears in another step.
- [ ] Observe device temperature and memory warnings during ten sample/real analyses: __________
- [ ] Camera and torch are released after leaving capture.

## Calibration worksheet

Record physical border widths before looking at the app result. Use consistent units.

| Card / side | Lighting | Physical L | Physical R | Physical T | Physical B | Expected L/R | Expected T/B | Auto L/R | Auto T/B | Manual L/R | Manual T/B | Notes |
|---|---|---:|---:|---:|---:|---|---|---|---|---|---|---|
| | | | | | | | | | | | | |
| | | | | | | | | | | | | |
| | | | | | | | | | | | | |

For the full study, use roughly 20–30 cards and report:

- Outer-quad detection rate: ______
- Automatic inner-border measurement rate on standard-border cards: ______
- False measurement rate on full-art/borderless cards: ______
- Manual-correction rate: ______
- Median absolute ratio error: ______ points
- 95th-percentile absolute ratio error: ______ points
- Repeat-shot difference: ______ points
- Bad-photo stop rate: ______
- Good-photo false-stop rate: ______

Provisional acceptance bar from `docs/preslab-validation-spec.md`: median absolute error at or below 3 ratio points, 95th percentile at or below 6, and full-art cards almost never receiving a confident ratio.

## Final result

- [ ] PASS — keep this checkpoint and begin the real-card calibration set.
- [ ] CONDITIONAL — fix the listed phone issues, then repeat the affected sections.
- [ ] FAIL — do not treat this working tree as a release candidate.

Blocking defects:
1. ____________________
2. ____________________
3. ____________________

Screenshots or screen recordings saved at: ____________________
