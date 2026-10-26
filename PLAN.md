# Pump Monitor v2 — plan, status and history

The design document for pump-monitor. Written 2026-10-04 from
`PUMP-MONITOR.md` (the brain dump), the three node YAMLs, the
TODO/PID-PLAN/fields docs, and a read-only inventory of Home Assistant on
machone. Sections 1–16 are the plan as written, with the 10-08/10-09
results added. Section 0 says what is actually built; section 17 is the
PID loop that v2 replaced (formerly `PID-PLAN.md`).

Labels used below: **[measured]** = on record in TODO/PID history/memory,
**[reasoned]** = arithmetic from measured numbers, not yet observed,
**[decide]** = Casey's call.

## 0. Status (2026-10-25)

**Flashed 2026-10-09 10:25 [measured]:** `pump-monitor.yaml` (then
`pump-monitor-v2.yaml`) = the v1 firmware plus the guard only. Guard
checks G1–G5 passed on water the same morning (section 16). Season over:
pond drained, lines blown out.

Built, on the node:

- **`Guard`** switch (default ON, restored). ON holds both CVs at or above
  pulse 4 (25 %, 2.3 GPM each) at one choke point, the pulse scripts. A
  close from HA or Pulse − stops at the floor. OFF removes the floor and
  moves nothing. The switch is set by hand: the automatic release from
  manual-line toggles (section 4) is **not built**.
- **Reflex**: pressure ≥ `Guard Reflex Pressure` (default 57 psi, 110 =
  never) for 3 s, or the transducer dead for 5 s → floor forced with Guard
  ON or OFF. Clears after 60 s of a good reading 2 psi under the threshold;
  clearing moves nothing. `Guard Reflex` problem sensor shows it.
- **`Recycle Flow`** (GPM to the pond from the valve positions, 0.0923 per
  % per valve; 0 when the pump is stopped).
- Removed from v1: the PID loop (17 entities) and `STOP All`.
- Unchanged from v1: valve pulse positioning, ICE (relay **not wired**,
  `ICE Bypass` default ON; `ICE High Trip` still exists at 58 psi although
  section 9 retires it as a trip), Pump Running, diagnostics.

Built, in HA (scripts in `ha/`, both run 2026-10-09): `Pump Unload`
(section 15) and `Field A Test Cycle` (sections 14, 16). Plus
`ha/field-a-dashboard-card.yaml`.

Not built: sections 5–8 and 10–13 (Pump State, flow/totals, line table,
faults, RTC, pump-controller schedule and hand-over, HA package), and the
firmware version of Pump Unload.

**Season start (valve position is dead-reckoned).** The counters survive
a winter of no moves, but nothing confirms the balls are where the counter
says. Re-home both valves before the first water: pump off, `Guard` OFF,
close Valve 1 and Valve 2 (each drives onto the seat with the homing
margin and resets its counter to 0), then `Guard` ON — both drive back up
to pulse 4 (25 %). Then check the two jets into the pond by eye.

## 1. What is wrong with the system today

| # | Problem | Where it shows |
|---|---|---|
| 1 | Logic is spread over three places and only one is in git | Firmware (valves, ICE, PID); 9 HA template helpers + 30 input helpers in `.storage`; 8 HA automations |
| 2 | The dead-head protection for Field A is an HA automation | `Auto Open CV1` needs HA + Wi-Fi + both nodes alive, and it keys on the dashboard booleans (`input_boolean.field_a_line_N`), not on the solenoid relays. 10-04: A1 ran from 08:00 and CV1 opened at 10:46, when the boolean was remembered **[measured, automation trace]** |
| 3 | The PID and the safety opening fight | PID drives CV2 to 0 whenever pressure is under setpoint, so CV2 cannot be both "always 25 %" and "on the loop" |
| 4 | ICE means three different things in the docs | Trip value appears as 58, 60, 65 and 95; "not wired, maybe ever" vs "will be wired"; YAML comment recommends NC while TODO §2 decided NO |
| 5 | The same constants live in several places | Two pump-curve fits, 4.7 vs 4.9 GPM/head, the 0.0923 recycle fit, head counts — in HA templates, TODO, fields.md |
| 6 | The node shows 58 entities with no hierarchy | Raw relays, stopwatches and PID internals sit next to the three numbers that matter |
| 7 | "What is running" has no single owner | Manual lines = HA booleans, Field A = pump-controller relays, lawn = two sprinkler controllers |

## 2. Design rules

1. **Safety never crosses the network.** Anything that protects the pump
   runs on pump-monitor from its own pressure sensor and its own valves.
   HA, Wi-Fi and the other nodes may all be down.
2. **Safety needs no state from another node.** The guard is ON unless
   pump-monitor's own manual-line toggles say otherwise, and the pressure
   reflex backs it up when they are wrong. What Field A and the lawn zones
   are doing is for bookkeeping and alarms only.
3. **One choke point per actuator.** Every CV move (slider, buttons,
   guard) goes through one function that applies the floor.
4. **One home per fact.** Each constant is defined once, in a file in git.
5. **Alerts first, actions later.** Every new fault starts alert-only and
   earns the right to act after it has been watched for a while.

## 3. Who owns what

