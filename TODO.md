# TODO

Working list for the Pump Monitor node. Numbers below are first guesses —
revisit after the ~2-week pressure-monitoring period (Aug/Sep 2026).

## 1. Staged pressure response (the real control system) — NOT YET

Today the ICE layer is a plain threshold: ≥ High Trip (95 psi) for 3 s →
open the pump loop. The intended system is staged: the recycle valves
absorb pressure first, and cutting the pump is only for the case where
that response has already failed. A pump cut should never be an anomaly
the system didn't see coming.

Zones (on `Pump Pressure`):

| Zone | Condition | Response |
|---|---|---|
| **Green** | ~48–62 psi at the gauge (BEP ≈ 57; below ~46 the 5 HP motor is at full load — overload territory; above ~62 flow is dropping toward dead-head at ~70) | nothing |
| **Yellow** | > ~62 psi (or < ~48) | Valve 1 opens in steps (Pulse +) until pressure is back in band; when Valve 1 reaches 100%, Valve 2 starts opening the same way. Low side: pressure < ~48 means flow > ~140 GPM — motor near full load — so the response there is to CLOSE recycle, not open |
| **Red** | > ~64 psi with **both** valves at 100% | hold and wait — ~1 min — for the recycle path to bring it down |
| **DEFCON 1** | at/near dead-head (~66+ psi at the gauge), both valves 100%, sustained | cut power to the pump (ICE trip, latched). Interim: the flat 65 psi ICE High Trip is live today. NB: the pump physically cannot exceed ~70 psi at the gauge, so 80 was unreachable |

Design notes:
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

Line data (pipe sections, each with a sprinkler): 1 = 6+8+2 = **17**,
2 = 6+8+3 = **17**, 3 = 6+8+5 = **19**, 4 = 6+8+6 = **21**. More pipes =
more flow = lower pressure. Rotation **3 → 1 → 4 → 2** (changes ~9 am;
avoids double watering). Curve-based predictions in the last column —
Casey will do a quick run on each line (2026-08-24) to fill the table.

| Line | Pipes | Base psi | Date | Notes / prediction |
|---|---:|---:|---|---|
| line 1 | 17 | 51.5 | 2026-08-23 | steady; ≈125 GPM on the curve (right of BEP) |
| line 2 | 17 | _pending_ | | predict ≈ line 1 (~51–52) |
| line 3 | 19 | _pending_ | | predict ~49–50. (Dial read ~62 on 2026-08-19 with line 3 on — inconsistent with the pipe count; the dial's offset is evidently not a constant 8 psi. Ignore the dial.) |
| line 4 | 21 | _pending_ | 2026-08-24 ~9 am | predict ~47–48; with an evening lawn zone on top, ~43–45 → ~150 GPM ≈ 5 HP motor near full load per the curve (Casey: overloads trip when warranted; the original heaters dropped occasionally at the high-flow end, so they were upsized with the pump installer's OK — consistent with the curve. With bigger heaters there's less thermal margin, so the controller's pressure FLOOR (~46–48 psi at the gauge) is a real motor-protection constraint, not just an efficiency preference. Pump leads were also upsized 12 → 10 AWG (12 AWG is 20 A-rated vs ~23 A full load — hot leads + voltage drop = extra current = nuisance heater drops); the installer's clamp reading came in lower than expected, so the motor has real headroom. A clamp-meter reading on line 4 + lawn zone 1 would still put a number on it) |

### Lawn zone deltas (measured on line 1)

| Lawn zone | psi observed | Delta | Date |
|---|---:|---:|---|
| zone 1 (front) | 47.4 | −4.1 | 2026-08-23 (≈145 GPM — motor near full load) |
| zone 2 | 48.5 | −3.0 | 2026-08-23 |
| zone 3 | 49.8 | −1.7 | 2026-08-23 |
| zone 4 | 51.1 | −0.4 | 2026-08-23 |

### Pump zones (mornings)

| Pump zone | psi observed | Delta vs line base | Date |
|---|---:|---:|---|
| pump zone 1 | _pending_ | | 2026-08-24, read from HA history |
| pump zone 2 | _pending_ | | |

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
      PCF8574 + relay module if it ever hits 7).
- [ ] Open-next-before-close-previous sequencing so a flow path always
      exists; a few seconds of delay between zones. No solenoid timing
      exists (OpenSprinkler only has station delay / master on-off adjust).
- [ ] MEGA2560 PLC-300 rejected: no ESPHome on AVR.

## 5. Calibration & sensors

- [ ] DS18B20 temperature (like revel-monitor) — `one_wire` on a spare GPIO
- [ ] Measure Valve 2's Full Travel Time after install
- [ ] Re-verify the 50–95% flow anchors with clean-blank bucket runs
- [ ] Confirm the valve flow table on the real pump (60 psi static, so the
      faucet numbers should transfer)
- [ ] Pressure: transducer trusted over the dial (~8 psi apart at the same
      tap; moving the transducer to the main leg won't change a dead-end
      reading). Next pump-off: check both read 0.
