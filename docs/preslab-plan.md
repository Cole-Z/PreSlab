# PreSlab — Project Plan

> **Status (2026-11-06):** Milestone 1 is an on-device centering tool for standard-size Pokémon cards. It does not estimate a grade. Do not merge, deploy, buy services, or submit to the App Store without Cole's approval.
>
> **November 9, 2026 direction:** local/offline processing is the continuing
> product architecture. Earlier references below to hosted models, backend
> inference, Scrydex, subscriptions, or uploaded crops are historical ideas,
> not approved implementation work. The current master roadmap and
> `PRESLAB_DEVELOPMENT_ROADMAP.md` take precedence.

## What PreSlab is

An iOS app for an honest look at a trading card before paying a grading company. The user photographs the front and back. The app measures what a photo can actually measure, and it says so when it cannot.

PreSlab gives a pre-check, never an official grade. Only PSA, BGS, CGC, SGC, TAG, and similar companies assign official grades. The app must never claim affiliation with a grading company or with Pokémon / Nintendo. A grade range is allowed only after a blinded test shows the range is meaningful. Until then the app shows measurements and an inconclusive result, not a score.

## What exists in the repo

- `PreSlab/` — SwiftUI app. Milestone 1 replaces the Xcode template with local capture, a photo check, centering, and a saved library.
- `docs/preslab-validation-spec.md` — geometry study first, professional-grade study later.
- `backend/connectivity_check.py` — a Meta Llama connectivity spike. It is not the app's pipeline. The key stays in the environment.

## MVP

Pokémon cards that are 2.5 by 3.5 inches. Automatic centering is for cards with a visible outer border. Full-art and borderless designs return "not measured." Other games wait until this path is repeatable on real photos.

In this version:

- Guided front and back photos (camera or library), with a framing guide and a reminder to remove the sleeve.
- On-device photo check: card found, large enough, margin around the edges, not too skewed, not badly soft, no large glare. A failure explains the problem and asks for another photo.
- Centering from the card quad and the artwork border, with the left/right and top/bottom ratios, an overlay, and manual handles. The user can leave centering unmeasured.
- Assessments saved on the iPhone, reopened, deleted, and compared on those measurements only.
- Recommendation copy is only "Centering recorded" or "Inconclusive," plus an explicit list of what was not assessed.

Not in this version: a grade or grade range, AI observations, accounts, subscriptions, card identification, Scrydex, SAM, video, and any claim about authenticity or value.

## Architecture

```
Capture (camera or library)
  -> PhotoQuality
  -> CardGeometry (Vision quad, flatten, border scan)
  -> manual adjustment
  -> Assessment in SwiftData, photos in Application Support
  -> summary and compare
```

Measurement runs on the phone. Photos are not uploaded. Deleting an assessment deletes its files.

`ConditionObserver`, `GradeEstimator`, `CardCatalog`, and `PriceLookup` in `PreSlab/Seams/FutureSeams.swift` are the later boundaries. Views must not call a vendor SDK directly. `GradeEstimator` may only return "not enough evidence" until a blinded set says otherwise.

**Backend, when a paid API is actually required.** One HTTPS service holds provider keys in its environment. The app sends only the crops that call needs. The server processes and discards by default. The phone copy is what the user saves and deletes. Add authentication and per-user limits before a shared key is exposed to other people. No backend in milestone 1.

Scrydex stays behind `PriceLookup` on that server, and only after written permission to show prices inside the app (see the validation spec). Cache one card at a time. Do not sync the catalog. Do not put the key in the app. Pricing never changes the condition result.

## Measured vs inferred

Measurable now, with limits: the outer quad on a contrasting background, a flattened crop, and inner-border ratios when each side has one stable color step. Blur and glare checks are heuristics. Their thresholds are not calibrated on real photos yet.

Not measurable from an ordinary phone photo: every dent or scratch, a few pixels of whitening, trimming, alterations, counterfeits, or the grade a company would assign. The app does not pretend to detect a sleeve; it asks the user to remove it.

A later model may describe a crop. That sentence is an observation, shown next to the crop, and it is not a measurement.

## How a result is produced

1. The user confirms the card is unsleeved on a plain background.
2. Front photo, then the quality check. Failure returns to capture.
3. Centering overlay. Detected lines, or "not measured," with handles to correct either.
4. The same steps for the back. An unmeasured back does not block saving.
5. Summary: ratios, whether the user moved the lines, and what was not assessed.
6. Save on the phone. Compare is available once two assessments exist.

## Guardrails that still hold

- No general chat and no editable prompt in the app.
- No paid API key in the binary.
- No unlimited paid inference later. Caps and a provider spend alert come before any subscription.
- Duplicate protection, short structured output, and sign-out rules from the earlier plan still apply to a future backend.
- The privacy policy, when an upload exists, has to say that photos go to PreSlab's server and to the named AI service.

## Business

Subscription pricing is not decided. Milestone 1 has no StoreKit product. A subscription needs a known cost per scan, which this version does not have. Competitors include Binder AI, CardSense, Cardinal, Graid, and others. PreSlab's difference is showing the measurement and its limit, not claiming a higher grade. The monetization proposal lives in `docs/preslab-monetization.md`; prices stay undecided until the validation run measures per-scan cost.

## Phases

### Now — on-device centering

Build and check the measurement against ruler or caliper readings. See the validation spec. If the ratios are not repeatable, the screen stays an aid and does not grow a grade.

### Next — observations, still not a grade

Add `ConditionObserver` behind the seam, with crops and limitations. Run the blinded grade study before any range is shown. Abstention and range width are the headline numbers.

### Later — identity, price, and App Store

Card identification and a submit / keep / sell note only after condition and price are both real, and after Scrydex display rights are in writing. TestFlight, privacy policy, and AI disclosure come before review.

## Roles

- **Cole** — founder. Approves merges, purchases, and App Store submission.
- **Dash** — project tracking. Reviews code on GitHub after it is pushed.
- This environment implements only what Cole has approved. It does not share a session with Dash. The bridge is GitHub.

## Decisions already made

- Name: PreSlab (2026-10-31).
- Milestone 1 measures on device with Apple Vision and classical border detection. SAM is a fallback only if that study fails.
- No model vendor is hardwired. The Meta connectivity script is a spike.
- No training in this phase.
- iOS, SwiftUI, deployment target iOS 26.2, bundle id `com.preslab.PreSlab`.
- Pokémon, standard size, is the first supported category.

## Open items

- USPTO and App Store Connect name check for "PreSlab."
- Cole's geometry study: about 20–30 of his cards, physical border measurements recorded before looking at the app.
- Written Scrydex permission before any price call, including cache duration. Confirm whether the current plan returns graded prices; the public pricing page and FAQ disagree.
- Subscription price and scan caps, after a real per-scan cost exists.
- The professional-grade study thresholds in the validation spec are still proposals. Do not treat them as approved, and do not run that study until geometry is stable.
