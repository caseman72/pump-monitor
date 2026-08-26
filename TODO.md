# TODO

Working list for the Pump Monitor node. Numbers below are first guesses —
revisit after the ~2-week pressure-monitoring period (Aug/Sep 2026).

## Definitions

- **BEP — Best Efficiency Point**: the flow rate on a pump's H-Q curve where
  it converts the most input (electrical/shaft) power into useful water power
  — i.e. peak pump efficiency. Running far from BEP wastes energy; the far
  extremes also stress the pump (recirculation/cavitation at very low flow,
  motor overload at very high flow). For this Goulds 3656 the published BEP
  is ~73% efficiency at ~100 GPM.
- **TDH — Total Dynamic Head**: the head the pump itself adds, in feet of
  water (1 psi ≈ 2.31 ft). Here TDH ≈ (gauge psi − ~0.4 psi suction boost)
  × 2.31. The suction boost is only ~0.4 psi because the pump sits just
  **1 ft** below the pond surface (corrected 2026-08-24 — the intake is
  10 ft below the pump, but intake depth adds no head; the free surface
  sets it).
- **Shutoff / dead-head**: zero-flow condition — all outlets closed. The
  pump makes its maximum pressure but no flow, so it just heats the trapped
  water (dangerous for a running pump; hence the ICE high-pressure trip).
- **ICE — In-Case-of-Emergency**: the pump-protection relay layer (see the
  ICE sections below and the README).
- **WHP — Water HorsePower**: hydraulic output power = GPM × TDH(ft) ÷ 3960.
- **COID — Central Oregon Irrigation District**: the water supplier.

## 0. Project roadmap & risk model (Casey, 2026-08-24)

**Now — no safety layer needed.** The pump runs near max against the
always-open irrigation lines (manual aluminum pipe, controller-independent).
That big open flow path means the pump can't dead-head no matter what the
controller does. Lawn zones add only ~2 psi on top. This is why the ICE
pump-kill isn't being wired (see the decision in section 1) — there is
simply nothing for it to protect against yet.

**Future — automated zones, where the recycle system becomes load-bearing.**
Field A first: 4 zones, **underground glued PVC**, in-ground **Falcon**
heads, ~8 heads/zone (maybe 10 depending on spacing — call it the flow-
equivalent of ~8 sprinklers). When an automated zone switches, all paths can
momentarily close → dead-head. With no always-open irrigation line in that
scenario, **the recycle system MUST work flawlessly** to dump pressure to
the pond. It will NOT be allowed to run un-manned / un-fail-safed until
proven.

### Validation plan — prove recycle before trusting it

**Step 1 — build the sprinkler node.** Convert the 2 existing pump-house
lawn zones to an Arduino/ESPHome sprinkler controller (the second PLC-100;
24 VAC solenoids). This is the automation testbed.

**Step 2 — the bounded-risk recycle stress test.** Set up a HIGH-pressure,
LOW-flow scenario and force dead-head events at the recycle system:
- Run just **6 sprinklers** (one short line) with the pump-monitor holding
  pressure at **BEP**. Low flow → pressure runs high (near shutoff), the
  hardest case for pressure control.
- Cycle the 2 lawn zones **open → close → open → close → off** — each close
  is a dead-head event the recycle valves must catch by opening to the pond.
- **Why it's safe to fail here:** the 6-sprinkler line is always open and
  the automation can't close it, so the pump ALWAYS has a flow path — it
  never truly dead-heads. If the recycle logic fails, pressure spikes toward
  the 6-head operating point and may **break a PVC fitting ($ + time)** —
  but never damages the **pump ($$$$)**. Pump safety is guaranteed by
  construction (the un-closeable minimum path), so only the recycle control
  logic is on trial.

Only after the recycle system is proven flawless in this bounded test does
it earn the right to run Field A's automated zones un-manned.

## 1. Staged pressure response (the real control system) — NOT YET

> **SMALLEST ZONE IS 12 HEADS, NOT 6 (Casey, 2026-08-25).** Field A lines
> 2-4 are 6 heads each, but a lone 6-head line is a waste for a 5 HP pump
> (32 GPM at 60 psi — most of the work goes into unused pressure), so zones
> are built as pairs: **12 = the floor.** This resolves every problem the
> 6-head case created:
>
> | smallest zone | pump psi | margin to shutoff | recycle to hold 55 | ICE @ 60 |
> |---:|---:|---:|---:|---|
> | 6 | 60.0 | 1.2 psi | 58% | false alarms |
> | **12** | **56.8** | **4.4 psi** | **18%** | **safe** |
>
> Operating envelope = 12-21 heads = ~56.8 → 50.3 psi, a ~6.5 psi range with
> 55 psi comfortably mid-window. The "pressure is a weak discriminator /
> ~1 psi band" concern was a 6-head artifact and no longer applies to
> normal operation (it still argues for the passive thermal backstop in
> section 6 as defense-in-depth). ICE at 60 trips ONLY on genuine control
> failure, since every real zone runs ≤ 56.8. Remaining test: **10 heads
> via 2×5** (safe, predicts ~58.1) and **12** (predicts ~56.8) — skip 6 and 5.

