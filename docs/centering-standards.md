# PreSlab centering standards — implementation reference for Muse

**Source-checked:** November 8, 2026 (CST).  
**Purpose:** Implement transparent comparisons against published centering guidelines in PreSlab for iOS.  
**Scope:** PSA trading cards, Beckett BGS, CGC standard cards, and TAG sports/TCG cards. Not an overall grading algorithm.

## 1. Read this before implementing

- Centering alone does **not** determine or guarantee an overall card grade.
- Corners, edges, surface, printing defects, authenticity, alteration, and other condition factors remain independent constraints.
- Use the result label **“Highest published baseline-compatible centering guideline”**, with the qualifications below.
- This is not a guaranteed grade or a hard grade ceiling: discretion, unknown rules, and other condition factors prevent that inference.
- Ratios describe maximum imbalance, normally “or better”; they are not exclusive bands or target ratios.
- A better-centered card can satisfy several rows simultaneously.
- Do not interpolate unpublished ratios, copy another company's ratios into gaps, or silently apply legacy standards.
- `null` / “NP” means no numerical ratio published in that grade description. It is **not** an automatic pass, failure, or unrestricted tolerance.
- Qualitative rules must remain qualitative unless an actual published numerical rule also exists.
- Treat the tables as versioned source snapshots; recheck official standards before future releases.

## 2. Official sources and provenance

Every linked source below was accessed during the November 8, 2026 research session.