| Layer | Owns | Must work without HA |
|---|---|---|
| **pump-monitor** | Pressure, CV1/CV2, minimum-flow guard, ICE, flow math, water totals, line table, `Closed Heads`, hydraulic faults, pump state | Yes — all safety; bookkeeping degrades to "unattributed" |
| **pump-controller** | Field A relays, pump lawn zones, hard 4 h cap per Field A line, Field A schedule from the RTC | Yes |
| **home-controller** | House lawn zones | Yes (as today) |
| **Home Assistant** | Dashboard, notifications, history, kWh ledger (Schedule F), the weekly manual-line rotation text, relaying state between nodes | — |

Considered and rejected: chaining pump-controller's board behind
pump-monitor as a dumb I2C expander so one MCU owns relays and CVs. Rule 2
makes it unnecessary, and it would put every relay behind one flash.

## 4. The minimum-flow guard (the core change)

**Decided (Casey, 10-04):** the guard is for solenoid lines and small
sets. Manual lines run near the GPM limit and cannot close by themselves,
so with a manual line running the CVs are **closed**.

| Layer | Rule | Covers |
|---|---|---|
| **Guard** | ON unless the declared manual lines carry ≥ 60 GPM (12 brass heads, after `Closed Heads`) **and** pressure has been < 56 psi for 30 s. ON = CV1 ≥ 25 % and CV2 ≥ 25 % (pulse 4 each), enforced in the choke point | A solenoid closing for any reason; B1 alone (7 heads); nothing running |
| **Reflex** | Pump running and pressure ≥ 58 psi for 3 s, or the transducer reads fault (NaN, < 0.7 V, ≥ 105 psi) → drive both CVs to 25 % even if Guard is OFF | A manual line declared but not actually open; a manual line shut by hand |

The guard rule uses only state held on pump-monitor (the manual-line
toggles and `Closed Heads`, both restored from flash), so it does not
depend on HA, Wi-Fi or pump-controller. Default with nothing declared is
Guard ON.

Numbers behind it:

- 25 % + 25 % = 4.6 GPM to the pond **[measured, bucket 10-01]**.
- Thermal minimum for this pump ≈ 1.3 GPM (TODO §1), so the pair is ~3.5×
  that and **one valve alone (2.3 GPM) is still above it** **[reasoned]**
  — the reason for two valves at 25 % rather than one at 50 %.
- Idle on the guard, ~2.2 kW into 4.6 GPM ≈ +3 °F per pass back to a
  60,000 gal pond **[reasoned]**. Accepted by Casey 10-08 without a long hold: an IR gun shows nothing with the bypass open, and the pump man agrees 5 GPM keeps it cool.
- 12 heads (60 GPM) is the smallest set that leaves real margin to shutoff
  (55.8 psi, TODO §1) **[measured]**. Every legitimate set runs ≤ 56 psi;
  no field flow reads ≥ 60 **[measured]**. 58 separates them.

`Auto Open CV1` and `Auto Close CV1` are replaced by this rule.

**No PID [decided 10-08].** Both valves at 25 % is the whole control.
The loop existed to trim small sets down to 55 psi; the solenoid lines run
~54.5 on their own and the valves are meant to stay parked. Removed from
v2: the pid climate, its output, setpoint, enable switch, gain numbers,
autotune and the eight loop sensors (17 entities). The tuned gains (0.492
/ 0.0683 / 0.886) and the tuning log are in section 17; the v1
firmware is `pump-monitor.yaml` on branch `pid` if it is ever wanted back.

**The valves park at 25 % and stay there [decided 10-08].** Once every
line is on solenoids (7 heads each, A4 with 8), the guard is never
released, so nothing ever asks the CVs to move. No daily resync and no
daily full-open "proof" move: a valve that never moves cannot lose its
count, and every extra move is wear on a motorised valve for no gain.
What this gives up: nothing on the node confirms the recycle path still
passes water. The check is the two jets into the pond, by eye. Until the
hand lines are gone the valves still move at each hand-over (closed for a
C line, back to 25 % after), and closing on the seat resyncs the count.

## 5. Pump state and the dead-head timer

One text sensor, `Pump State`, replaces reading five entities:

| State | Condition |
|---|---|
| STOPPED | pressure < 10 psi |
| IRRIGATING | running, pressure < 58 |
| SWAP | running, pressure < 40 (line fill; up to ~2 min on C lines) |
| IDLE ON GUARD | running, pressure ≥ 58, **nothing commanded** — the intended dead head between sets |
| LINE DID NOT OPEN | running, pressure ≥ 58 for 60 s with a line commanded — a fault (section 8) |
| UNLOADING | a pump stop has been requested; all Field A lines and both CVs are being opened first (section 15). Overrides the hand-over and overload rules |
| FAULT | any other latched fault |

The pump is equally safe in both ≥ 58 states (the guard is carrying it);
what differs is whether it was on purpose. That is why the node needs the
line state.

Pressure cannot tell "recycle flowing" (61.2 psi) from a true dead head
(61.3) **[measured/reasoned, TODO §1]**. So the timer is named for what it
measures: `No Field Flow Time` (current stretch) and `No Field Flow
Today`, stamped from the RTC.

## 6. Flow, water and cost

Computed on pump-monitor, defined once in `pump_math.h`:

| Value | Formula | Status |
|---|---|---|
| Pump GPM | √((61.3 − psi) / 0.001165), capped 150 | **[measured fit 08-25]** |
| Pond GPM | 0.0923 × (CV1 % + CV2 %) | **[measured to 50 % total only]** |
| Field GPM | Pump − Pond | derived |
| Expected psi | 61.3 − 0.001165 × (Σ line GPM − 5 × closed heads + Pond GPM)² | same curve, run backwards |
| Residual | measured − expected | derived |

