# PID pressure control — plan and tuning log

Closed-loop trim of pump pressure using the two recycle valves (CV1/CV2),
built on ESPHome's `climate: pid` component and its autotuner. Started
2026-08-27 on branch `pid`.

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
- Closed floor is **pulse 1 (water-zero)**, never pulse 0 / flow 0% — those
  are seat drives, only done with the pump off (README).

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

**Output → valves** — `output: platform: template, type: float, id:
recycle_out`. The one lambda in the design: PID output 0..1 → combined
recycle flow 0..200 % (CV1 fills 0–100 first, then CV2) → per-valve flow %
→ `vm_flow_to_frac` → `vm_frac_to_pulse` (`valve_math.h`) → pulse target →
`v1_pulse_go` / `v2_pulse_go` (queued, no re-home). Using the flow table
means the loop sees a roughly linear plant despite the ball's nonlinear
curve. Never `v1_go` — that re-homes to full open on every move. Pulse
target floors at 1. A target equal to the last requested one is skipped so
repeated identical outputs don't stack queued moves.

Inherent behaviours, no extra handling needed:
- Pump off → pressure ~0 < SP → output 0 → valves park at pulse 1.
- Open transducer lead → 110 psi → full cool → both CVs 100 % = the safe state.
- Pressure Control OFF → pid mode OFF → output 0 → valves to floor.

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
- `Recycle Output %` (0–200, from the write_action)
- `Pressure Control Reset Integral` (button) → `climate.pid.reset_integral_term`

## Tuning procedure

The pump never turns off, so every step is live. The loop can only open
the valves when pressure is ABOVE the setpoint, so a setpoint above
anything the pump can make (70) is the "do nothing" state.

1. Flash. Pressure Control OFF. Confirm nothing moves on boot.
2. Chain check: Pressure Setpoint 70, Pressure Control ON → output 0 % →
   floor = pulse 1, so both seated valves step 0 → 1 once (log: `output
   0% -> CV1 pulse 1`) and then nothing else moves. Pulse 1 weeps ~1 %
   flow (~0.3 GPM) to the pond — expected; only pulse 0 seals.
3. Run the 12-head set (A-4 + A-3, natural 55.8). Setpoint 54.
4. Press PID Autotune. Recycle Output % bangs 0 ↔ 200 and pressure
   oscillates around 54. Autotune logs `PID Autotune finished` with
   kp/ki/kd (also on the PID Kp/Ki/Kd Active sensors).
5. Type the values into the Kp/Ki/Kd numbers to run them live; step SP
   54 → 55 → 54 and watch settling. Pass: no hunting beyond ±1 pulse,
   overshoot < 2 psi. Then bake them into `control_parameters`.
6. 14 heads (SP 52.5) — should hold with the same gains. Then 7 heads:
   SP 57.5 (reachable) and SP 50 (unreachable — confirm valves go 100 %
   and behave when SP is raised again).
7. Disturbance test: a lawn zone on top of a line (−4 psi step).
8. Record every run below; commit the gains.

## Results log

| date | line | SP | Kp | Ki | Kd | overshoot | settle | hunting | notes |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| | | | | | | | | | |

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