| ID | Official source | Use |
| --- | --- | --- |
| P | [PSA grading standards](https://www.psacard.com/gradingstandards#cards) | Current card definitions and discretion |
| P-data | [PSA official grading-definition website asset](https://www.psacard.com/psa/_next/static/chunks/26xj-3rtxw1p-.js) | Full carousel definitions, half-grade and OC explanations |
| P-half | [PSA: Introducing Half Grades](https://www.psacard.com/articles/articleview/5212/introducing-psa-half-grades-more-precise-grading-your-cards) | Historical explanatory context, not a deterministic current formula |
| B | [Beckett current grading scale](https://beckett.com/grading#scale) | BGS scale and subgrade context |
| B-data | [Beckett official grading-page component asset](https://beckett.com/_next/static/chunks/9137-fe8d7f15526d7b27.js) | Current scale tab criteria |
| C | [CGC current standard card scale](https://www.cgccards.com/card-grading/grading-scale/?scale=standard) | Current standard cards; TCG versus sports/non-sports wording |
| T | [TAG grading rubric](https://taggrading.com/pages/rubric) | All centering tolerances and qualitative rules |
| TS | [TAG grading scale](https://taggrading.com/pages/scale) | Overall TAG score-to-grade bands |

**Access/provenance note:** PSA and Beckett render selected carousel/tab content initially. Their official public website assets supplied the additional definitions. Beckett's structured extraction returned all 12 scale rows but carried an `isTruncated` flag; retain that verification limitation. The Black Label row was also directly visible on Beckett's page. These are written-source findings, not confirmations from company representatives. Hashed asset URLs may change after a website deployment.

## 3. Verified published policy — PSA

All numerical rows in this section: sources [P](https://www.psacard.com/gradingstandards#cards) and [P-data](https://www.psacard.com/psa/_next/static/chunks/26xj-3rtxw1p-.js).

| Grade | Front maximum imbalance | Back maximum imbalance |
| --- | --- | --- |
| 10 Gem Mint | approximately 55/45 | 75/25 |
| 9 Mint | approximately 60/40 | 90/10 |
| 8 NM-MT | approximately 65/35 | 90/10 |
| 7 NM | approximately 70/30 | 90/10 |
| 6 EX-MT | 80/20 | 90/10 |
| 5 EX | 85/15 | 90/10 |
| 4 VG-EX | 85/15 | 90/10 |
| 3 VG | 90/10 | 90/10 |
| 2 Good | 90/10 | 90/10 |
| 1.5 Fair | approximately 90/10 | approximately 90/10 |
| 1 Poor | NP | NP |

### PSA half grades and discretion

- PSA 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, and 8.5: no separately fixed front/back ratio table.
- PSA 1.5 is separately defined above. There is no PSA 9.5.
- Current wording: “Cards that exhibit high-end qualities within each particular grade, between PSA 2 and PSA 9, may achieve a half-point increase.” PSA places “a clear focus on centering.”
- Current PSA 10 wording: “within a tolerance not to exceed approximately 55/45 percent on the front, and 75/25 percent on the reverse.”
- Do not substitute the older PSA 10 printed range of 55/45–60/40 for the current baseline.
- The visible page says: “At the grader's sole discretion, a small variance may be permitted on occasion based on the card’s overall eye appeal.”
- The official current website asset retains: “A 5% leeway is given to the front centering minimum standards for cards which grade PSA 7 or better.”
- Its example says 60/40 meets PSA 9's front standard, while 65/35 **may** meet it when eye appeal is good.
- Preserve this as discretionary context, **not** an automatic five-percentage-point expansion of every threshold.
- PSA determines centering left/right and top/bottom at “the most off-center part of the card.” Do not average away a worse axis or border variation.
- PSA's OC explanation allows an OC designation or a numerical grade reflecting minimum centering. Do not implement a qualifier-to-grade conversion formula.
- The historical half-grade article discusses five-to-ten-percentage-point improvement “in most cases,” with exceptions; do not convert that discussion into exact half-grade thresholds.

## 4. Verified published policy — Beckett BGS

This section is **BGS**, not BVG or BCCG. Sources for every numerical row: [B](https://beckett.com/grading#scale), [B-data](https://beckett.com/_next/static/chunks/9137-fe8d7f15526d7b27.js). See the extraction limitation in section 2.

| Grade / label | Front | Back | Diamond-cut wording |
| --- | --- | --- | --- |
| 10 Pristine — Black Label | 50/50 all around | 55/45 or better | No allowance listed |
| 10 Pristine — Gold Label | 50/50 all around | 55/45 or better | No allowance listed |
| 9.5 Gem Mint | 55/45 both ways | 60/40 or better | No allowance listed |
| 9 Mint | 55/45 both ways | 70/30 or better | No allowance listed |
| 8 NM-MT | 60/40 both ways or better | 80/20 or better | No allowance listed |
| 7 NM | 65/35 both ways or better | 90/10 or better | Very slight allowed |
| 6 EX-MT | 70/30 both ways or better | 95/5 or better | Slight allowed |
| 5 EX | 75/25 both ways or better | 95/5 or better | Slight allowed |
| 4 VG-EX | 80/20 both ways or better | 100/0 or better | Moderate allowed |
| 3 VG | 85/15 both ways or better | 100/0 or better | Moderate allowed |
| 2 Good | 90/10 both ways or better | “100/0 or offcut” | Noticeable allowed |
| 1 Poor | “100/0 or offcut on front or back” — combined face wording | Same combined statement, not an independent second threshold | Heavy allowed |

### BGS interpretation constraints

- “Both ways” means left/right and top/bottom.
- Current 9.5 wording is “55/45 both ways on front. 60/40 or better on back.”
- Do not substitute older “50/50 one way, 55/45 the other” 9.5 tables.
- Current Pristine rows say 55/45 back; do not substitute older 60/40-back tables.
- Grades 8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5, and 1.5 have no separately published numerical centering thresholds found in this scale.
- Official half-grade explanation: cards “typically share characteristics from both the level above and the level below the actual grade given.” Do not interpolate ratios.
- Centering is one of four BGS subgrade categories. A matching centering row cannot establish the overall grade or label.
- Both Pristine label rows share the published centering limits. Centering cannot distinguish Black Label from Gold Label.
- An explicit current all-four-10-subgrades qualification sentence was not recovered in this research; do not represent it as freshly verified text from this snapshot.
- BGS explicitly publishes 100/0 in certain low-grade rows. Retain those numbers **and** accompanying offcut wording; do not generalize them to other companies.
- The grade-1 combined front-or-back statement requires interpretation review, not conversion into two independent numerical requirements.

## 5. Verified published policy — CGC current standard cards

Every row below comes from [C](https://www.cgccards.com/card-grading/grading-scale/?scale=standard). “TCG” is kept separate from CGC's **sports and non-sports** wording; do not assume that wording supplies TCG ratios.

### CGC shared top-grade statements

| Grade | Published statement | Implementation limitation |
| --- | --- | --- |
| Pristine 10 | “The centering is 50/50.” | Face scope is not separately specified; no explicit reverse ratio. Mark scope ambiguous pending implementation review. Do not invent a back 50/50 requirement. |
| Gem Mint 10 | Approximately 55/45 front; reverse not to exceed 75/25 | Separate front/back numbers are published. |
| Mint+ 9.5 | Qualitative exceptional centering / eye appeal | No numerical front/back threshold. |

### CGC TCG intermediate and low grades

| Grade | Front ratio | Back ratio | Published qualification |
| --- | --- | --- | --- |
| 9 | NP | NP | Sports/non-sports numbers in the description do not apply automatically to TCG. |
| 8.5 | NP | NP | No numerical centering rule. |
| 8 | NP | NP | Sports/non-sports-only ratio omitted here intentionally. |
| 7.5 | NP | NP | Sports/non-sports-only ratio omitted here intentionally. |
| 7 | NP | NP | Sports/non-sports-only ratio omitted here intentionally. |
| 6.5 | NP | NP | No numerical centering rule. |
| 6 | NP | NP | Sports/non-sports-only ratio omitted here intentionally. |
| 5.5 | NP | NP | No numerical centering rule. |
| 5 | NP | NP | No numerical centering rule. |
| 4.5 | NP | NP | Sports/non-sports-only ratio omitted here intentionally. |
| 4 | NP | NP | No numerical centering rule. |
| 3.5 | 90/10 mentioned without face scope | NP | “may have 90/10 centering”; not restricted to sports, but no separate face limits. |
| 3 | NP | NP | No numerical centering rule. |
| 2.5 | NP | NP | No numerical centering rule. |
| 2 | NP | NP | No numerical centering rule. |
| 1.5 | NP | NP | “The card may be miscut.” |
| 1 | NP | NP | No numerical centering rule. |

### CGC sports / non-sports intermediate and low grades

| Grade | Published centering ratio | Separately published back ratio / scope |
| --- | --- | --- |
| 9 | 60/40 or better front | 90/10 back |
| 8.5 | NP | NP |
| 8 | 65/35 or better | No separate back figure; front/back scope not explicitly repeated |
| 7.5 | 65/35 allowed | No separate back figure; front/back scope not explicitly repeated |
| 7 | 70/30 or better | No separate back figure; front/back scope not explicitly repeated |
| 6.5 | NP | NP |
| 6 | No worse than 75/25 | No separate back figure; front/back scope not explicitly repeated |
| 5.5 | NP | NP |
| 5 | NP | NP |
| 4.5 | 85/15 | No separate back figure; front/back scope not explicitly repeated |
| 4 | NP | NP |
| 3.5 | “may have 90/10 centering” | No separate back figure; face scope unspecified |
| 3 | NP | NP |
| 2.5 | NP | NP |
| 2 | NP | NP |
| 1.5 | NP; may be miscut | NP |
| 1 | NP | NP |

### CGC version and inference cautions

- Do not infer a current CGC TCG 9–4 ratio ladder from PSA, BGS, older CGC tables, or CGC sports descriptions.
- Where face scope is unspecified, preserve the literal statement and mark scope unresolved; do not automatically apply it to both faces.
- CGC's current Legacy Grade Key maps former CGC/CSG **Gem Mint 9.5** to current **Gem Mint 10**.
- Current **9.5 means Mint+**, not the legacy Gem Mint designation.
- Legacy Perfect 10 is retired and retains legacy status; it is not the current Pristine 10 category.
- Old subgrade tables must not be treated as current rules. Subgrade-retirement context was found secondarily but not independently read from a current primary FAQ in this research; no retirement-date rule should be inferred here.

## 6. Verified published policy — TAG

Every centering row below is from [T](https://taggrading.com/pages/rubric). Overall score bands are from [T](https://taggrading.com/pages/rubric) and [TS](https://taggrading.com/pages/scale).

**SLIVER** means: “may show a tiny sliver of border, but may not be miscut or have a portion of another card displayed.” It is not a numeric 100/0 threshold.

### TAG sports cards

| Grade | Overall TAG score band | Front | Back |
| --- | --- | --- | --- |
| Pristine 10 | 990–1000 | ~51/49 | ~54.5/45.5 |
| Gem Mint 10 | 950–989 | ~55/45 | ~70/30 |
| 9 | 900–949 | ~60/40 | ~90/10 |
| 8.5 | 850–899 | ~62.5/37.5 | ~95/5 |
| 8 | 800–849 | ~65/35 | SLIVER |
| 7.5 | 750–799 | ~67.5/32.5 | SLIVER |
| 7 | 700–749 | ~70/30 | SLIVER |
| 6.5 | 650–699 | ~72.5/27.5 | SLIVER |
| 6 | 600–649 | ~75/25 | SLIVER |
| 5.5 | 550–599 | ~77.5/22.5 | SLIVER |
| 5 | 500–549 | ~80/20 | SLIVER |
| 4.5 | 450–499 | ~82.5/17.5 | SLIVER |
| 4 | 400–449 | ~85/15 | SLIVER |
| 3.5 | 350–399 | ~87.5/12.5 | SLIVER |
| 3 | 300–349 | ~90/10 | SLIVER |
| 2.5 | 250–299 | ~92.5/7.5 | SLIVER |
| 2 | 200–249 | ~95/5 | SLIVER |
| 1.5 | 150–199 | ~98.33/1.67 | SLIVER |
| 1 | 100–149 | SLIVER | SLIVER |

### TAG TCG cards

| Grade | Overall TAG score band | Front | Back |
| --- | --- | --- | --- |
| Pristine 10 | 990–1000 | ~51/49 | ~52/48 |
| Gem Mint 10 | 950–989 | ~55/45 | ~65/35 |
| 9 | 900–949 | ~60/40 | ~75/25 |
| 8.5 | 850–899 | ~62.5/37.5 | ~85/15 |
| 8 | 800–849 | ~65/35 | ~95/5 |
| 7.5 | 750–799 | ~67.5/32.5 | SLIVER |
| 7 | 700–749 | ~70/30 | SLIVER |
| 6.5 | 650–699 | ~72.5/27.5 | SLIVER |
| 6 | 600–649 | ~75/25 | SLIVER |
| 5.5 | 550–599 | ~77.5/22.5 | SLIVER |
| 5 | 500–549 | ~80/20 | SLIVER |
| 4.5 | 450–499 | ~82.5/17.5 | SLIVER |
| 4 | 400–449 | ~85/15 | SLIVER |
| 3.5 | 350–399 | ~87.5/12.5 | SLIVER |
| 3 | 300–349 | ~90/10 | SLIVER |
| 2.5 | 250–299 | ~92.5/7.5 | SLIVER |
| 2 | 200–249 | ~95/5 | SLIVER |
| 1.5 | 150–199 | ~98.33/1.67 | SLIVER |
| 1 | 100–149 | SLIVER | SLIVER |

### TAG interpretation constraints

- Preserve the approximate `~` qualifiers; do not invent an additional numerical tolerance.
- No TAG 9.5 is published in this scale.
- Grade 1's sliver wording applies to front and/or back. At the other SLIVER rows above it applies to the back.
- A numeric border ratio alone cannot determine whether a card is miscut or shows another card.
- Score bands are mappings of the **overall TAG score** to the overall grade, not a disclosed centering-to-score formula.
- Do not calculate a 1000-point TAG score by interpolating centering ratios or averaging condition categories.

## 7. Proposed implementation instructions — not grader policy

1. Require a grader profile, standard version, and applicable card category before comparison.
2. Store four independent measurements: front left/right, front top/bottom, back left/right, back top/bottom.
3. For nonnegative opposite-border measurements `a` and `b`, with `a + b > 0`, normalize imbalance as `max(a,b) / (a+b) * 100`; the other share is `100 - imbalance`.
4. Reject invalid geometry/negative widths/zero denominators; preserve original measurements and orientation for display.
5. Within each face, compare the worse axis against that face's numerical guideline. Never average front/back or horizontal/vertical results to erase a worse measurement.
6. For PSA, also preserve worst-point border variation; a single averaged border-width estimate is insufficient for a tapered or diamond-cut border.
7. Evaluate separate face rules independently. A missing back photograph is not 50/50 and cannot establish a full front/back match.
8. Retain unrounded measurements for comparison; round only display values. Do not turn rounding into an invented allowance.
9. Preserve approximate/discretionary wording and measurement uncertainty. If uncertainty crosses a boundary, return a borderline/uncertain result rather than confident compatibility.
10. Treat unknown ratios, unspecified face scope, and qualitative rules as unresolved checks, not successful checks.
11. Suggested row states: baseline-compatible, outside numerical baseline, borderline/uncertain, insufficient published information, missing measurement, and qualitative review required. Preserve individual check results rather than collapsing everything into one Boolean.
12. Report the highest fully assessable, published baseline-compatible guideline **among evaluated rows**, with visible unresolved higher rows and applicable discretion caveats. Never imply unknown higher rows were ruled out.
13. Keep qualitative review separate: sliver/no-miscut/no-other-card, BGS offcut allowances, diamond cuts, and CGC face-scope ambiguities need explicit review.
14. Surface capture limitations: perspective correction, camera/lens distortion, rotation, true diamond cutting, chosen printed frame, glare, and uncertain borders. Do not invent a universal numerical error allowance.
15. Borderless or intentionally asymmetric designs may be unassessable without a reliable design-specific reference. Return uncertainty instead of manufacturing a frame.
16. Display: “Centering fits [grader/grade] published baseline; this is not an overall grade prediction.” Add unknown-rule and discretionary exceptions where relevant.
17. Persist source links, checked date, profile version, qualifiers, raw measurements, uncertainty, and review status with results.

## 8. Proposed implementation acceptance tests

These tests validate PreSlab's interpretation logic, not a grading company's actual final decision. Numerical fixtures assume clean geometry and negligible measurement uncertainty unless stated otherwise.

| Test | Input / condition | Required behavior |
| --- | --- | --- |
| Cross-company baseline | Both front axes 58/42; both back axes 70/30 | PSA 9 baseline-compatible; PSA 10 outside baseline. BGS 8 baseline-compatible; BGS 9 outside baseline. No overall-grade claim. |
| TAG category separation | Both front axes 54/46; both back axes 68/32 | TAG sports Gem Mint 10 baseline-compatible; TAG TCG Gem Mint 10 outside back baseline. |
| Direction mirror | Compare 58/42 with 42/58 | Both normalize to 58/42 imbalance; compatibility is identical. |
| One bad axis | Front L/R 54/46, T/B 61/39; back within PSA 9 limits | PSA 9 outside front baseline; averaging axes must not rescue it. |
| Exact threshold, ideal fixture | Front exactly 55/45; back exactly 75/25; evaluate PSA 10 | Nominally compatible with the published baseline; retain approximate/discretion caveat and no final-grade guarantee. |
| Threshold uncertainty | A measurement uncertainty interval spans either side of 55/45 for PSA 10 front | Borderline/uncertain, not confidently compatible or confidently incompatible; do not invent an error margin. |
| No rounding rescue | Front 55.04/44.96, displayed as 55/45 | Preserve 55.04 internally; do not silently pass the nominal 55 threshold because of display rounding. Retain approximation/uncertainty context. |
| Missing back | Front measurements available, back photograph absent | Front-only comparison allowed; full front/back assessment unassessable, never assume back 50/50. |
| CGC TCG unknown | Evaluate CGC TCG 9 for a measured 60/40 front and 90/10 back | Insufficient published numerical information, not an automatic pass using sports rules. |
| CGC Pristine scope | Evaluate CGC Pristine with measured front/back | Preserve the literal 50/50 statement but flag unresolved face scope; do not invent a back threshold. |
| CGC unspecified reverse | CGC sports grade 8, measured 65/35 front | Preserve 65/35 statement and unresolved face/reverse scope; do not invent a 90/10 back limit. |
| Qualitative sliver | TAG sports 8 front numerically compatible, back ratio measured but no cut-content review | Qualitative review required; a ratio alone cannot establish SLIVER compatibility. |
| Actual 100/0 wording | BGS grade 4 back versus TAG SLIVER back | Preserve BGS's explicit 100/0 numerical statement; never translate TAG SLIVER into 100/0. |
| Half-grade gaps | Request PSA 8.5 or BGS 8.5 exact numerical limits | No interpolation; display no separately published threshold and qualitative context. |
| PSA leeway | PSA 9 front 65/35 with otherwise suitable measurements | Outside nominal 60/40 baseline; mention discretionary possibility separately, never auto-pass. |
| BGS label distinction | Centering matches either BGS Pristine row | Do not award or predict Black versus Gold Label from centering. |
| TAG score | Centering fits TAG Gem Mint 10 row | Do not assign a specific 950–989 score; these are overall score bands. |
| Invalid geometry | Negative width or a zero sum of opposite border widths | Invalid measurement; no compatibility result. |
| Unknown is not rejection | A higher grade has NP thresholds while a lower row is assessable | Show the unknown higher row explicitly; never call the lower row a proven grade ceiling. |

## 9. Delivery boundary

This document supplies researched standards and proposed implementation requirements only. It contains no app code, repository changes, or claim of official affiliation with any grader. Any broader pre-grade feature must independently evaluate other condition categories and disclose phone-image limitations.