With the line table in GPM (section 7) there is one curve for
everything. The second fit (60.2 − 0.02794·heads², and its 4.7 GPM/head
twin in the HA template) is retired. Today's Falcon runs land on the
catalog GPM through this curve, which is the evidence for keeping it.

Totals (gallons, `total_increasing`, restored, RTC-reset): field today /
season, pond today / season, plus one counter per line (section 7). HA's
long-term statistics give week/month views for free; no HA math needed.

Power and cost: the Shelly stays the meter and HA's `utility_meter` stays
the kWh ledger for Schedule F (already designed in TODO §5; needs the
50/80 correction). pump-monitor imports instantaneous kW only, for $/hour,
wire-to-water efficiency, and the power faults. New number: `Energy Rate`
(¢/kWh). kW is never used for a safety action.

## 7. Line table — what is running and how much it got

One table in firmware (`lines.h`): A1–A4, B1–B3, C1–C4, pump lawn 1–2,
house lawn 1–4. Heads are fixed once a field is laid out, so the table is
constants in git **[decided 10-04]**. **The unit is GPM, not effective
heads [decided 10-04]** — the same number then gives expected pressure,
field flow and gallons, through the one pump curve.

Per-head GPM (the seed for a line, and what `Closed Heads` subtracts):

| Head | GPM | Check against the pump curve |
|---|---:|---|
| Brass 5/32" impact | 5.0 | C4, 21 heads, 49.78 psi → 99 GPM → 4.7 each **[measured 10-04]** |
| Falcon #12 tan | 11.0 | A1 54.74 psi → 75.0 GPM → 10.7 each; A2 → 11.0 each **[measured 10-04]** |
| Falcon #10 grey | 9.1 | A4 → 75.5 GPM → 9.4 each **[measured 10-04]** |

Per-line GPM is what the firmware uses. Falcon lines sit on count × head
GPM. Hand lines do not: the same brass head passes 5.2 GPM on an 18-head
line and 4.7 on the 21-head line (nozzle pressure and latch-gasket
leakage), which is up to 2 psi of error if a flat 5 is used. So each hand
line gets its own GPM, read off the curve from its measured plateau:

| Line | Heads | Line GPM | From |
|---|---|---:|---|
| A1 | 7 tan | 75 | 54.74 psi, CVs closed **[measured 10-04, 08:15–10:40]** |
| A2 | 7 tan | 77 | 54.00 psi with CV1 at 25 % **[measured 10-04]** |
| A3 | 7 tan | 75 | same as A1: 53.35 vs 53.32 psi back to back, both CVs at 25 % **[measured 10-01]** |
| A4 | 8 grey | 75.5 | 54.24 psi with CV1 at 25 % **[measured 10-04]** |
| C1 / C2 / C3 | 18 / 18 / 19 brass | 94 / 94 / 93 | 51.06 / 51.03 / 51.27 psi **[measured 08-28..31]** |
| C4 | 21 brass | 99 | 49.78 psi **[measured 10-04]** (49.73 on 08-30) |
| B1, B2, B3 | 7 / 8 / 7 brass | 35 / 40 / 35 | seed; B2+B3 together measured 83 (53.27 psi) |

Today's A-line windows are taken from Casey's times and the dashboard
toggles; CV1 was at 25 % from 10:46 to 19:14 and its 2.3 GPM is taken off
the pump flow. A1 read 2.6 GPM more with CV1 open than closed, which
agrees with the bucket fit. fields.md still lists Field A as 6/6/6/7 and
needs correcting to 7/7/7/8.

**`Closed Heads`** (number, 0–10, − / + on the dashboard like Skip Days):
5 GPM per closed head off the running manual lines. B1+B2+B3 with two
shut = 21 − 2 = 19 heads. Resets to 0 when the manual line set changes
**[decided 10-04]**.

| Source of "running" | Lines |
|---|---|
| Solenoid relay state, imported from the owning node via HA | Field A, all lawn zones |
| Toggle on pump-monitor, set by the hand-over rule (section 13) or from the dashboard | B and C manual lines (replaces the HA booleans) |

Published: `Running Lines` (text, e.g. `C2 + House Lawn 1`), `Expected
GPM`, and gallons per line. Field GPM is split between running lines by
their line GPM. Flow with nothing declared goes to `Unattributed`.

"How much does each line need" (inches from gallons ÷ area, weekly target)
is a later step on top of these counters, and lawn zones need per-zone
area. Not designed here.

## 8. "Something is wrong"

Measured pressure against expected pressure, read 60 s after a change has
settled. Broken heads, risers and elbows always mean **more** water, so
the low side is the one that matters.

| Measured vs expected | Meaning | Response |
|---|---|---|
| within ±1 psi | normal | — |
| +1 to +3 psi | a head is plugged (one of 7 tan ≈ +1.7 psi **[reasoned]**) | log only, no alert; they often clear |
| ≥ 58 with a solenoid line commanded | the line did not open | pump is on the guard, so no hurry. Alert at 60 s. Once the action is enabled: at 5 min close this line, flag it, open the next in the order. A full pass with no line opening stops the schedule on the guard (points at something shared, e.g. the 24 VAC supply) |
| 3 psi or more low, steady | more water than the line should take: broken head or riser, or the previous line did not close | Solenoid line: alert. Later: close this line and move to the next; if pressure is still low with it closed, the previous line's valve is stuck open → alert, stop the schedule on the guard. Manual line: alert only |
| < 40 while a Field A line runs | a manual line was opened | handover (section 13) |
| ≥ 58, nothing commanded | intended idle on the guard | none; timer runs |

