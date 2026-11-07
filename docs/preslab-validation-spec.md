# PreSlab — Validation Spec

> **Order:** the geometry study below is the current test. The professional-grade
> study that follows it waits until centering is repeatable and an observation
> model exists. Do not show a grade, a grade range, or a confidence percentage
> from an uncalibrated model. Thresholds are proposals until Cole approves them.
> Do not move a bar after seeing results.

## 0. Geometry study — do this first

The question: on a standard-border Pokémon card, under a written photo protocol, how close are the app's left/right and top/bottom ratios to a physical measurement, and does a full-art card come back unmeasured?

**Set.** About 20–30 Pokémon cards Cole owns, mixed standard-border (both yellow-border and silver-border eras) and full-art, front and back. Ground truth is a ruler, caliper, or flatbed measurement of each border, written down before opening the app result. Each card: window light, room light, and a flash or deliberate glare shot. Two phones if available. Also shoot a bad set on purpose: sleeve, blur, cutoff, steep angle. Record the phone model and whether the automatic lines were accepted or moved.

**Report.**

- Outer-quad detection rate on the good-photo protocol, and how far manual corner fixes moved.
- Inner-border unsupported rate. Full-art should land here. A standard-border card that lands here is a miss.
- Absolute error of each ratio against the physical measurement, median and 95th percentile, standard-border cards only.
- Repeatability: two shots, same card, same light, difference in the ratio.
- Quality gate: share of bad photos that were stopped, and share of good photos that were wrongly stopped.

**Bar for calling the overlay a measurement.** On standard-border cards under the good-photo protocol, median absolute error at or under 3 ratio points and 95th percentile at or under 6, and full-art cards almost never receive a confident ratio. Missing that bar means the screen stays labeled as an aid. These numbers are about the ruler. They are not a PSA result.

The app's blur and glare thresholds are uncalibrated heuristics. This study is what changes them.

## 1. Later question — professional grades

The rest of this document is the later test. It does not start until section 0 has been run and the measurement is stable. The original draft assumed a point grade from SAM plus Llama Vision. That pipeline is not the foundation. Any hosted model is a replaceable `ConditionObserver`. The headline, when this study runs, is how often the app abstains, how wide a shown range is, and how often a shown range contains the professional grade. A range that always says 1–10 is a failure. False certainty is worse than abstaining.

The cost and latency caps further down still apply to any hosted model. The within-1-point table is a proposal from 2026-11-01 and is not approved. Prefer the abstention metrics above if the product shows a range instead of a point.

## 2. The original grade question, kept for the later study

Can the pipeline below estimate a card's professional grade closely enough
that a collector would trust it to decide "submit / hold / sell"?

- **Pipeline under test:**
  1. SAM (self-hosted on the backend) isolates the card, returns the mask,
     measures centering (L/R and T/B border ratios), and crops corners/edges.
  2. Llama Vision via Meta's developer API (provider of record, decided
     2026-11-01 — NOT Ollama/local hosting) inspects the crops and returns
     subgrades for centering, corners, edges, and surface, each with one reason
     sentence and a confidence note. The API key lives on the backend server
     only — never in the app. Model version pinned and recorded; test with the
     strongest vision model the Meta API offers first.
  3. A fixed, published combination rule turns subgrades into the final
     estimate. Proposed rule for the test: final = the lowest subgrade, capped
     by photo-evidence rules (a corner that is not clearly visible cannot
     score above 8). The rule is fixed before the run; it is not tuned mid-run.
- **What is NOT under test yet:** the iOS UI, card identification, pricing,
  accounts, subscriptions, video upload. Those come after a GO decision.

## 2. Dataset — 100 cards with known professional grades

Each entry: front photo + back photo + ground-truth grade + grading company
(PSA / BGS / CGC / SGC / TAG) + date graded.

**Target mix (adjust counts, keep the spread):**

| Grade band | Target count | Why |
|---|---|---|
| 10 (Gem Mint) | ~20 | Tests false-positive 10s — the most expensive mistake |
| 9 – 9.5 | ~30 | The bulk of real submissions |
| 8 – 8.5 | ~25 | Tests the submit/hold boundary |
| 7 and below | ~15 | Tests detection of real wear |
| Tricky cases | ~10 | Off-center cards, whitening, print lines, holo bleed |

