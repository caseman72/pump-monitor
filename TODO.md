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
| **Green** | 30–60 psi | nothing |
| **Yellow** | > 60 psi (or < 30) | Valve 1 opens in steps (Pulse +) until pressure is back below 60; when Valve 1 reaches 100%, Valve 2 starts opening the same way |
| **Red** | > 70 psi with **both** valves at 100% | hold and wait — ~1 min — for the recycle path to bring it down |
| **DEFCON 1** | > 80 psi, both valves 100%, and > 70 psi for over 1 min | cut power to the pump (ICE trip, latched) |

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

Recycle valves closed unless noted. Transducer-calibrated psi.
Naming: **house zones 1–4** (residential lawn, evenings) and **pump zones
1–2** (irrigation, mornings ~5–6 am); **line N** = the long irrigation lines.

| Date | Running | psi | Notes |
|---|---|---:|---|
| 2026-08-23 | irrigation line 1 (smallest long line) | 51.5 | steady |
| 2026-08-23 | line 1 + house zone 1 (front lawn) | 47.4 | −4 psi from one residential zone; steady ±0.1 |
| 2026-08-23 | line 1 + house zone 2 | 48.5 | house system has 4 zones, cycles 1→4 |
| 2026-08-23 | line 1 + house zone 3 | _pending_ | |
| 2026-08-23 | line 1 + house zone 4 | _pending_ | |
| 2026-08-24 | line 1 + pump zone 1 | _pending_ | morning run ~5–6 am — read from HA history |
| 2026-08-24 | line 1 + pump zone 2 | _pending_ | |

## 2. ICE wiring & policy decisions (open)

- [ ] Wire the ICE relay into the pump loop. **NC energize-to-trip
      recommended** (`ice_run_energized: "false"`): reboots, crashes, dead
      controller all leave the latching starter loop closed.
- [x] Furnas pressure switch **cuts out at 10 psi** (confirmed 2026-08-23);
      that's the hardware floor under the ICE Low Trip (20) and the
      `Pump Running` threshold (> 10). Cut-in / high-side setting still to
      confirm so the ICE High Trip is known to sit above it.
- [x] Low Trip is the primary broken-line protection (fires ~10 s after
      pressure falls below 20; the Furnas at 10 psi and the starter's
      thermal overloads are the backups). Start window: pressure must reach
      low+10 within 60 s of pump start or it trips. After any trip the loop
      re-closes automatically once the pump is confirmed stopped, so a
      manual restart at the pump house works; the alert stays latched until
      ICE Reset.
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