Reference sizes: one brass riser off = −9 psi in one sample **[measured
08-27]**; a cracked Falcon elbow = flow cycling 76 ↔ 90 GPM **[measured
09-27]**. The ±1 / +3 / −3 bands are starting values to tune against a
week of data.

Other faults, each a `problem` binary sensor plus one `Fault` text line:

| Fault | Signal | Basis |
|---|---|---|
| Leak cycling | field GPM max − min > 8 over 5 min on one line | **[measured 09-27, A-3 elbow]** |
| Unattributed flow | field GPM > 10, nothing declared | new |
| Motor overload zone | pressure < 46 while irrigating, or kW > 5.3 | pump curve, Sense history. C4 + house lawn ran 47.8 psi median, 46.6 at the low end, 4.98 kW **[measured 10-04]** — the normal worst case sits just above this line |
| Power / pressure mismatch | kW far from the value the pressure implies | TODO §5 "derive" list |
| Field A over-run | a Field A line on > 4 h | **[measured 09-28 flood]** |
| Sensor | transducer fault | new |
| Pond low | level-sensor problem | existing node |

Everything starts alert-only. "Later" and "once enabled" mean a later
rollout step, not a time delay. Those actions only ever close a
solenoid while the guard is on, and are enabled one at a time.

## 9. ICE (pump kill)

**Decided (Casey, 10-04): no high-pressure trip.** With the CVs carrying
the pump, 60–61 psi is a guarded, intended state, and shutting the pump
off there is not wanted. High pressure triggers the reflex (section 4) and
the LINE DID NOT OPEN alert (section 8), never the relay.

- `ICE High Trip` is removed as a trip. The 58 psi number lives on as the
  reflex threshold.
- **No thermal layer (Casey, 10-08, after talking to the pump man):** the
  pump has no port for a thermal relief valve, and 5 GPM to the pond is
  enough to keep it cool. So no relief valve, no copper line, no DS18B20;
  TODO §6 is dropped, and with it the temperature trip that the August
  design called the only kill trigger.
- What that leaves: the two CVs are the whole dead-head protection, and
  nothing can see them both fail (pressure reads 61.2 with them flowing
  and 61.3 without). There is no automatic check either (section 4: the
  valves stay parked); the two jets into the pond are the check.
- The only trip candidate left for when the relay is wired, off by
  default: `No Field Flow Time` over a limit.
- **Every commanded stop unloads the pump first (section 15).** The
  relay is never dropped at 60 psi if it can be helped.
- Wiring stays as decided in TODO §2: NO contact, energized = run, relay
  held through reboot by the pca9554 override **[measured, bench 08-23]**.
  The YAML comment recommending NC gets corrected in v2.

## 10. RTC use

Same pattern on all three nodes as pump-controller already runs (`ds1307`
platform, SNTP writes the chip, chip time latched at boot as the battery
check):

1. Timestamps that survive a network outage: last trip, last fault, start
   of each no-field-flow stretch.
2. Daily and season counter resets on the node.
3. On pump-controller: the hard 4 h cap and a standalone Field A schedule
   (3 h twice a day per line, order in section 13), so Field A waters itself with HA down.

## 11. Cleanup

**Firmware.** Split the 1,335-line file with ESPHome `packages:` into
`valves`, `guard`, `pid`, `ice`, `flow`, `lines`, `faults`, `base`. Raw
relay switches and stopwatches become diagnostic and
disabled by default. Target for the main device card: Pump State, Pressure
vs Expected, Field GPM, Pond GPM, Running Lines, Guard, Fault.

**Home Assistant.** Everything that remains moves from UI helpers into one
`ha/packages/irrigation.yaml` in this repo.

| Today in HA | v2 |
|---|---|
| `Auto Open CV1`, `Auto Close CV1` | deleted (guard) |
| Pump Flow GPM / PSI, Est Pressure, Est Pressure Delta, Valve N Percent Open, Pump Water Total | deleted (node publishes them) |
| 11 line booleans, 17 heads numbers | deleted (line table + `Closed Heads` on the node) |
| Irrigation Lines / Lines Next, `input_text.irrigation_schedule`, swap-detected automation | kept, retargeted to the node's line toggles, moved to the package |
| Lawn schedule + skip automations (4) | kept, moved to the package |
| Pump Power / Pump Energy templates | kept, plus `utility_meter` and the rate |

Stray items found: two template entries both titled `Pump Flow GPM`; the
house lawn zone 2 heads helper is stored under id
`home_lawn_zone_1_heads_2`.

**Docs.** One `docs/OPERATIONS.md` page: the states, the guard rules, what
each fault means and what to do. TODO.md stays as the history.

## 12. Order of work

Each step is flashed with no zone running and has a check before the next.

