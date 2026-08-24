# Pump Monitor

ESPHome firmware for an irrigation pump node: an **ESP32-C6-DevKitC** seated in
a **Canaduino ESP32 PLC-100 V1**, driving two motorized 1/2" stainless ball
valves and a pump enable relay through the board's relays, and reading a
pressure transducer. Each valve appears in Home Assistant as a native `valve`
entity with a 0–100% position slider — and **position means calibrated flow
percent, not ball rotation** (see [Flow calibration](#flow-calibration)) — plus
an incremental **Pulse Position** for fine trims.

## Hardware

| Component | Detail |
|---|---|
| Controller | ESP32-C6-DevKitC-1 on Canaduino ESP32 PLC-100 V1 |
| Valve 1 | REL1 (close) / REL2 (open) — PCA9557 IO1/IO2 |
| Valve 2 | REL3 (close) / REL4 (open) — PCA9557 IO3/IO4 |
| Pump ICE enable | REL5 or REL6 (selectable) → external Songle 2-relay module, NO contact in line with pump control wiring |
| Pressure | 1–5 V ratiometric transducer, 0–100 psi, on AI1 (GPIO0, ~3:1 divider). Calibrated to the transducer spec (dial gauge read ~8 psi higher; transducer trusted — absolute psi is a reference, the trace shape is what matters) |
| Relays | PCA9557 I2C expander @ 0x1A → ULN2003 (IO1..IO6; IO0 unused) |
| I2C | SDA=GPIO6, SCL=GPIO7 (DS3231 RTC @ 0x68 shares the bus) |
| Valves | 1/2" SS motorized ball valve, ~3.55 s travel, internal end-stop switches |
| Power | 12–24 V on the board supply terminals (relay coils from onboard 5 V buck) |

The actuators have internal end-stop limit switches, so driving past full
travel is harmless — the firmware exploits this to re-home on every move.

## How positioning works

The valves have no position feedback; position is dead-reckoned by motor
run-time. To keep that accurate:

1. **Every move re-homes at FULL OPEN** (drive open for travel + 0.25 s;
   the end-stop absorbs the overrun). The pump never gets dead-headed
   mid-move — the transient is extra flow, never zero flow.
2. The firmware then **close-pulses down to the target** using the flow
   table. Every position is approached from the same direction, so gear
   backlash cancels.
3. **Position 0% is the exception**: it drives the ball hard onto the seat
   (full close). *Only command 0% with the pump off.*

A 20 s dead-man timer forces the valve relays off if anything (including a
lost Wi-Fi/HA connection) leaves one energized.

### Pulse Position (incremental mode)

Each valve also has a **Pulse Position** number (0–16) for small trims
without the full re-home cycle — the primitive for pressure control
("pressure high → +, pressure low → −"). Counter semantics:

| Counter | Ball position |
|---:|---|
| 0 | seated (hard on the end-stop) |
| 1 | breakaway pulse (travel − 3.0 s ≈ 0.55 s) — water-zero, flow ≈ 0 |
| 2 … 15 | +0.2 s of open travel per count |
| 16 | full open (= full travel) |

The **Pulse +** / **Pulse −** buttons step the counter by one (automations:
`button.press`); each press advances the last *requested* target, so rapid
presses accumulate correctly. The **Pulse Target** number jumps straight to
N. Either way the valve moves from its current counter to the target in one
continuous pulse (open or close).
Pulse moves are dead-reckoned (no re-home) so error accumulates; any move
on the flow slider re-homes and resyncs the counter, and pulse moves update
the valve's reported flow %. Counter and position survive reboots (the ball
doesn't move when the ESP restarts).

**Reboot behaviour.** All relays are commanded OFF at boot and nothing moves
the ball. Reported positions are seeded at boot from restored globals,
because ESPHome's `Valve::position` is an uninitialized float — without the
seed, a first boot after a flash reports RAM garbage (clamped to 1.0 =
"open"), which is what once looked like "the valves opened on reboot".
Diagnosed 2026-08-23 from the pressure history: no dip at boot, dips only
during the manual closes that followed.

Power-on is also clean: the PCA9557 comes up all-inputs with 100 kΩ
pull-ups, but the ULN2003's built-in input network (2.7 kΩ series + 7.2 kΩ
base-to-ground) holds each driver input at ~0.3–0.45 V — well below the
~1.4 V a Darlington needs — so the relays cannot pull in during boot.
Relays are commanded OFF the moment ESPHome configures the expander.

### Per-valve calibration constant

Each valve's **Full Travel Time** is a number entity in HA (default 3.55 s).
Everything scales from it at runtime — swapping in a replacement valve of the
same model only requires measuring its travel (seat test: drive closed onto
the seat, then time open-to-endstop) and typing the number into HA. No reflash.

## Flow calibration

On a ~60 psi static supply (city faucet ≈ the irrigation pump), the installed
flow curve of these ball valves is extremely nonlinear: **~10% of ball travel
already passes over half of max flow, and everything above ~35% travel is
plateau**. All real control authority lives in the first quarter of rotation.

The firmware therefore maps commanded flow % → ball position through a
measured table (`VM_OPEN_FRAC` in `valve_math.h`), built with a bucket test
(2026-08-17, 30 s holds, constant-transient protocol):

| Flow % | Ball position (fraction of travel from seat) |
|---:|---:|
| 0 (water-zero) | 0.141 |
| 5 | 0.197 |
| 10 | 0.225 |
| 15 | 0.254 |
| 25 | 0.275 |
| 50 | 0.34 *(provisional)* |
| 80 | 0.43 *(provisional)* |
| 95 | 0.53 *(provisional)* |

Anchors ≤25% are solid (trickle-sweep measurements). The 50–95% anchors are
converted from an earlier sweep with a contaminated blank — re-verify with
clean bucket runs (see TODOs). Note the valve has *two* zeros: water stops at
~0.14 of travel (water-zero); the mechanical seat is further (seat-zero).

### Calibration procedure (for a new valve or supply)

1. Measure **Full Travel Time** (seat test) and set the HA number.
2. **Blank run**: command position 0, run the bucket protocol — the weight
   is tare + transient water (the constant to subtract from every trial).
3. Sweep positions with fixed hold times, weigh the bucket each run.
   Flow fraction = (weight − blank) / (max-flow weight − blank).
4. Update the `VM_OPEN_FRAC` anchors in `valve_math.h`.

## Home Assistant entities

- **Valve 1 / Valve 2** — native valve entities: position slider (= flow %),
  open / close / stop buttons
- **Valve N Pulse Position** — integer sensor, the 0–16 pulse counter
  (see above); **Valve N Pulse +** / **Pulse −** buttons step it, and the
  **Valve N Pulse Target** number (config category) jumps straight to N
- **Pump Pressure** (psi) and **Pressure Sensor Voltage** (diagnostic, for
  calibration trimming)
- **Valve N Full Travel Time** — per-valve calibration constant
- **Valve N Open/Close (RELx)** switches — raw relay diagnostics
- **Valve N Elapsed / Last Open Time / Last Close Time** — motion
  diagnostics (verify positioning pulses without log access)
- **Control Wiring Relay** — the pump ICE (in-case-of-emergency) protection.
  The pump runs on a *latching* starter loop: one break = pump off until a
  manual restart. So the loop is opened **only on a latched pressure trip**,
  never by a reboot or a switch:
  - **ON = bypass**: loop held closed unconditionally (work on the board,
    reboot, swap a valve). Default; remembered across reboots.
  - **OFF = automation armed**: loop still closed; opened only when pressure
    is ≥ **ICE High Trip** (default 95 psi, sustained 3 s) or ≤ **ICE Low
    Trip** (default 20 psi; 0 disables; arms only after 30 s above low+10,
    then sustained 10 s). A trip latches (**ICE Tripped**, reason in **ICE
    Status**) until **ICE Reset**. A sensor fault (transducer voltage out of
    the 0.7–5.3 V range) never trips.
  - **ICE Test Mode**: the trip logic runs and reports "TEST: would trip …"
    in ICE Status but never actuates the relay — lower the High Trip and
    close the main valve slowly to prove it with zero risk.
  - **Control Wiring Relay Select** picks REL5 or REL6 (spare swap without a
    reflash); changes are make-before-break.
  - Polarity is the `ice_run_energized` substitution. `"true"` = loop through
    the module's **NO** contact, relay energized to run (an ESP reboot drops
    the loop ~1 s — fatal on a latching starter). `"false"` = loop through
    **NC**, relay energized only to trip — reboots, crashes and a dead
    controller leave the pump running. **NC is the recommended wiring.**
  - The valve dead-man timer and STOP All never touch these relays.
