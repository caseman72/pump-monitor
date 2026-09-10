# PID pressure control — plan and tuning log

Closed-loop trim of pump pressure using recycle valve CV2, built on
ESPHome's `climate: pid` component and its autotuner. Started 2026-08-27
on branch `pid`; reworked 2026-09-10 to CV1-fixed / CV2-on-the-loop.

**Layout (Casey, 2026-09-10).** CV1 is parked by hand at the ~5 GPM point
and is ALWAYS open whenever automated zone valves run (Field A later, the
lawn zones for testing now). It is the pump's guaranteed flow path: if a
solenoid fails closed the pump cannot dead-head or overheat. CV2 is the
loop's only actuator and holds the setpoint (55) — it may sit fully
closed when the line already runs below setpoint, and on a dead-head it
pulls ~60 psi down to 55 while CV1 keeps flowing.

## Why

The pump runs against the always-open aluminum irrigation lines; the
recycle valves exist to trim pressure down to a setpoint on small zones
(7/12/14-head runs now, automated Field A zones later). Until now the valves
were hand-driven (Pulse +/-). This work turns them into a real loop, tuned
by trial and error **now**, while a control mistake costs nothing, so the
PID constants are known before automation — where a control error is a
failure and possibly a costly one. Once tuned, the parameters don't change
(in theory).

Decisions (Casey, 2026-08-27):
- Use the built-in `climate: pid` + `climate.pid.autotune`, not a hand-written
  loop. A make-shift PID is where the "oh yeah, forgot about that" bugs live
  (anti-windup, derivative kick, sample timing); the built-in has those
  handled and ships tuning sensors for free.
- The setpoint is a plain HA number (psi), changeable any time like a
  mini-split. Default 55.
- ICE is unrelated to the loop and stays alert-only at 58. Autotune on
  12/14 heads can't reach it (natural 55.8 / 55.5); 7 heads (59.3) alerts
  with or without the PID, as it does today.
- ~~Closed floor is pulse 1 (water-zero), never pulse 0.~~ Superseded
  2026-09-10: CV2 may close to pulse 0 because CV1 is always open in this
  layout; seating CV2 never dead-heads the pump.

## Physics the tuning runs must respect

Fitted curve `H = 61.3 − 0.001165·Q²` (TODO.md §1), ~4.7 GPM per head,
both CVs wide open ≈ 29 GPM near shutoff. Reachable floor with both CVs
100%:

| line | natural psi | floor, both CVs 100% (est.) | usable autotune SP |
|---:|---:|---:|---|
| 12 heads | 55.8 | ~52.9 | 54 (tune here first) |
| 14 heads | 55.5 | ~51 | 52.5 |
| 7 heads | 59.3 | ~56.8 | 57.5 |

Autotune is a relay test: it bangs the output 0 ↔ 100 % and needs pressure
to cross the setpoint **both ways**. So the SP for a tuning run must sit
between "natural" and "floor". **50 psi on 7 heads is unreachable** — the
valves saturate, the integrator winds up, autotune never converges. Tune on
12 or 14 heads; use 7 heads to confirm the loop saturates cleanly (valves
100 %, pressure ~57 = the "alarm by design" case from TODO §1).

What the loop does NOT do: notice a break. A broken riser (2026-08-27,
−9 psi step) pushes pressure *below* setpoint, so the loop drives recycle
to its floor and stays out of the way. Break/fault detection is the
residual-alarm design in TODO §1 (expected − measured), not the PID.

## Firmware design (`pump-monitor.yaml`)

All new blocks; nothing in the existing valve or ICE logic changes.

**Sensor** — `pid_pv`: `copy` of `pump_pressure`, internal. The pid
component only needs a numeric sensor; unit is irrelevant. Updates every
2 s (existing ADC filter: 8-sample window, send_every 4 → ~4 s lag).

**Output → CV2** — `output: platform: template, type: float, id:
recycle_out`. The one lambda in the design: PID output 0..1 → CV2 pulse
target 0..16 (linear, `lroundf(state × 16)`) → `v2_pulse_go` (queued, one
continuous drive from the current counter, no re-home). CV1 is not
touched by the loop. A target equal to the last requested one is skipped
so repeated identical outputs don't stack queued moves.

The plant is nonlinear in pulse count: per the README flow table, pulses
1–8 carry essentially all the flow and 9–16 add almost none. Autotune's
relay test bangs 0 ↔ 16, so the gains it finds are an average over that;
so the output is capped: 100 % = `pid_max_pulse` (10, set 2026-09-10)
rather than 16.