| Step | Content | Done when |
|---|---|---|
| 0 | Settle the remaining **[decide]** items; snapshot the current HA helpers and automations into the repo as-is | Decisions written here; snapshot committed |
| 0a | `Pump Unload` HA script (section 15), as soon as the solenoids are wired — no flash | Attended: 2, 3, then 4 lines opened for ~10 s each give the real pressures; then one real stop with the button shows the suction line stays on |
| 1 | Guard, reflex, manual-line toggles and `Closed Heads`, RTC | Declaring a C line closes the CVs and un-declaring reopens them; slow close of the 4" main with Guard OFF shows the reflex opening both CVs; one A4 run gives the grey-nozzle value |
| 2 | Pump State, no-field-flow timer, flow and totals | A known line reads its known GPM; totals survive a restart |
| 3 | Line table, expected pressure, per-line gallons | A week of rotation with residual inside ±1 psi and nothing unattributed |
| 4 | Faults and notifications | Each fault provoked once on purpose or replayed from recorder data |
| 5 | pump-controller: 4 h cap, Field A day from the RTC, hand-over, OTA ride-through bench test (TODO §4) | Relay rides through a real upload; a line switches itself off at the cap; a Saturday hand-over closes Field A and then the CVs |
| 6 | HA package, dashboard, delete the old helpers | Old entities gone, dashboard runs on node entities only |
| 7 | Wire ICE and enable the chosen trips | Trip proven in Test Mode first |

**Step 1 should be proven before the first unattended Field A solenoid
run.** Until then the current `Auto Open CV1` automation is the only
protection and it depends on HA.

Later, not planned here: weir control from pond level, fields B–E, the
per-line water budget.

## 13. Field A day and the hand-over to manual lines

**Field A day (pump-controller, from its RTC).** Friday 08:00 → Saturday
08:00, each line 3 h, twice. Order **[decided 10-04]**: 3-1-3-2-4-1-4-2.

| 08 | 11 | 14 | 17 | 20 | 23 | 02 | 05 |
|---|---|---|---|---|---|---|---|
| A3 | A1 | A3 | A2 | A4 | A1 | A4 | A2 |

- A1 and A2 (the lines that get wettest) have 12 h between their runs.
- A3 and A4 repeat after a 3 h gap; they do not get as wet.
- A4 runs at 20:00 and 02:00, in the dark for the chickens.
- One back-to-back neighbour pair, A3 → A2 at 17:00. No order of four
  lines avoids all of them while keeping the points above.

The day is an ordered list of (line, 3 h), not clock slots: a skipped
line (section 8) advances the list, so no line runs past its 3 h. A skip
pulls everything after it earlier, A4 included (toward daylight).

Each change: open the next line, then close the previous one straight
away. No wait between them: the solenoid valves close slowly, which is
the overlap (Casey, 10-08; the pressure trace of the test cycle is the
check). Guard
is ON the whole day, so a change that goes wrong lands on the guard.

**The list loops [decided 10-04].** If no manual line has been opened when
the list ends, it starts again at A3 and keeps cycling until the hand-over
or until `Field A Run` is switched off. One pass is exactly 24 h, so A4
stays on 20:00 and 02:00 on every pass. Each pass is 6 h per line, about
2.7" at the #12 rate of 0.45 in/hr (fields.md) **[reasoned]** — a second
day is a second 2.7" on the field that puddles, so a missed hand-over
sends a notification at the start of each extra pass.

**Hand-over (Saturday 08:00, Casey opens C3) [decided 10-04: opening
the riser is the trigger].** Field A and a C line together are ~170 GPM,
past the 5 HP limit, so Field A must close.

1. Casey opens the riser. Pressure falls below 40 while a Field A line
   runs.
2. pump-monitor marks the manual line the weekly schedule expects (C3)
   as running and asks pump-controller, through HA, to close every Field
   A line.
3. Manual lines ≥ 60 GPM and pressure < 56 for 30 s → Guard releases and
   the CVs close.

Closing Field A here cannot dead-head the pump: the low pressure is the
proof that the manual line is flowing. The dashboard toggle stays as the
way to correct it when the line opened is not the scheduled one.

If Casey arrives late, Field A is simply still cycling and the hand-over
works the same at any hour. Idling on the guard (pressure ~60, nothing
commanded) now only happens when `Field A Run` is off or the schedule has
stopped itself on a fault; opening a riser from that state marks the
scheduled line the same way. The existing swap-detected automation
keeps doing the manual-to-manual changes (3 → 1 → 4 → 2).

The request to close Field A crosses the network, which rule 1 allows:
it protects against motor overload for a few minutes, with the thermal
overloads behind it, not against a dead head.

## 14. Attended short-cycle test (before any unattended Field A day)

`Field A Block` is a number on pump-controller (minutes, default 180,
capped at 240 by the 4 h limit). Set it to **10** and start the day by
hand: the whole 3-1-3-2-4-1-4-2 list runs in 80 minutes, with Casey
watching.

10 rather than 30: what is on trial is the eight line changes and what
happens around them, not the watering. Ten minutes is long enough for the
60 s pressure check and the 5 min skip rule to play out, and short enough
that nothing puddles. At 30 the same eight changes take 4 hours.

| Watch for | Pass |
|---|---|
| Each change | next line opens, previous closes right after; no spike toward idle pressure |
| Guard | CV1 and CV2 stay at 25 % for the whole run |
| Pressure vs expected | inside ±1 psi a minute after each change (A1 54.7, A4 ~54.6, less ~0.5 for the guard flow) |
| Running Lines / gallons | the right line named each block; ~750 gal booked per block |
| End of list | the list wraps to A3 and carries on; switching `Field A Run` off closes the line and the state goes to IDLE ON GUARD, pressure ~60, no alert |
| Hand-over | open a manual riser afterwards: line marked, CVs close once pressure is < 56 for 30 s |

