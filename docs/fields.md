# Irrigation field layout

Source: Casey's hand sketch (`images/irrigation fields.pdf`, local only; dimensions from Google
Maps — accurate for distance; some lines will move for better spacing when
the underground system goes in). Head counts per line/zone as sketched — **to be verified by physically
counting each line** (should be close).

## Mainline topology — distance from the pump

Order along the ~1000 ft 4"→3" mainline (confirmed 2026-08-25):

**pump → Field A (closest) → Field B (middle) → Field C → Fields D/E
(furthest, end of the line)**

Distance matters a LOT at the nozzle and only a little at the pump —
worth keeping straight (worked 2026-08-25 with the measured pump curve +
Hazen-Williams, 14 heads):

| 14 heads at… | Nozzle psi | GPM/head | Total | Pump gauge |
|---|---:|---:|---:|---:|
| 50 ft | 58.7 | 5.42 | 75.8 | 59.0 |
| 1000 ft (real mainline) | 53.8 | 5.18 | 72.6 | 59.5 |
| 1 mile | 38.7 | 4.40 | 61.6 | 60.9 |

- **At the nozzle:** less pipe → much higher pressure → materially more
  water (23% more per head at 50 ft vs a mile). Closer really is better.
- **At the pump gauge:** the opposite direction but *small* — more flow
  makes the pump slide down its own curve, worth <2 psi over a mile and
  ~0.5 psi across this system's actual 1000 ft.

So when comparing two tests, **head count dominates the pump reading**;
field distance is a ~1 psi correction, not a confound.

## Fields C, D, E — the four current "lines"

C, D and E are irrigated together as **four lines** that each run across all
three fields (line 1 at the top of the fields, line 4 at the bottom). Field E
tapers, so its lines carry fewer heads.

| Line | Field C | Field D | Field E | Heads (verified 2026-08-24) |
|---:|---:|---:|---:|---:|
| 1 | 6 | 8 | 1+3 | **18** |
| 2 | 6 | 8 | 4 | **18** |
| 3 | 6 | 8 | 5 | **19** |
| 4 | 6 | 8 | 1+6 | **21** |

Nozzles: **5/32" Rainbird** (~5.0 GPM/head at 50 psi at the nozzle,
clean). Counts above are physically verified (supersede the earlier sketch
estimate of 16/16/17/19).

**Main line**: ~1000 ft of **4"→3" aluminum latch-coupling pipe**, 11
risers/openers. Latch (lever-lock) couplings leak at the gaskets by design,
unlike glued PVC — so flow through the pump exceeds nozzle flow, and there's
friction loss between the pump and the field.

Rotation today: 3 → 1 → 4 → 2, one line at a time, changed once a day
(morning normally; evenings when the schedule is flipped).

## Field A — 4 zones (240 × 230 ft)

Zones of **6, 6, 6, 7** heads; an optional **+2 per line** for the back
yard. Separate from the C/D/E lines ("the other zones").

Satellite view (`images/field-A-satellite.png`, local): the four lines are
visible as light stripes running east–west across the field, with the
**pond at the south edge, the pump house beside it** — so Field A is the
field nearest the pump. West of the field is the bare ground and trench of
"the back", the area the future automated lines (+2 per line) would cover.

## Satellite imagery (local, `images/`, gitignored)

Casey pulled these from Google Maps 2026-08-24; per-field zone counts here
are Casey's intended automation breakup (the current C/D/E watering is by
the 4 cross-field lines, not these per-field zones).

| File | Field | Zones | Notes from the image |
|---|---|---|---|
| `field-A-satellite.png` | A | 4 | 4 lines visible as faint E-W stripes; pond + pump house at the south edge; bare "back" area and a trench to the west |
| `field-B-satellite.png` | B | 3 | long narrow field (190 x 310); faint line traces; a structure at the SW corner |
| `field-C-satellite.png` | C | 4 | **4 irrigation lines clearly visible** as bright N-S lines across the field; a lone tree mid-field; structure at SW |
| `field-D-satellite.png` | D | 4 | 4+ bright N-S lines; several trees dotting the field; road along the west edge |
| `field-E-satellite.png` | E | 2 | tapered field on **Powell Butte Rd** (SE corner); the tapering that gives lines 1-4 fewer heads here (2/3/4/5) is visible; to become 2 zones (outside 7, inside 7) |

## Field B — 3 zones (190 × 310 ft)

Zones of **7, 7+1 = 8, 7** heads; **zones 2 + 3 currently run together
(15 heads)**.

## Future automation plan

Planned run patterns (both keep the pond full — usage balances with COID
inflow + recycle):
- **Field A**: 18 heads, then 7 + 7 (14).
- **Field B**: 7 + 7 (14).

**Underground conversion goal (~½ the water).** Converting the aluminum
latch-pipe + impact heads to underground **glued PVC** with in-ground
**Falcon** heads is expected to cut water use roughly in half:
- glued PVC eliminates the gasket leakage entirely (measured: the laterals
  leak — see the line-4 loss data in TODO.md);