**Card-type spread:** Pokémon, Magic, and sports cards all represented; a mix
of modern and vintage (vintage centering and print defects behave differently).
**Sources (in order of preference):**
1. Cards Cole owns with known grades (his own submissions).
2. Cards from trusted collectors, with slab photos or submission receipts as proof.
3. Purchased graded cards photographed before/after — only with documented proof.

**Blinding (mandatory):** the pipeline runs WITHOUT seeing the ground-truth
grade. Ground truth is joined to predictions only at scoring time.

## 3. Photo standards (the test is only valid if photos are realistic)

- Phone camera, in-app-style capture: unsleeved, even lighting, no filters,
  plain dark or neutral background, full card plus a small margin in frame.
- Minimum resolution: shorter side ≥ 2000 px.
- Front AND back required. A backless entry is scored separately and cannot
  receive a 10 (mirrors the app's rule).
- Reject-and-retake criteria (recorded, not silently fixed): glare over any
  corner, card cut off at any edge, sleeve glare, heavy shadow, blur.
- Record per card: phone model, lighting description, retake count. If the
  pipeline only works on perfect photos, that is a finding, not a footnote.

## 4. What gets measured

For each card, record: SAM centering ratios, per-corner and per-edge findings,
each subgrade + reason, final estimate, latency (photo in → report out),
and inference cost (tokens + dollars).

**Metrics:**

1. **Final estimate accuracy** — exact-match % and within-1-point %.
2. **Bias** — overgrade rate vs. undergrade rate. Overgrading is worse than
   undergrading: a user who submits on a false 10 loses real money.
3. **Per-subgrade accuracy** — which pillar fails most (expect surface to be
   weakest; confirm or refute with data).
4. **Centering measurement error** — SAM's ratio vs. a reference measurement
   (manual border measurement on the same photo). Report % of cards within
   5 ratio points.
5. **False-10 rate** — % of cards predicted 10 that are truly below 10.
6. **Cost and latency** — mean and p95 per scan, in dollars and seconds.

## 5. Pass thresholds (approve before running)

| Metric | GO threshold | Notes |
|---|---|---|
| Within-1-point accuracy | ≥ 80% | The headline number |
| Exact-match accuracy | ≥ 50% | Stretch signal, not the decider |
| False-10 rate | ≤ 10% | Protects users from costly submits |
| Overgrade bias | Overgrades ≤ undergrades + 10 pts | Must not flatter cards |
| Centering within 5 pts of reference | ≥ 90% of cards | SAM's core job |
| Mean cost per scan | ≤ $0.10 | Keeps subscription math viable |
| Mean latency | ≤ 60 seconds | Usability ceiling |

**Decision rule:**
- All GO thresholds met → **GO** to Phase 2 (MVP).
- Within-1 between 70–80%, or one threshold narrowly missed → **CONDITIONAL**:
  fix the specific weakness (prompt, combination rule, photo guidance) and
  re-run on a fresh 50-card holdout set. One re-run, not endless tuning.
- Within-1 below 70%, or false-10 rate above 20% → **NO-GO**: do not build
  the app on this pipeline. Options then are LoRA fine-tuning (needs labeled
  data), a different model, or killing the project. That decision is Cole's,
  with the data in hand.

## 6. Execution checklist

- [ ] Cole approves thresholds in Section 5 (or edits them — before running).
- [ ] Pin and record: SAM version, Llama model + version, prompt text, combination rule.
- [ ] Assemble the 100-card dataset with ground-truth proof for each card.
- [ ] Build the backend test script (NOT the app): photo in → SAM → Llama →
      report JSON out. Log every input and output.
- [ ] Run blind: ground truth hidden from the pipeline during the run.
- [ ] Score with the Section 4 metrics. No threshold changes after scoring.
- [ ] Write the validation report: metrics table, worst misses with photos,
      cost/latency summary, and a GO / CONDITIONAL / NO-GO recommendation.
- [ ] Cole makes the final call.

## 7. Cost control during the run

- 100 cards × ~2 photos, one SAM pass (self-hosted, cheap) + one Llama Vision
  call per card. Expected total inference cost is small (tens of dollars at
  most at current hosted pricing) — record the actual number.
- Provider-side spend cap and billing alert ON before the run starts.
- If a single card's cost exceeds $1.00, stop and investigate before continuing.

## 8. What happens after GO

Phase 2 (MVP) begins: SwiftUI app with guided capture, report UI with crops
and reasoning, card identification, submit/hold/sell recommendation, and
StoreKit subscription. The validation report becomes the app's honesty baseline
— the App Store description must not claim accuracy the test did not support.