- **STOP All** — valve relays off immediately (does not touch the ICE
  relay); **Restart** — reboot the ESP; **ICE Reset** — clear a latched trip
- WiFi RSSI, IP Address, WiFi Network, Uptime

## Building & uploading

Secrets never live in the YAML — `upload.sh` parses `secrets.h` and injects
them as ESPHome substitutions:

```sh
cp secrets.example.h secrets.h   # then fill in values
./upload.sh                      # OTA to DEVICE_IP from secrets.h
./upload.sh 192.168.1.50         # or an explicit device / hostname
```

Note: mDNS may not resolve on your network (it doesn't on DD-WRT) — use
the device IP or the router's DNS name (`pump-monitor`).

If Wi-Fi is unreachable the device broadcasts a fallback hotspot
(`Pump-Monitor`, password = `AP_PASSWORD`) — connect and reach it at
192.168.4.1 to recover or OTA.

To rotate the OTA password: set the new value in `OTA_PASSWORD`, add
`#define OTA_OLD_PASSWORD "<current device password>"`, run `./upload.sh`
once (it compiles the new password in while authenticating with the old),
then delete the `OTA_OLD_PASSWORD` line.

## TODO

- [ ] Pressure control automation using Pulse Position increment/decrement
      (feedforward table per irrigation line + slow PI trim, 55 psi setpoint)
- [ ] Recycle failsafe: when zone solenoids are automated, open Valve 1 to
      ~15% if the HA/API connection is lost (keeps the 5 HP pump cool)
- [ ] Wire the ICE relay into the pump loop (NC recommended) and run the
      Test Mode exercise at a ~60 psi threshold first
- [ ] Sprinkler node: second PLC-100, 24 VAC solenoids, 2–3 zones now (+4
      later); open-next-before-close-previous sequencing
- [ ] DS18B20 temperature (like revel-monitor) — `one_wire` on a spare GPIO
- [ ] Measure Valve 2's Full Travel Time after install
- [ ] Re-verify the 50–95% flow anchors with clean-blank bucket runs
- [ ] Confirm calibration on the real pump once plumbed in (~60 psi static,
      so the faucet numbers should transfer)

## Repo files

- `pump-monitor.yaml` — production firmware (two valves, ICE relay, pressure)
- `valve_math.h` — flow↔position table and pulse-counter math shared by
  both valves and both positioning modes
- `pump-monitor-proof-of-concept.yaml` — single-valve bench-calibration rig this project grew
  out of (still what shipped the calibration data)
- `upload.sh` / `secrets.example.h` — secret-free build workflow

## License

MIT