Then one provoked fault: pull one solenoid's wire at the valve box and run
the list again. Expected: LINE DID NOT OPEN alert at 60 s, that line
skipped at 5 min, the rest of the list unaffected. (The skip action must
be enabled for this run.)

Needs steps 1 and 5 flashed and the solenoids wired.

## 15. Unload before any pump stop

**Requirement (Casey, 10-04):** stopping the pump at ~60 psi blows the
suction line off in the pond, and reconnecting it means swimming. So
before the relay is dropped, pressure must be as low as it can be made:
**open all four Field A solenoids, then stop.**

Sequence, owned by pump-monitor (it holds the ICE relay):

1. State → UNLOADING. Ask pump-controller, through HA, to open A1–A4.
   Drive CV1 and CV2 to full open (local, costs nothing).
2. Wait for pressure < 30 psi, or 20 s, whichever comes first.
3. Drop the relay.
4. Pressure < 10 psi for 30 s → close A1–A4, CVs back to 25 %, `Field A
   Run` off. Nothing restarts by itself.

What the four lines should do to pressure, from the pump curve and the
Falcon lines flowing as √pressure **[reasoned; beyond the measured part of
the curve, which ends near 110 GPM]**:

| Field A lines open | Pressure | Flow |
|---:|---:|---:|
| 1 | ~54.5 psi **[measured]** | 75 GPM |
| 2 | ~41 psi | ~130 GPM |
| 3 | ~30 psi | ~165 GPM |
| 4 | ~21 psi | ~185 GPM |

Four lines is well past the 5 HP limit (~150 GPM), so the unload is held
for seconds only (the 20 s ceiling), and ~21 psi is right at the Furnas
20 psi cutoff — which may stop the pump itself a moment early. Both are
acceptable for a stop that is already under way. The real numbers come
from one attended run: open 2, 3, then 4 lines for ~10 s each and read
pressure and kW.

If the unload does not happen (HA down, 24 VAC dead, solenoids stuck):

| Kind of stop | Pressure still high after 20 s |
|---|---|
| Requested (`Pump Stop` button, maintenance) | abort, leave the pump running, alert |
| Protective trip (no-field-flow limit) | drop the relay anyway — the pump outranks the swim |

**`Pump Unload` button — wanted now (Casey, 10-04):** with Field A
underground there is no hand valve left to open before a stop. Steps 1–2
and 4 as a button: press it, watch the pressure fall, flip the starter by
hand. First version is an HA script using entities that already exist, so
it needs no flash: `ha/pump-unload.yaml`, drafted 10-04 and **used for
the season's last stop on 10-09** (results in section 16). It holds the
lines open for 60 s (time to reach the switch) and puts everything back
if the pump is still running. It moves into pump-monitor firmware with
the rest of this section when the relay is wired.

Not covered, and cannot be by this node: a power cut, the Furnas, the
thermal overloads, or the switch thrown without pressing the button
first. Those stop the pump at whatever pressure it is at.

## 16. Test morning, 2026-10-09 (last water of the season)

Solenoids are wired to pump-controller REL3–REL6 and each line checked by
hand (Casey, 10-08). Water goes off tomorrow, the pond is drained, lines
are blown out ~14:00. **Nothing from sections 4–13 is built.** So the
morning is run with two HA scripts and no flash, and its job is to
collect the numbers the firmware will be built on over the winter:

- `ha/pump-unload.yaml` — the unload button (section 15)
- `ha/field-a-test.yaml` — the 3-1-3-2-4-1-4-2 cycle with the CVs at 25 %

Both were drafts the night before (not deployed, never run); both ran on 10-09.

**Not flashing guard firmware tonight** — recommended. It would be new
safety code on the pump node, unbenched, the night before the only test
window, against the standing rule. The cost is real: the reflex cannot be
proven on water until spring.

Run sheet, in order. The pump is attended throughout.

| # | Do | Record | Status |
|---|---|---|---|
| 0 | Turn off the automations `Auto Close CV1` and `Irrigation rotation - line swap detected` | — | both can close CV1 mid-test |
| 1 | With B1 still open: CV1 and CV2 to 25 % | pressure, kW | **done 10-08 21:58: 57.94 psi, 3.88 kW** (CV1 only: 58.01, 3.85) |
| 2 | Close B1 by hand → pump idles on the two CVs, ~2 min | pressure **and kW** | first idle on 25 % + 25 %. No IR hold (see below) |
| 3 | Run `Field A Test Cycle`, 10 min blocks (80 min) | per line: pressure, kW; each change: any spike | all four lines under identical conditions; eight open-before-close changes |
| 4 | Let the cycle end: all lines close, idle on the CVs again | pressure and kW settle where step 2 did | the end-of-list / "line did not open" picture |
| 5 | With one A line running, open B1 by hand | size of the pressure step | **done 10-08 from the solenoid checks, see below** |
| 6 | Unload measurement: open 2, then 3, then 4 A lines, ~10 s each | pressure and kW at each | real numbers for section 15's table |
| 7 | The season's last stop: press `Pump Unload`, flip the starter | pressure at the moment of the stop; suction line still on? | the reason the button exists |

Notes for the morning:

- The level sensor reads `unavailable` tonight, and the pond is being
  drained with the canal off. Nothing will warn of low water; do step 7
  while there is still plenty over the intake.