Inherent behaviours, no extra handling needed:
- Pump off → pressure ~0 < SP → output 0 → CV2 closes to pulse 0.
- Open transducer lead → 110 psi → full cool → CV2 100 % = the safe state
  (plus CV1's fixed opening).
- Pressure Control OFF → pid mode OFF → output 0 → CV2 closed.

**PID climate** — `pid_pressure`, `internal: true` (HA converts ESPHome
climate temperatures °C→°F, so a thermostat card would read "131 °F" for
55 psi; the climate object is only the engine). `cool_output: recycle_out`
only: pressure above SP → output > 0 → valves open; below → 0 → floor.
Starts with kp/ki/kd = 0; autotune fills them in, then they get baked into
the yaml.

**HA-facing entities**
- `Pressure Setpoint` (number, psi, 30–70 step 0.5, restored) → `climate.control target_temperature`
- `Pressure Control` (switch, restored, default OFF) → mode COOL / OFF
- `PID Autotune` (button) → `climate.pid.autotune` (noiseband 0.5 psi ≈ sensor noise). No cancel action exists — restart the node to abort.
- `PID Kp / Ki / Kd` (numbers, config) → `climate.pid.set_control_parameters`, to nudge gains from HA without a reflash
- `PID Result / Error / P / I / D / Kp / Ki / Kd` (the component's own `sensor: platform: pid` types)
- `Recycle Output %` (0–100 = CV2 pulse / 16, from the write_action)
- `Pressure Control Reset Integral` (button) → `climate.pid.reset_integral_term`

## Tuning procedure

The pump never turns off, so every step is live. The loop can only open
the valves when pressure is ABOVE the setpoint, so a setpoint above
anything the pump can make (70) is the "do nothing" state.

1. Flash. Pressure Control OFF. Confirm nothing moves on boot.
2. Park CV1 at the measured ~5 GPM pulse (Pulse Target or the slider) and
   leave it there for the whole session.
3. Chain check: Pressure Setpoint 70, Pressure Control ON → output 0 % →
   CV2 pulse 0 (log: `output 0% -> CV2 pulse 0`; nothing moves if it was
   already seated). Then Setpoint 30 → output 100 % → CV2 drives to 16 in
   one pull. Back to 70 → CV2 closes. CV1 must not move at any point.
4. Run the 12-head set (A-4 + A-3, natural 55.8). Setpoint 54.
5. Press PID Autotune. Recycle Output % bangs 0 ↔ 100 (CV2 pulse 0 ↔ 16)
   and pressure oscillates around 54. Autotune logs `PID Autotune
   finished` with kp/ki/kd (also on the PID Kp/Ki/Kd Active sensors).
6. Type the values into the Kp/Ki/Kd numbers to run them live; step SP
   54 → 55 → 54 and watch settling. Pass: no hunting beyond ±1 pulse,
   overshoot < 2 psi. Then bake them into `control_parameters`.
7. 14 heads (SP 52.5) — should hold with the same gains. Then 7 heads:
   SP 57.5 (reachable) and SP 50 (unreachable — confirm CV2 goes to 16
   and behaves when SP is raised again).
8. Disturbance test: a lawn zone on top of a line (−4 psi step).
9. Record every run below; commit the gains.

## Results log

| date | line | SP | Kp | Ki | Kd | overshoot | settle | hunting | notes |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| 2026-09-10 | 12 heads, CV1 closed | 55 | 0.492 | 0.0683 | 0.886 | | | | Natural 55.6, floor 54.1 (CV2 = 16). Autotune 15:40:44–15:41:19, 35 s, three 0↔16 swings. Held 55.0–55.2 at pulse 6–7, output 40 %, I-term creeping in-band as designed. Gains baked into control_parameters. |
| 2026-09-10 | 12 heads, CV1 closed | 54 / 54.5 / 55 / 55.5 | 0.492 | 0.0683 | 0.886 | none | slow → ok | none | Steps: 54 saturated cleanly (CV2 16, floor 54.1). Back to 54.5 took minutes: deadband +0.5/−1.0 kept P/D off (real noise ±0.1, window 1.6 psi) and the I-term had wound into the pulse 9–16 plateau. Fixed: deadband +0.2/−0.3, output capped at pulse 10 (`pid_max_pulse`). Then found a dead-reckoning bug: queued pulse script stamped the counter with the *latest* target, not the one it drove to — PID queues targets faster than a 3 s close, counter read 10 while the ball sat near 3. Fixed by latching the target at run start (`vN_pulse_run`). Resync = command close (0). |

## Superseded notes (from PRESSURE-CONTROL.md, 2026-08-27)

Original sketch: fake a °C sensor and point `cool_output` at the valve
entity. Two corrections: `cool_output` must be a float `output:`
component, not a `valve:` (hence the template output above), and the
setpoint moved from 50 to a changeable number defaulting to 55. Open
questions from that note — deadband thresholds, averaging samples, alarm on
"CV1 full open and pressure still high", logging known CV values per line
— are answered by: deadband +0.5 / −1.0 psi (P and D off inside, I at 5 %,
15-sample ≈ 30 s output averaging in-band; 5-sample ≈ 10 s outside — the
PV publishes every 2 s), the residual alarm in TODO §1, and the results
log here.
