# Irrigation field layout

Source: Casey's hand sketch (`images/irrigation fields.pdf`, local only; dimensions from Google
Maps — accurate for distance; some lines will move for better spacing when
the underground system goes in). Head counts per line/zone as sketched — **to be verified by physically
counting each line** (should be close).

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

Nozzles: **5/32" Rainbird**. Counts above are physically verified
(supersede the earlier sketch estimate of 16/16/17/19).

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

- Target **≤ 8 heads per line** so that **two lines can run at once**
  (~16 heads total — right at the pump's sweet spot; see the pump curve
  notes in `TODO.md`).
- Field E becomes **two zones**: outside (5 + 2 = 7) and inside (4 + 3 = 7).
- The sketch's zone divisions are the intended automation breakup; the
  per-line head counts are the current reality.
