# PreSlab — Monetization Plan (Superseded Historical Proposal)

> **Not approved for implementation:** This document predates the November 9,
> 2026 local-only product direction. Paid inference, image uploads, backend
> accounts, subscriptions, and API-based pricing are out of scope unless the
> product owner explicitly reverses that decision in a future session.

> **Status:** proposal. Prices and scan counts below are placeholders.
> Nothing here is final until the validation run measures the real
> per-scan cost and Cole approves. Milestone 1 ships with no StoreKit
> product and no paid call of any kind.

## Principles

1. **Free forever:** on-device centering, library, and compare. These cost
   us nothing per use. They are the acquisition engine.
2. **Paid:** AI observations (`ConditionObserver` via backend) only. Every
   paid call must pass the on-device photo-quality gate first.
3. **No bring-your-own-key.** Keys live on the backend. Simpler product,
   owned margin, no support nightmare.
4. **Price follows measured cost.** Price = scans x cost/scan x margin,
   adjusted for Apple's cut. No price is picked before the study.
5. **Caps are server-side and hard.** The client never decides spend.

## Tiers (proposed, pending measured cost)

- **Free:** unlimited centering; 3 AI scans per month, no rollover.
- **Plus subscription** ($4.99/mo or $39.99/yr proposed): 25 AI scans per
  month, no rollover.
- **Scan packs** (consumable IAP; $0.99 for 5, $2.99 for 20 proposed):
  never expire, for heavy months.

Annual is discounted ~33% to reward retention. Rollover: none at launch,
for simplicity.

## Cost math (template, not a quote)

- Inputs come from the validation run: mean input/output tokens per
  observation call and dollars per scan (the spec already requires logging
  both).
- Sketch only: $0.03/scan x 25 scans = $0.75 cost on $4.99 gross. Apple's
  cut is 30% (15% for small businesses / second-year subscribers). Margin
  must also cover backend hosting and support.
- Recompute with real numbers. Cole approves the final price.

## Abuse prevention (layered, cheapest first)

1. The on-device quality gate rejects bad photos before any paid call.
   This is the biggest cost filter and it already exists.
2. Upload crops only, never full photos, downscaled to what the model
   actually needs.
3. Short structured JSON output. No freeform essays.
4. Auth required on every AI endpoint. Per-account monthly caps plus
   per-minute rate limits.
5. Provider spend cap with billing alert, plus a single-scan cost tripwire:
   pause and investigate, mirroring validation spec section 7.
6. No client-side retry on paid calls. Idempotency keys on the backend.
7. Device-level free-tier farming defenses only if abuse is observed.
   Do not overbuild this before launch.

## StoreKit and App Store shape

- Auto-renewable subscription plus consumable packs. Neither exists in
  Milestone 1.
- Receipt validation happens server-side before scans are fulfilled.
- Privacy policy and AI disclosure are required with the first build that
  uploads anything. Internal TestFlight before external.
- Review risk control: marketing copy must match the in-app honesty copy.
  Never promise a grade anywhere Apple can read it.

## Sequencing

1. M1 ships free. No monetization code.
2. Validation run measures per-scan cost.
3. Backend with caps and auth. TestFlight with paid features unlocked for
   testers.
4. Cole approves price. StoreKit lands. External TestFlight, then review.

## Open decisions (Cole's)

- Final prices and scan counts, after measured cost.
- Launch with packs, subscription, or both.
- Refund and abuse-appeal handling.
- Whether graded-price display (Scrydex, pending written permission) ever
  touches a paid tier. Pricing never changes the condition result either way.

## Non-goals

Ads. Selling user data. Any pricing mechanic that influences what the app
says about a card.