- in-ground Falcon heads are more efficient than aging impacts;
- proper spacing cuts overlap waste.
Pursuing a **COID grant** to help fund it — the district funds on-farm
efficiency/piping conversions, and with COID cutting deliveries to ~60%
(2026), conservation projects are exactly what they want to support. The
measured leakage + per-line flow data is real supporting evidence for an
application.

Pump-match note: the pump's BEP flow is ~100 GPM; the current 18-21 head
lines (~86-99 GPM) sit right in that sweet spot, so they are better matched
to this pump than the previous owner's 16-head standard (slightly low-flow
of ideal). Head counts above ~21 would push past BEP toward the 5 HP motor
limit.

### Build plan (Casey, 2026-08-25)

**Phase 1 — Field A (proof of concept), then repeat for Field B.** A & B
are doable, and once done they water themselves — no help needed for
vacations etc. They also produce the before/after data for the C-E grant.

1. Buy a trencher + a hydraulic diverter valve for the tractor.
2. Trench Field A.
3. Buy pipe, conduit, fittings, valves, sprinklers, primer, glue, wire,
   boxes.
4. Install pipe, fittings, sprinklers, valves.
5. Install conduit + wiring.
6. Install valve boxes (access + protection).
7. Remove the risers → plumb in the valves.
8. Test zones 1-4 **by hand**.
9. Repeat the test **with the controller** (`pump-controller.yaml`).
10. Fill in, over-seed, fertilize.

**Phase 2 — Fields C-E (~4x the area of A). Needs more planning.**
- Each current cross-field line becomes 3 runs:
  - **Field C:** valve → pipe → sprinklers.
  - **Field D:** valve → pipe (no sprinklers) → pipe + sprinklers at the
    end; conduit runs to a box at the watering area by the fence.
  - **Field E:** mainline through C & D → **2 valves** → pipe + sprinklers;
    conduit to a box by the gate.
- Open design questions:
  - Add an extra line along the fence with **180° (part-circle) heads** to
    water the edge properly? (Recommended — see spacing notes below.)
  - Current line spacing is uneven (~30 + 60 + 60 + 50 ft). Re-layout for
    **even, optimal spacing** rather than reusing the old riser positions.

### Head spacing & the Falcon flow question

- **Fence line with 180° heads: yes.** Part-circle heads on the boundary
  are standard practice — full-circle heads set back from the edge leave
  the last ~half-radius under-watered, and pushing them to the fence
  throws half their water off the property. A perimeter run of 180° heads
  fixes both.
- **Spacing rule:** heads should be spaced at **~50% of throw diameter
  (= one radius, "head-to-head")**, and Central Oregon wind argues for
  ≤50%, not more. Don't trust a 60 ft catalog throw at working pressure:
  a Falcon's radius depends on nozzle and pressure, and our nozzles see
  ~45 psi, not 50-60. Measure one head's real radius at real pressure,
  then lay the grid at that radius — triangular pattern if the field shape
  allows (better uniformity than square). **Re-layout is worth it**; the
  old 30/60/60/50 spacing was set by riser convenience, not coverage.
- **⚠️ Falcons flow MORE per head than the current 5/32" impacts.** The
  whole pressure/zone model in TODO.md (heads → GPM → pump psi, the
  12-head floor) is built on ~4.7 GPM/head. A Rain Bird Falcon 6504 runs
  ~4 to 20+ GPM depending on nozzle. So zone sizing for the new fields is
  **by GPM, not head count**: pick the Falcon nozzle and heads-per-zone so
  each zone lands in the pump's good window (~60-100 GPM, near BEP). E.g.
  8 Falcons on a ~9 GPM nozzle ≈ 72 GPM ≈ today's 14-15 impact heads.
  Fewer, bigger heads per zone — re-run the zone table once the nozzle is
  chosen.

- Target **≤ 8 heads per line** so that **two lines can run at once**.
  Note: two 8-head lines = 16 heads ≈ 76 GPM, which is slightly BELOW the
  pump's BEP (~100 GPM ≈ 21 heads at ~4.7 GPM/head). If pipe/head capacity
  allows, ~10 heads/line (20 total) sits closest to BEP; the ≤8 target is
  presumably driven by pipe sizing / per-head pressure rather than pump
  match. (See the pump curve + flow notes in `TODO.md`.)
**Zone building blocks & schedules:**
- 6 heads = smallest line. 12 = two 6-head lines. 13 = 12 + 1. 7 = a line.
  14 = two 7-head lines.
- **Near-term (current pipe, manual valves):** run **12, 13, 7, 14** on
  **12-hour** sets.
- **Fully automated (underground + automated valves):** run **6, 6, 6, 7,
  7, 7, 7** (seven small zones, 46 heads total) on **4-hour** timers.

- Field E becomes **two zones**: outside (5 + 2 = 7) and inside (4 + 3 = 7).
- The sketch's zone divisions are the intended automation breakup; the
  per-line head counts are the current reality.