> **Control target & ICE setpoint — Casey's plan, 2026-08-25.** Since the
> system can never actually reach 60 psi in normal use (55.5 at 14 heads is
> today's max), **control recycle to hold ~55 psi**, and set **ICE at 60**.
> Quantified cost (pump then always runs 73.3 GPM):
>
> | zone | delivered | recycled | % |
> |---:|---:|---:|---:|
> | 14 | 69.5 | 3.8 | 5% |
> | 12 | 60.4 | 12.9 | 18% |
> | 10 | 51.0 | 22.3 | 31% |
> | 8 | 41.2 | 32.1 | 44% |
> | 7 | 36.2 | 37.1 | 51% |
> | 6 | 31.1 | 42.2 | 58% |
>
> At 6-7 head zones **recycle exceeds delivery**. Water returns to the pond
> so it isn't lost, but the energy is. NOTE: the pump does NOT need this for
> steady-state protection — un-recycled, 6 heads runs **32.5 GPM at 60.0
> psi**, above the ~25-30 GPM minimum continuous flow. So 55 psi is
> **insurance for zone transitions** (recycle already open = guaranteed flow
> path when a zone closes), not a necessity. A 57-58 psi target would cut
> the recycle fraction substantially if trading margin back is acceptable.
>
> **ICE at 60 psi** sits above the 55 target and below the 61.3 fitted
> shutoff, so it reads as *"the recycle control has failed"* — a useful
> alarm. ⚠️ Dependency: 6-head zones naturally run at 60.0 psi, so ICE at 60
> **false-alarms on any small zone run WITHOUT the recycle loop active**.
> Only correct while the control loop is running.
>
> **Thermal burst valve + IR temp baseline** (Casey): measuring cast-iron
> casing temp before/after the low-flow runs with a laser thermometer is the
> direct measurement of the actual damage mechanism (heat, not pressure) —
> it will show whether 32 GPM at 60 psi is genuinely benign. Pairs with the
> thermal relief valve in section 6.

> **Design principle — recycle is PROTECTION/RELIEF, not efficiency
> (2026-08-24, Casey asked "open recycle at 14 heads?"): NO.** This pump's
> input power rises with flow, so adding recycle to push flow back toward
> BEP spends MORE kWh to deliver the SAME irrigation — the extra flow goes
> to the pond, wasted. Pump efficiency % goes up but useful-water-per-kWh
> goes DOWN. At 14 heads (~70 GPM ≈ 70% of BEP) the pump is healthy: well
> above its minimum continuous flow (~25-40 GPM), pressure ~55 psi (below
> the ~65 dead-head and far under the 150 psi pipe rating), and the pond
> stays full on its own. So do NOT recycle for "efficiency." Recycle earns
> its keep ONLY near the pump's minimum flow / dead-head — i.e. automated
> zone transitions where all heads briefly close, or a genuinely tiny load.
> That is the relief role the staged controller below implements.

> **DECISION 2026-08-24 — the ICE pump-kill relay is NOT being wired into
> the pump loop this year, and maybe ever.** Solid reasons (Casey):
> *stopping* the pump is itself the risky/expensive act (~$500 to recover,
> per last year; the pump has been off only 2x all season) and stresses the
> latching starter; the Furnas + thermal overloads already cover the
> low-side/overload cases; and a pump-kill on overpressure would trade a
> known-cost failure for the recycle path instead.
>
> ⚠️ **Rationale correction needed (2026-08-24):** an earlier version of
> this note claimed "the recycle valves fail OPEN, so the recycle system is
> inherently fail-safe against overpressure." **That is WRONG** — the
> motorized ball valves are hold-last-position (motor-driven, no spring
> return): on power/Wi-Fi/controller loss they STAY WHERE THEY ARE. A
> closed recycle valve stays closed. So the recycle valves are NOT the
> fail-safe. The real guaranteed flow path is most likely the
> **always-running irrigation lines** (manual aluminum pipe, independent of
> the controller) — TBC with Casey. Open gap: all lines closed + a recycle
> valve closed + controller down = dead-head. Need to confirm a line is
> always open during operation before treating overpressure as fully
> covered without the kill.
>
> **The ICE stays firmware-only: a monitoring/alert layer, relay never
> actuating the pump loop.** The ICE High Trip is an ALERT threshold now,
> not a kill point — its exact value (and the dead-head-margin/worn-pump
> question) is no longer safety-critical, but the dead-head SCENARIO above
> still needs an answer.

Today the ICE layer is a plain threshold: ≥ High Trip (95 psi) for 3 s →
open the pump loop. The intended system is staged: the recycle valves
absorb pressure first, and cutting the pump is only for the case where
that response has already failed. A pump cut should never be an anomaly
the system didn't see coming.

Zones (on `Pump Pressure`):

| Zone | Condition | Response |
|---|---|---|
| **Green** | ~48–62 psi at the gauge (BEP = best efficiency point, ≈ 57; below ~46 the 5 HP motor is at full load — overload territory; above ~62 flow is dropping toward dead-head at ~70) | nothing |
| **Yellow** | > ~62 psi (or < ~48) | Valve 1 opens in steps (Pulse +) until pressure is back in band; when Valve 1 reaches 100%, Valve 2 starts opening the same way. Low side: pressure < ~48 means flow > ~140 GPM — motor near full load — so the response there is to CLOSE recycle, not open |
| **Red** | > ~64 psi with **both** valves at 100% | hold and wait — ~1 min — for the recycle path to bring it down |
| **DEFCON 1** | at/near dead-head (~66+ psi at the gauge), both valves 100%, sustained | cut power to the pump (ICE trip, latched). Interim: the flat 65 psi ICE High Trip is live today. NB: the pump physically cannot exceed ~70 psi at the gauge, so 80 was unreachable |

Design notes:
- **Recycle is PROPORTIONAL, not all-or-none** (Casey, 2026-08-24): the
  valves are 0-100%, so the controller MODULATES the recycle opening to
  hold pressure below the setpoint (a trim loop on pulse position), cracking
  open just enough to bleed excess pressure and closing as load returns —
  smoother and less wasteful than open/shut. The "threshold" is the setpoint
  the loop holds under, not a trip.
- [~] **Low-flow pressure tests — STARTED 2026-08-25.** First point in:
      **14 heads (Field A-1 (7) + B-3 (7), the shortest lines) = 55.5 psi**
      at the pump (recorder, 20:02-20:59, very stable ±0.4). Predicted ~54,
      so the curve steepens a bit faster at low flow than linear.
      Note (2026-08-25): field order from the pump is **A (closest) → B →
      C → D/E (furthest)**, and the 14-head test used the two CLOSEST
      fields. Distance does push pump pressure slightly DOWN (more flow,
      pump slides down its curve) while fewer heads push it UP — but
      **the distance effect at the PUMP is small**: worked with the real
      curve + Hazen-Williams, 14 heads at 50 ft vs 1 mile is only
      59.0 vs 60.9 psi, and 50 ft vs the actual 1000 ft mainline is ~0.5
      psi. So the 4 psi vs the 18-head lines is essentially all head-count;
      an earlier note here overstated distance as "masking" it.
      **Implication:** a single 7-head zone likely lands ~58-62 psi,
      crowding the ~65 psi dead-head estimate — the recycle threshold has a
      NARROW band to live in. The worst case (highest normal pressure) is
      the **smallest zone at the FURTHEST field** (D/E) — but only by ~1 psi
      over Field A, since distance moves the PUMP gauge very little (see
      above). Head count is what sets it.
      Measure the smallest zone AT D/E plus true dead-head before setting
      the threshold. (This also tightens the ~3 psi window that section 6's
      thermal-relief reasoning is built on — supports that conclusion.)
      **BONUS — transducer zero confirmed:** the recorder caught a pump-off
      window (19:57-19:59) reading **0.1 psi** (0.0-0.2). Exactly what the
      corrected 1-ft suction geometry predicts (~0.4, within noise) and
      proof there's no large offset. Together with the Boshart gauge
      agreement at 50 psi, the transducer is confirmed at both ends.
      Still to run: 12 (6+6) and the **6-head** line (Field A lines 3-4 are
      6 heads each). **SKIP the 5-head test** (closing a head on a 6): the
      curve fit says 6→5 gains only **0.37 psi** of signal — under 2x sensor
      noise — for real risk. Casey's instinct ("gets dicey, potential
      energy") was right.

      ### Pump curve FITTED to the three measurements (2026-08-25)

      Fit to (99,50.3) (88,51.4) (72.6,55.5) — flows derived from nozzle
      pressure — gives **H = 61.3 − 0.001165·Q²**, matching all three within
      0.8 psi:

      | heads | est. pump psi | margin to shutoff |
      |---:|---:|---:|
      | 21 | 50.7 | 10.6 (measured 50.3) |
      | 18 | 52.8 | 8.5 (measured 51.4) |
      | 14 | 55.5 | 5.7 (measured 55.5) |
      | 12 | 56.8 | 4.4 |
      | 10 | 58.1 | 3.2 |
      | 8 | 59.1 | 2.1 |
      | 6 | 60.0 | **1.2** |
      | 5 | 60.4 | 0.9 |

      **⚠️ FITTED SHUTOFF ≈ 61.3 psi, NOT the ~65 psi the published Goulds
      curve implied.** Consistent with the measured ~52-62% efficiency (real
      curve sits below published). Caveat: all three points are 72-99 GPM,
      so the low-flow end is a long extrapolation — the 6-head run will test
      it directly (predict ~60.0 psi).

      **Consequences:**
      - [ ] **ICE High Trip (65 psi) is UNREACHABLE** — the pump can't make
        65, so the alert can never fire. Same failure as the old 80 psi
        setting, repeated. It's alert-only (relay not wired) so nothing is
        unsafe, but it should be lowered (~59-60) or the approach rethought
        once the 6-head run confirms shutoff.
      - A 6-head zone runs ~1.2 psi below dead-head → **pressure cannot
        discriminate "smallest zone normal" from "dead-headed"** at that
        size. Directly supports section 6's thermal-relief conclusion, now
        with fitted numbers rather than estimates.
- [ ] ~~Low-flow pressure tests — Casey to run 2026-08-25 (tomorrow).~~
  Run reduced-head sets and read the steady pump pressure to extend the
  pressure-vs-heads curve (currently only 18 = 51.7, 21 = 50.3 psi — too
  clustered to extrapolate to the small zones). Targets: **14 heads** (7+7),
  **12** (6+6) if convenient, and ideally the **6-head** smallest line and a
  brief **13**. Each fills the lower end of the curve and pins the recycle
  setpoint. Tell Claude roughly when each ran; pull the plateaus from the
  recorder via `tools/ha_pressure.py`.
- **Recycle-open threshold is a PRESSURE, not a flow** — the sensor reads
  pressure, and low flow shows up as HIGH pressure (pump climbing toward
  shutoff). So recycle opens ABOVE a pressure threshold, which must sit
  between the smallest normal zone's pressure and dead-head (~65 psi).
  We have only 2 measured points (18 heads = 51.7, 21 = 50.3 psi) — too
  clustered to extrapolate reliably to low flow (the curve steepens near
  shutoff). Rough estimates: 6-7 head zone ~58-60 psi, dead-head ~65, so a
  PROVISIONAL threshold ~61-62 psi — but DO NOT bake that in. Set it from
  measurement: (a) run the smallest zone you'll actually use and read its
  steady pressure, (b) slow main-valve close for true dead-head, (c) set
  the threshold ~3-4 psi above the smallest-zone pressure. The roadmap's
  stress test (section 0) produces both numbers directly.
- Valve response uses the pulse primitive (no re-home transient); the
  order is Valve 1 to 100% before Valve 2 starts.
- Below 30 psi (Yellow-low) is the dry-run / line-break side — response TBD
  (probably close recycle valves first, then Low Trip).
- The DEFCON 1 condition replaces the current flat 95 psi trip: it requires
  *both* the pressure and the evidence that the valve response failed.
- Should run **in the firmware** (must work with HA / Wi-Fi down), with
  setpoints as HA numbers and a master enable switch; HA only observes.
- Eventually a feedforward table per irrigation line (line 16 → Valve 1
  27%, line 15 → 33%, …) plus a slow PI trim holding ~55 psi, with a
  deadband (±1–2 psi) and a minimum interval between steps (30 s+) so it
  doesn't hunt — the valve's authority is all in pulse counts ~1–6.

## 1a. Pressure observations (feedforward table data)

Model: **base pressure per irrigation line + delta per lawn zone**. Lawn
zones ride on whichever irrigation line is running, so their effect is a
delta from that line's base, not an independent setpoint. Deltas are only
roughly additive (a zone's draw shrinks slightly as base pressure falls);
the PI trim absorbs that. Recycle valves closed unless noted;
transducer-calibrated psi.

Naming: **line N** = the long irrigation lines (line 1 = smallest/shortest);
**lawn zones 1–4** (house system, evenings; they never run alone — always on
top of an irrigation line); **pump zones 1–2** (mornings
~5–6 am). Casey: "lawn zone 1 (front) is my shortest long line" — to confirm
exactly how zone 1 relates to line 1.

### Base pressure per irrigation line

Head counts confirmed by physical count + line tests 2026-08-24
(`docs/fields.md`; nozzles are **5/32" Rainbird**): line 1 = 6+8+1+3 = **18**,
line 2 = 6+8+4 = **18**, line 3 = 6+8+5 = **19**, line 4 = 6+8+1+6 = **21**.
Main line: ~1000 ft of 4"→3" aluminum latch-coupling pipe, 11 risers/openers
(leaks at gaskets by design — not glued PVC).

**Measured base pressures (recorder + Casey's notes, 2026-08-24 11:00-11:45):**

| Line | Heads | Base psi | Notes |
|---|---:|---:|---|
| line 1 | 18 | **51.4** | 11:00-11:12 |
| line 2 | 18 | **51.7** | 11:13-11:17; "same as 1" — matches (same head count) |
| line 3 | 19 | **51.4** | 11:19-11:36; read 52.2 with one head off, 51.4 with all 19 on |
| line 4 | 21 | **50.3** | 11:38-11:45 |

**KEY FINDING — the lines are nearly flat**: only ~1.4 psi spread across
18→21 heads (51.4 / 51.7 / 51.4 / 50.3). The earlier pipe-count model
predicted a much steeper psi-per-head slope; reality is far flatter because
the pump sits near BEP (flattest part of the curve) and the 5/32" Rainbird
nozzles flow less per head than the earlier ~7.8 GPM guess. Consequences for
the controller:
- The feedforward table barely needs a per-line term — all four lines are
  within 1.4 psi. The recycle valves will mostly be trimming the *pump*
  (season, wear, pond, temperature), not compensating line-to-line jumps.
- Line 4 (21 heads) at 50.3 is the lowest — still well inside the control
  band, nowhere near the ~46 psi motor-load floor. Two lines at once (the
  ≤8-head-per-line goal) would land ~36-42 heads → meaningfully lower
  pressure; that's the case the recycle system actually has to manage.

**Flow & efficiency (nozzles = 5/32" Rainbird ≈ 5.0 GPM/head @ 50 psi, clean):**
- Measured operating points: line 1 ≈ 91 GPM @ 51.4 psi, line 4 ≈ 106 GPM @
  50.3 psi (√P-corrected per-head flow; TDH = (gauge − 0.4 psi suction) × 2.31
  ≈ 117-118 ft across all lines — corrected suction geometry, was mistakenly
  ~107 ft with a wrong 5 psi boost).
- **Efficiency RESOLVED 2026-08-24 with measured first/last-head + pump
  pressures on line 4 (21 heads, 5/32" Rainbird = 5.0 GPM @ 50 psi):**
  - Pump gauge 49 psi (HA transducer 50.0 — agree; transducer confirmed
    accurate, see above). Pipe-0 (field entry) 45.2, pipe-21 (last head)
    44.0.
  - **Mainline loss = 3.8 psi** (pump→field, ~1000 ft 4→3"); **lateral
    loss = 1.2 psi** across all 21 heads (very even — heads run within ~1
    psi of each other, so flow is nearly uniform end to end).
  - Nozzle pressure ~44.6 psi avg → **4.72 GPM/head → ~99 GPM** nozzle flow.
  - TDH ≈ 112 ft → hydraulic ≈ 2.1 kW ÷ ~4.1 kW shaft = **≥51% pump
    efficiency** (nozzle-flow lower bound; real pump flow ≥ nozzle flow due
    to gasket leakage, so with 10-20% leakage efficiency is **~56-62%**).
  - **Line 4 is the WORST case** — longest line (21 heads, 3 more than lines
    1/2 at 18, 2 more than line 3 at 19). So these loss numbers are the
    ceiling: shorter lines have LESS mainline loss (less flow), LESS lateral
    loss (fewer heads), and HIGHER nozzle pressure → more GPM/head + even
    more uniform distribution. Confirmed by the pump-gauge data: line 1
    (18) ran 51.7 psi at the pump vs line 4 (21) at 50.3 — shorter = ~1-1.5
    psi higher. (Pump EFFICIENCY is ~the same across all four, though — they
    cluster in a tight 50.3-51.7 psi / ~86-99 GPM band, all the same healthy
    point on the curve.)
  - **Verdict: healthy pump running slightly off-BEP. No wear.** The earlier
    ~49% "possible wear" flag is retired — it was under-counting flow
    (nozzle≠pump) and assuming an unverified transducer; both now fixed.
    Combined with the confirmed-failed cap (18.3 µF), fresh cap, and packing
    at spec, nothing points at pump wear.

**COID delivery cut (2026-08-24, from Central Oregon Irrigation District):**
Deschutes River natural flows are dropping; COID is reducing deliveries to
**~60% (fluctuating)** for patrons. Real operating constraint — less inflow
to the pond, so the recycle-to-pond strategy has to account for a pond
that may not refill as fast, and total irrigation may need to be rationed.
Worth wiring pond level into HA eventually so the controller can see it.

  **Water-balance synthesis (Casey, 2026-08-24):** at 60% delivery, the
  forced response is to WATER LESS (fewer heads / shorter runs) to match
  reduced inflow — else the pond drains. That's the efficient response
  (pump less → save pond AND energy). Recycling does NOT help the pond
  (net-zero: pond→pump→pond) and costs energy, so it's the wrong tool for
  the water shortage. BUT watering less = smaller loads = pump runs nearer
  its low-flow edge, so recycle's PROTECTION role becomes more relevant: it
  ENABLES running small conservation-driven loads without dead-heading the
  pump. Keep it minimal (proportional trim), never a way to "use up" water.
  The structural fix for sustained cuts is the underground conversion
  (~½ the water, see docs/fields.md) — that's what lets 60% delivery
  actually cover the need.

### Pump maintenance history (for context on motor margin)

Two separate events, not one visit — corrected 2026-08-24 after conflating
them:

- **Pump packing replaced** (2026, Casey) — new, and adjusted to the
  standard **~1 drip/sec** at the gland (proper shaft lube/cooling, NOT
  over-tight). So packing is a non-factor for current efficiency: no
  parasitic drag, and the drip is negligible flow (~0.0008 GPM). The 2024
  Sense power data predates it, so what the OLD packing was doing is
  unknown — the only reason it's noted here.
- **Overload heaters upsized** — self-installed by Casey, sized from the
  motor's known amp draw; the pump guy approved the sizing. Fixed
  occasional drops at the high-flow end (consistent with the curve — line
  4 + a lawn zone runs the motor near/at full load). Date unknown; Casey
  may still have the box/receipt. With bigger heaters there's less
  thermal margin, so the controller's pressure floor (~46–48 psi at the
  gauge) is a real motor-protection constraint, not just an efficiency
  preference.
- **Separate paid service visit**: pump leads upsized 12 → 10 AWG (12 AWG
  is only 20 A-rated vs ~23 A full load — hot leads + voltage drop = extra
  current = nuisance heater drops), a new **HAND-OFF-AUTO selector relay**
  installed (this is why the HOA switch exists at all — it wasn't there
  before), and the run capacitor tested low on capacitance and was
  replaced, week of 2025-07-06 (see the Sense historical-data section
  below for why that date matters). Installer's clamp reading during this
  visit was somewhere in 20–30 A (not precisely recalled) — 87–130% of
  the 23.1 A nameplate, too wide to place on the curve; a fresh clamp
  reading with the running line noted would pin it. Casey: total bill
  ~$500, most of it diagnosis/labor rather than parts.

### Lawn zone deltas (measured on line 1)

Lawn zones are Rain Bird-type pop-ups and watering tips — small loads
(~2–20 GPM each, i.e. two or three irrigation heads at most), unlike the
~7 GPM impact heads on the irrigation lines. Flow estimates use the
curve slope near the operating point (~0.2–0.25 psi per GPM).

| Lawn zone | psi observed | Delta | Date |
|---|---:|---:|---|
| zone 1 (front) | 47.4 | −4.1 | 2026-08-23 (≈ +15–20 GPM) |
| zone 2 | 48.5 | −3.0 | 2026-08-23 (≈ +12–15 GPM) |
| zone 3 | 49.8 | −1.7 | 2026-08-23 (≈ +7 GPM) |
| zone 4 | 51.1 | −0.4 | 2026-08-23 (≈ +2 GPM, drip/tips; or baseline drift) |

### Motor load via Sense (whole-house energy monitor)

Clamping the leads means opening the panel. Sense can't fingerprint the
pump (24/7 load, lives in "Always On"), so use the **whole-house total**:
pump OFF (HAND→OFF for a minute, house quiet) → baseline; each line
running → the delta is the pump's input power. Line-to-line deltas
(~0.3–0.4 kW between line 1 and line 4) work without a pump-off. Nameplate full load ≈
23.1 A × 230 V × 0.92 PF ≈ **4.9 kW** (amps ≈ W ÷ 212).

| Running | Predicted input | Motor load |
|---|---:|---:|
| 13 heads (BEP) | ~4.1 kW | ~83% |
| 16 heads | ~4.4 kW | ~90% |
| line 1 (17) | ~4.5–4.6 kW | ~93% |
| line 3 (19) | ~4.75 kW | ~97% |
| line 4 (21) | ~4.9 kW | ~100% |
| line 4 + lawn zone 1 | ~5.1–5.2 kW | into 1.15 SF |

Measured (Sense pump-only CT, Sep 7–18 2024, 30 cursor points from Casey's
screenshots):

| Mode | kW | Motor load (of 4.9 kW nameplate) |
|---|---:|---:|
| line plateaus (4 lines + variation) | **4.41 / 4.53 / 4.62–4.65 / 4.74–4.75 / 4.81–4.82** | 90–98% |
| Sep 11 daytime (anomaly) | ~5.4 | 110% — two lines at once? |
| pump zones, 6:22–6:54 AM | **5.40–5.58** | 110–114% — at the 1.15 SF ceiling (5.6 kW) |
| lawn zones, 7:16–7:38 AM/PM | 5.0–5.4 | +0.4–0.7 kW ≈ +30–55 GPM (more than the ~15–20 GPM from today's psi deltas — resolve with simultaneous psi + kW) |
| morning line-switch spikes | ~6.2 (chart) | ~125% briefly — the open-before-close overlap; keep it short |

Conclusion: the motor runs just under full load on every line; the morning
pump zones sit right at the service-factor limit (why the original heaters
dropped). Curve predictions (4.55–4.9 kW) matched the plateau band.
Energy ≈ 4.7 kW × 24 h ≈ 113 kWh/day.

### Season cost estimate vs. Casey's actual 2025 tracking

- Confirmed from the archive: water is off **Oct 15** every year (Casey) —
  visible directly in the data as a wall of Sense `-1` "no data" hours
  starting right at Oct 15 in both 2022 and 2024 archives. Season is
  **May 1 – Oct 15 (~168 days)**, not the full May–Oct calendar months.
  Mid-season `-1` blips (a handful of hours here and there, ~15 instances
  across the archive) are real short pump-stop events, already correctly
  excluded by the "full 24h ≥3500W" day filter used for the averages below.
- Full-running-day averages by year (same filter as the kWh/day figures
  above), May 1–Oct 15 only: **2022 = 108.9, 2023 = 112.2, 2024 = 114.0
  kWh/day**.
- At Casey's rate (**8.66 c/kWh**): 180-day season cost ≈ **$1,698 (2022)
  / $1,750 (2023) / $1,778 (2024)**.
- **Casey's actual 2025 spreadsheet: $1,558.80 over 180 days** — implies
  ~100.0 kWh/day, *below every archived year including 2022*. Consistent
  with (not proof of) the July 2025 capacitor replacement pulling the
  second half of the season down enough to drag the whole-season average
  under the pre-drift baseline — the right direction and roughly the
  right size for the capacitor-aging theory, though weather/schedule
  differences could also contribute.

### Historical Sense data (2022–2024), pulled via API 2026-08-23

Sense's Home app UI only shows one hover value at a time; pulled the raw
hourly `[min,max]` W series directly from `api.sense.com` for every day the
CTs were on the pump — 418 days (Sep–Oct 2022, May–Oct 2023, May–Oct 2024,
per Casey; whole-house from Jan 2025) — saved locally as
`~/Downloads/sense-pump-usage-2022-2024.json` (**not committed** — it's raw
household energy data, kept out of the public repo).

Findings:
- **The ~9 AM daily line switch is independently confirmed**: across 332
  clean days, the single largest hour-to-hour jump falls in the 8–11 AM
  window 47% of the time (156/332) — matches Casey's rotation timing with
  no prompting.
- **Steady-state power is one continuous spread, not four separable
  clusters**: even isolating pure overnight readings (midnight–4 am, one
  line only, before any pump/lawn zone), the histogram spans 4212–5450 W
  with no gaps. Too much other variance (season, pond level, year-over-year
  drift) sits on top of the four lines to reverse-engineer "this watt value
  = this line" from history — **today's/tomorrow's live per-line readings
  are the trustworthy source for that mapping, not this archive.**
- **Real finding — year-over-year upward drift**, but the first pass at
  this (whole-season 2022 vs 2023 vs 2024 averages) was invalid: 2022 only
  has Sep–Oct data (32 days) while 2023/2024 are May–Oct, so it was
  comparing different seasons, not different years. Caught by Casey
  2026-08-24 (compared against the real Sense chart) — redone matched by
  calendar month:
  - **Sep, same month 3 years running: 4346 → 4452 → 4640 W (+294 W /
    +6.8% over 2 years)** — the drift survives, and is sharper than the
    original mixed-season estimate.
  - Oct: 4499 → 4407 → 4617 (2023 n=3, too thin to trust)
  - May–Aug, 2023 vs 2024 only: 4592 → 4673 W (+81 W / +1.8%)
  - Within a season the pattern runs the OPPOSITE of the pond-level theory
    that motivated checking this: power is higher in spring, lower by
    fall, in both 2023 and 2024. Moot anyway — Casey keeps the pond at
    ~100% at all times, so suction head doesn't vary; pond level is ruled
    out as a driver of either the seasonal or the year-over-year pattern.
  - **Leading hypothesis: aging motor run capacitors**, not impeller wear.
    The WEG motor is single-phase capacitor-run (nameplate: `CAP.: 2x216-
    259uF 250V + 1x30uF 400V`) — capacitance drifting down over a couple
    of years is a well-known, common cause of exactly this signature
    (creeping current draw for the same mechanical load). Cheap to check:
    a multimeter capacitance test (or an amp-draw check vs. the Sep 2024
    baseline) takes minutes; the caps are a ~$30 part if they've drifted
    out of the 208-230V-rated tolerance band.
  Worth tracking in 2025+: a continuing climb is the signal to act on
  before something fails outright.
  - **Update 2026-08-24: the run capacitor was already replaced**, week of
    2025-07-06 (Casey). **Caveat (Casey, 2026-08-24): the installed
    cap may be the "ok" in-spec loaner from the electrical shop, not a
    fresh new one — a new cap was ordered and may still be boxed/uninstalled
    (Casey unsure). So there may be a pending swap to the proper new cap.** All 418 days of archived pump-only power data
    (2022-2024) predate this, so the entire drift trend documented above
    reflects the OLD capacitor's degradation — a capacitor typically only
    gets swapped when it tests bad or the pump shows symptoms (hard
    starting, humming, high draw), which corroborates the hypothesis
    rather than just being consistent with it — **confirmed, not just
    inferred: the old cap tested a bit low on capacitance (Casey)**. No
    pump-only CT data exists
    from after the swap (Sense moved to whole-house Jan 2025) to directly
    confirm power dropped back down; if a CT ever goes back on the pump
    circuit (or Sense Flex in Dedicated Circuit mode - see the monitoring
    item above), compare against the pre-2025-07-06 baseline above.
  - **Correction (2026-08-24): Sep 11 is NOT anomalous — retracting the
    earlier "anomaly" framing.** Casey asked directly how it differs from
    other days; running the same "second sustained plateau" detector
    across the full 418-day archive found **227 similar events** — a
    second multi-hour power step on top of the normal ~9am rotation,
    roughly every 1–2 days, all three years. Sep 6 (5 days before Sep 11,
    same week) shows the identical shape. This is the system's normal
    behavior — most likely evening lawn-zone watering blocks running
    several hours — not a special event. Sep 11 was only the day I
    happened to look at first.
- One anomaly day (2024-09-11) shows two mid-day power steps instead of the
  usual single AM/PM split — a one-off event, not a mapping error.

### Pump zones (mornings)

| Pump zone | psi | Delta vs 51.7 baseline | Ran | Date |
|---|---:|---:|---|---|
| pump zone 1 | 47.3 | −4.4 | 05:50–06:05 (~15 min) | 2026-08-24, recorder; order confirmed by Casey |
| pump zone 2 | 47.9 | −3.8 | 06:05–06:20 (~15 min) | 2026-08-24 |

Brief transition dip to ~43 psi at the zone 1 → zone 2 switch (valve
switching transient, ~10 s, not sustained). Baseline was back at 51.7 from
06:20 until the lawn cycle at 07:27. (An earlier screenshot-based reading
had pump zone 2 running 79 min — a misread; the recorder shows ~15 min.)

**Lawn zone cross-check, same morning (recorder)** — the full cycle on top
of line 1 (51.7): zone 1 07:28–07:52 = **47.6** (47.4 the evening before),
zone 2 07:52–08:18 = **48.6** (48.5), zone 3 08:18–08:38 = **49.9** (49.8),
zone 4 08:38–08:52 = **51.0** (51.1), then line 1 alone again at 51.6.
All four repeat to within 0.2 psi across 12+ hours — solid grounds to trust
the deltas for the feedforward table. (Lesson: a lawn-zone level can
coincide with a predicted line level — always check the time against the
lawn schedule before labeling a plateau as a line change.)

Numbers now come straight from HA's recorder via `tools/ha_pressure.py`
(read-only query over ssh to machone, sustained-plateau detection); no more
screenshot reading needed for future line runs.

## 2. ICE wiring & policy decisions (open)

- [ ] Wire the ICE relay into the pump loop. **NO contact, energized = loop
      closed** (decided 2026-08-18, fail-stop). Reboot/OTA blip eliminated
      by the local pca9554 override — **bench-verified 2026-08-23**: relay
      LED stayed lit through a Restart.
- [x] Soak test: ICE left ARMED (relay not yet in the loop) for the
      monitoring period — any spurious trip shows up in ICE Tripped/Status
      with no consequences.
- [x] Furnas Class 69 pressure control (auto-off lever): low-pressure
      cutoff **20 psi**. Loop is **Pump → Furnas →
      ICE relay** in series (120 VAC, one leg of the starter loop). ICE Low
      Trip disabled (0) — the ICE guards the high side only. The Furnas has NO high setting — the ICE is the pump's only
      high-pressure protection. High Trip 65 psi (2026-08-23, from the pump curve + flooded suction).
- [x] ICE relay = debounced comparator with hysteresis, HIGH side only
      (Low Trip 0 = disabled; low pressure is the Furnas's job): opens after
      3 s ≥ 65 psi, re-closes after 2 s back in band.
- [x] Pump curve (Goulds 3656 1½×2–6 — 1½" outlet confirmed — A 5-15/16"
      impeller, 3500 RPM) with
      ~11 ft flooded suction (+5 psi at the gauge): shutoff ~70 psi, BEP
      ~57 psi @ 100 GPM, 5 HP limit ~46 psi @ 150 GPM. High Trip **65 psi**
      (80 was above shutoff and could never fire; 60 crowded the BEP). Starter is HAND–OFF–AUTO: start in HAND,
      flip to AUTO at pressure. Alerts latch until ICE Reset.
- [x] **Capacitor RESOLVED 2026-08-24 with meter measurements.** Bad
      original cap measured **18.3 µF** (vs 30 µF rating = 39% low →
      definitively failed; hard confirmation of the 2022-24 power-drift
      story). New **Titan Pro TRCF30, 30 µF 440/370 VAC** now installed.
      The in-service loaner (measured 30.7 µF, in-spec) kept as backup;
      the bad 18.3 µF cap kept for reference only.
- [~] ICE High Trip is now an ALERT threshold only (relay not wired — see
      the decision at the top of section 1), so its exact value is no longer
      safety-critical. Left at 65 psi as a "pressure is unusually high"
      notification. (If it's ever wired in future, first measure true
      dead-head: close the main valve slowly, watch peak pressure, set the
      trip a few psi below — because with the corrected +0.4 psi geometry,
      published dead-head at the gauge ≈ 65, so 65 has no margin.)
- [x] Real trip verified 2026-08-23 (High Trip 45 → tripped at 51 psi,
      relay released) with the module not yet in the pump loop.

## 3. Recycle failsafe (when zones are automated)

- [ ] If the HA/API connection is lost for N minutes, open Valve 1 to
      ~10–15% so the 5 HP pump always has a flow path. Firmware-side,
      disabled by default. Not needed while the long irrigation lines run
      24/7 (they *are* the fail-safe today).
- [ ] "Safe Mode" switch: same response, on demand.

## 4. Sprinkler node

- [ ] Second PLC-100 (have both an ESP32 V1 and a Nano V2 + Nano ESP32),
      standard 24 VAC solenoids, 2–3 zones now, +4 later (6 relays; I2C
      PCF8574 + relay module if it ever hits 7). **Use the native ESPHome
      `sprinkler:` component** (see `docs/sprinkler-component-notes.md`) —
      each zone = a GPIO relay switch; `run_duration_number` for HA-tunable
      times; `valve_overlap` gives open-before-close (no dead-head at zone
      transitions) natively. Recycle stays in the pump-monitor node
      (pressure-driven), NOT the sprinkler component's pump_switch.
- [ ] Open-next-before-close-previous sequencing so a flow path always
      exists; a few seconds of delay between zones. No solenoid timing
      exists (OpenSprinkler only has station delay / master on-off adjust).
- [ ] MEGA2560 PLC-300 rejected: no ESPHome on AVR.

## 5. Calibration & sensors

- [ ] Pump power monitoring: a CT on the pump feed so HA sees motor load
      directly — Shelly EM / Emporia on that circuit, or a 0–10 V CT
      transducer into the PLC's spare AI2. Gives the staged controller a
      real motor-load floor instead of inferring it from pressure.
- [ ] DS18B20 temperature (like revel-monitor) — `one_wire` on a spare GPIO
- [ ] Measure Valve 2's Full Travel Time after install
- [ ] Re-verify the 50–95% flow anchors with clean-blank bucket runs
- [ ] Confirm the valve flow table on the real pump (60 psi static, so the
      faucet numbers should transfer)
- [ ] Pressure: transducer trusted over the dial (~8 psi apart at the same
      tap; moving the transducer to the main leg won't change a dead-end
      reading). Next pump-off: check both read 0.

## 6. Thermal relief valve — passive dead-head backstop (2026-08-25)

> **Why not a pressure relief valve.** This pump can't make dangerous
> pressure: shutoff is ~65 psi against 150 psi pipe (2.3x margin).
> Overpressure isn't the failure mode — **zero flow is**, and its symptom is
> heat, not pressure. Worse, pressure is a weak discriminator here: normal
> small-zone operation runs 61–62 psi and dead-head is ~65, so a mechanical
> relief valve would have to sit in a **~3 psi window**. Commercial spring
> relief valves are ±3–5% on set point (±2–3 psi at these pressures), so it
> would either weep continuously during normal runs or never crack at all.
> (A rupture disc is worse — stays open once burst.) A **thermal** relief
> valve triggers on the actual damage mechanism instead of a proxy that
> barely moves.

Layers, each catching what the others structurally cannot:

1. **pump-monitor recycle** — normal operation, holds flow near BEP
2. **ICE-high** — cuts the pump on a pressure excursion it *can* see
3. **Thermal relief valve** — fully passive; fires on heat when everything
   electronic has failed. No power, no logic, no network.

### Sizing (checked 2026-08-25 — the small valve is enough)

- Heat load at dead-head: BEP ~100 GPM @ ~52 psi → TDH ~119 ft → ~3.0 WHP;
  at 73% eff ~4.1 BHP. A centrifugal at shutoff draws roughly half to
  two-thirds of BEP power → **~2.5 HP ≈ 6,400 BTU/hr** into trapped water.
- Flow to carry it, `GPM = BTU/hr ÷ (500 × ΔT)`: **0.6 GPM** at 20 °F rise,
  **1.3 GPM** at 10 °F.
- Flow available: the valve's 1/8" outlet is the restriction — orifice flow
  at 60 psi is **~2 GPM**, i.e. 2–3x what's needed. The "10% of BEP"
  rule-of-thumb (10 GPM) is conservative by ~an order of magnitude at 5 HP.
- Time to trip: ~1.5 gal of casing water needs ~875 BTU to rise 70 °F →
  **~8 min** of true dead-head. Mechanical seals suffer north of
  160–200 °F, so a 140 °F set point leaves real margin.
- Data point: neighbour Rick dead-heads a 7.5 HP pump ~8 hr/day on a
  **continuous** bypass with no ill effect — consistent with the thermal
  minimum being small. (A continuous bypass was considered and rejected
  here: it wastes pumping energy every hour of every day to guard an event
  that should never happen.)

### Parts

- [ ] Thermal relief valve, 140 °F, 1/4" MPT in x 1/8" NPSF out, brass,
      Viton/Buna, SS spring. J.E. Adams listed it but shows *Product
      Unavailable*; same device sells as a pressure-washer thermal relief —
      Cat Pumps 7803, General Pump 100573, etc.
- [ ] Fitting chain to get from the valve to 1/4" copper (ordered):
      valve `1/8-27 NPSF` (female, **straight** thread — sealed by a tapered
      male, so 1/8" NPT male is the correct mate, with PTFE tape)
      ← `1/8" NPT male — 1/4" NPT male` hex adapter
      ← `1/4" NPT female — 1/4" SAE flare male` adapter
      ← flare nut + **1/4" OD copper** (~0.19" ID, so the tubing does NOT
      restrict — the 0.125" valve orifice stays the limiting element).
- [ ] Mount on the **discharge port at the pump** so it sees casing water.
      Out on the mainline it would sit in stagnant water and never heat.
- [ ] Route the copper under the pump house. NOTE: it discharges **hot
      water, not steam** — 140 °F at 60 psi stays liquid (needs 212 °F to
      flash) — but it's a jet at line pressure, so aim it deliberately.
- [ ] Annual: pull, clean and warm-store the valve at winterization along
      with draining the housing. Pond water is Deschutes-fed and clean, so
      fouling risk is low, but a backstop you never verify is an *assumed*
      backstop.

### Make the event observable (temp probe → pump-monitor)

The valve fires only when everything else has already failed, and it can
open, do its job, and reseat with no trace. Evidence matters as much as
protection.

- [ ] **DS18B20 clamped to the copper discharge line** (thermal paste +
      insulation wrap; surface-mount tracks the water within a few degrees,
      which is plenty for detecting a ~70 °F excursion). `one_wire:` bus +
      `dallas_temp` sensor, one GPIO + 4.7 kΩ pull-up. See also the DS18B20
      item in section 5.
- [ ] **Put it on pump-monitor, not pump-controller** — that node owns the
      protection model (ICE latch, trip reason, pressure), so a thermal trip
      belongs in the same alert scheme, and it can correlate: pressure
      pinned near shutoff *and* the relief line hot is an unambiguous
      dead-head signature.
- [ ] **Latch it**, same pattern as ICE Tripped: a `restore_value: true`
      global that trips above **~100 °F** (well above solar warming, well
      below the valve's 140 °F) and *stays* tripped, plus a stored
      timestamp, until an explicit reset. The DS3231 (validated 2026-08-25
      through a real power cut) makes that timestamp trustworthy even if the
      event happens during a network outage.
- [ ] Freebie: the same probe reads pump-house ambient the other 99.99% of
      the time → **freeze detection** in shoulder season, on a system that
      gets winterized annually.