- Steps 2 and 4 do not drain the pond (the water goes back). Step 3 takes
  about 6,000 gal.
- The blow-out can use the same four `Field A Line` switches with the
  pump off.

### Results so far (10-08, from the recorder)

**Thermal question closed by Casey, not by measurement:** with the bypass
open the casing does not warm enough for an IR gun to show anything; 5 GPM
is enough, and pumps like this are run dead-headed. The 30 min IR hold is
dropped from this run sheet and from step 1 of section 12.

**Second CV at 25 % moved pressure 0.07 psi** (58.01 → 57.94). Near
shutoff the pressure barely registers 2.3 GPM. Consequences:

- B1 tonight is flushing to the ditch, so 58.0 is not a normal 7-head
  number; a closed 7-head line read 59.3 **[measured 08-26]**. Idle on the
  CVs should be ~60.5–61. So a small hand line and idle are only ~1.5 psi
  apart, and the 58 psi threshold in sections 4, 5 and 8 is too low and
  too blunt.
- Power separates what pressure cannot: B1 flushing 3.88 kW, an A line
  4.35–4.41 kW, A + B1 4.93 kW. **Step 2's kW reading is the important
  one** — if idle is well under 3.9 kW, "no field flow" should be decided
  on kW and pressure together. That would bring the Shelly into a
  monitoring decision, never into the reflex.
- Curve-derived GPM is not to be trusted below ~60 GPM (the fit was made
  on 72–99 GPM).

**Hand-over signal (step 5), measured during the solenoid checks** — each
A line was opened with B1 running and CV1 at 25 %:

| | Pressure | kW |
|---|---:|---:|
| B1 alone, just before | 57.8 | 3.85 |
| + A1 (5 min) | 47.98 | 4.92 |
| + A2 (12 min) | 47.78 | 4.93 |
| + A3 (2 min) | 47.71 | 4.94 |
| + A4 (2 min) | 48.00 | 4.92 |

A 10 psi step that settles at ~48 and never reaches 40. **The hand-over
cannot key on "< 40"**; section 13 changes to "3 psi or more below
expected, sustained", which section 8 already defines. The four lines land
within 0.3 psi of each other.

**A3, 10-01 16:16–18:37 (2 h 21 min), both CVs at 25 %:** 53.35–53.40 psi,
4.41 kW, dead steady. A1 in the 25 minutes before it, same valves: 53.32.
So **A3 = A1** to within 0.1 psi. Open question: A1 that day (53.3 with
both CVs) sits ~1 psi under what 10-04 implies (54.74 closed, 54.28 with
one CV). Tomorrow's cycle, all four lines in one session, settles which.

### Results 10-09, 2 min cycle 08:50-09:06 (from the recorder)

All **[measured]**, both CVs at 25 %, v1 firmware.

- Order ran 3-1-3-2-4-1-4-2, every swap on its 2 min mark.
- Line pressure (last 60 s of each block): A1 53.2 / 53.3, A2 53.1 / 53.1,
  A3 53.0 / 53.0, A4 53.3 / 53.3. Power 4.43-4.47 kW on every line.
  45 min block: A3 52.83 psi, 4.45 kW.
- Swap: pressure dips to 42.8-43.1 psi (two lines open; section 15
  estimated 41), back to 53 in 21-23 s. No spike at any swap. Power peaks
  at 5.15 kW during the dip.
- Idle on the two CVs (09:06:21-09:07:15, no line open): **58.8 psi,
  3.25 kW**, reached 19 s after the last line was switched off. This
  replaces the "~60.5-61" idle guess above.
- Line opening from idle: 58.8 to 53 in about 8 s.

So pressure separates idle from a running A line by 5.5 psi and power by
1.2 kW. `Guard Reflex Pressure` default changed 59 -> 57 in
`pump-monitor-v2.yaml` (now `pump-monitor.yaml`).

### Flash and guard test (added 10-08, late)

`pump-monitor-v2.yaml` (now `pump-monitor.yaml`) = the current firmware
plus the guard only: `Guard`
switch (default ON, floor 25 % on both CVs at one choke point), the
pressure reflex (`Guard Reflex Pressure`, default 57 psi, 110 = never),
`Guard Reflex` problem sensor, and `Recycle Flow` (GPM from the valve
positions, 0.0923 per % per valve). Removed: the PID loop and `STOP All`.
Compiles clean on
ESPHome 2026.9.1 **[verified]**; never run on the board **[untested]**.
pump-controller is NOT reflashed: its relays were checked today and are
needed for the blow-out. Everything else in sections 5–13 is logic that
can be benched without water.

    ./upload.sh pump-monitor-v2.yaml 172.24.1.174   # as flashed; now ./upload.sh pump-monitor.yaml

Flash with no Field A line switching and both CVs already at 25 %; the
way back was `./upload.sh pump-monitor.yaml` (v1, now on branch `pid`).

| # | Guard check | Pass |
|---|---|---|
| G1 | After the flash, Guard ON, CVs at 25 % | nothing moves on boot; both still report 25 % |
| G2 | Press close on CV1 in HA | it stays at 25 % and HA shows 25 %, not closed |
| G3 | With an A line running (~54 psi), set `Guard Reflex Pressure` to 50 | within ~5 s `Guard Reflex` turns on; set it back to 57 and it clears a minute later. Logic proven with a flow path open |
| G4 | Guard OFF, close both CVs, A line running. Turn the A line off | pressure climbs past 57, `Guard Reflex` on, both CVs open to 25 % with nobody touching anything. This is a real dead head for roughly 10 s |
| G5 | Guard back ON | CVs at 25 %, cannot be closed |

