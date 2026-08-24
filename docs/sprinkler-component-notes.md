# ESPHome sprinkler component — notes for the lawn/zone node

Refs: <https://esphome.io/components/sprinkler/> · reference project
`bruxy70/Irrigation-with-display` (shallow-cloned to
`~/Projects/Irrigation-with-display`, Sonoff 4ch + Nextion; video transcript
in `docs/ESPHome-Irrigation-Controller-Transcript.md`).

## Why use it
Replaces hand-rolled timer globals + a polling `interval:` (the old pattern)
with a native controller. Minimal config is ~15 lines:

```yaml
sprinkler:
  - id: controller
    main_switch: "Irrigation"
    auto_advance_switch: "Auto Advance"
    valves:
      - valve_switch: "Lawn Zone 1"
        valve_switch_id: relay_z1
        run_duration: 900s          # or run_duration_number: for HA control
      - valve_switch: "Lawn Zone 2"
        valve_switch_id: relay_z2
        run_duration: 900s
```
Each `valve_switch_id` is an ordinary `switch: - platform: gpio` driving a
relay → 24 VAC solenoid.

## Keys that matter for THIS project
- `run_duration_number:` (per valve) — HA-adjustable zone durations, no reflash.
- **`valve_overlap:`** — next valve opens before the current one closes, so
  there is never an all-closed instant → **no dead-head at zone transitions**
  (the open-before-close rule, built in).
- `pump_start_valve_delay` / `pump_stop_valve_delay` / `pump_start_pump_delay`
  / `pump_stop_pump_delay` — master-valve/pump sequencing with spin-up/drain
  delays. (For a MASTER SUPPLY valve, not our recycle system — see below.)
- Actions: `sprinkler.start_full_cycle`, `start_single_valve`,
  `queue_valve` + `start_from_queue`, `shutdown`, `pause`/`resume`,
  `next_valve`/`previous_valve`, `set_valve_run_duration`, `set_multiplier`.
- Multiple `sprinkler:` controllers per device (Field A zones could be a 2nd
  controller later); latching valves via H-bridge (not needed — standard
  24 VAC solenoids here).

## Architecture split (important)
- **Sprinkler node** (2nd PLC-100): runs the `sprinkler:` component — zone
  sequencing, durations, cycling. The lawn zones live here.
- **Pump-monitor node** (this repo): the **recycle valves are pressure-
  driven**, reacting to whatever the sprinkler cycling does to pressure.
  The sprinkler component's "pump switch" is a master SUPPLY valve concept,
  NOT our recycle system — do not try to drive recycle from it. The two
  nodes coordinate only through the water/pressure, plus optionally HA.
- For the roadmap's dead-head stress test (section 0): the sprinkler node
  cycles the 2 lawn zones (open/close/... via the component), and the
  pump-monitor node's recycle logic must hold pressure through each close.