**Results 10-09, v2 firmware flashed 10:25 with A1 running [measured]:**

- Flash: node back in 13 s, both valves still pulse 4 / 25 %, no valve
  relay fired, pressure unchanged. G1 pass.
- G2 pass: close pressed on CV1 and CV2, neither moved.
- G3 pass: threshold 50 -> `Guard Reflex` on 2 s later; back to 57 ->
  cleared 59 s later.
- G4 pass (A3, Guard off, both valves closed and re-homed, A3 switched off
  10:46:38): pressure crossed 57 at about +17 s, `Guard Reflex` on at
  +20 s, both valves at 25 % at +21 s. Peak 58.8 psi.
- **Dead head with both valves closed peaks at 58.3-58.8 psi, 3.22 kW** -
  the same as idling on the valves (58.4-58.8, 3.25 kW). The old default
  of 59 would not have tripped. 57 leaves 1.3 psi below the dead-head
  plateau and 2.3 above the highest running line.
- A3 with both valves closed: 53.5 psi; at 25 % + 25 %: 52.7.
- **Pump Unload, final stop 12:05:03 [measured]:** 4 lines + both valves
  full open: 52.9 -> 25.0 psi in 8 s, held 25.0 psi at 5.8-5.9 kW (a line
  alone is 4.44 kW) until the starter was dropped at about +27 s. Suction
  stayed on. Script then closed the lines and put the valves back to 25 %.
  Section 15 estimated 21 psi. The 2- and 3-line steps were not measured.

The blow-out does not involve the reflex: the transducer sits behind the
valve that is closed for it, so it never sees the compressor air (Casey,
10-08).

**Prediction for step 3, on record before the run:** the solenoids open
fast and close slowly, so each change should show a dip while two lines
are open, then recovery (Casey, 10-08). Two A lines ≈ 41 psi, ~130 GPM
**[reasoned]**. The dip's length is the valve's close time, and it sets
the settle wait before measured is compared with expected (60 s in
section 8). Open guess: whether the valves close quicker (Casey) or
slower (Claude) at the lower pressure. The pressure sensor averages ~4 s,
so a dip shorter than ~5 s will read shallower than it was.

## 17. PID history (v1, superseded by v2)

Formerly `PID-PLAN.md`. The loop ran on branch `pid` (2026-08-27 →
2026-10-09) and was removed in v2 because both CVs now park at 25 % and
stay there (section 4). The code is still `pump-monitor.yaml` on branch
`pid`.

**What it was.** ESPHome `climate: pid` + `climate.pid.autotune`
(built-in rather than hand-written, for anti-windup, derivative kick and
sample timing), cooling only: pressure above the `Pressure Setpoint`
(default 55 psi) opened CV2 through the pulse scripts. From 2026-09-10
CV1 was parked by hand at the ~5 GPM point as the guaranteed flow path
and CV2 was the loop's only actuator; output 100 % = pulse 10
(`pid_max_pulse`), not 16. The climate was `internal` because HA converts
climate °C → °F ("131 °F" for 55 psi).

**Tuned gains [measured 2026-09-10]:** Kp 0.492, Ki 0.0683, Kd 0.886.
Autotune on 12 heads with CV1 closed (natural 55.6 psi, floor 54.1 with
CV2 = 16), 15:40:44–15:41:19, 35 s, three 0↔16 swings. Then held
55.0–55.2 at pulse 6–7, output 40 %. Setpoint steps 54 / 54.5 / 55 / 55.5:
54 saturated cleanly (CV2 16, floor 54.1); no overshoot or hunting.

What it taught, still relevant:

- **Setpoint must be reachable.** Autotune is a relay test and needs
  pressure to cross the setpoint both ways; between "natural" and "both
  CVs open". Estimated floors: 12 heads 55.8 → ~52.9, 14 heads 55.5 →
  ~51, 7 heads 59.3 → ~56.8. 50 psi on 7 heads was unreachable.
- **Deadband and windup.** The first deadband (+0.5 / −1.0 psi) kept P and
  D off while the I-term wound into the pulse 9–16 plateau, so recovery
  from a saturated step took minutes. Fixed with deadband +0.2 / −0.3 and
  the pulse-10 cap. Pulses 1–8 carry essentially all the flow (README flow
  table).
- **Dead-reckoning bug (fixed, still in v2).** The queued pulse script
  stamped the counter with the *latest* target instead of the one it
  drove to; the loop queued targets faster than a 3 s close, and the
  counter read 10 with the ball near 3. Fix: latch the target when the run
  starts (`vN_pulse_run`). Resync = command close (0).
- **"CV1 and CV2 don't match" was the loop [measured 2026-09-10].** The
  climate writes its output every sample, 0 in mode OFF, so CV2 was being
  pinned shut, not sitting at the slider's pulse. With writes ignored while
  `Pressure Control` was OFF, both valves at 25 % looked identical at the
  pond. No per-valve calibration needed.
- **The loop does not notice a break.** A broken riser (−9 psi,
  2026-08-27) pushes pressure below setpoint, so the loop just closes CV2.
  Break detection is the expected-vs-measured residual (section 8).
