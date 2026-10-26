GOAL:
I want the pump monitor to control the irrigation pump's pressure and ensure that it is always in a safe state.

HA Server:
`ssh machone`


Mechanically:
* CV1 and CV2 are valves on 1/2" PEX that return to the pond

```
valve.pump_monitor_valve_1
valve.pump_monitor_valve_2
```

Electronically:
* We have REL5/6 -> a relay to interupt the PUMP running circuit (it should be on 100% of the time!)
* It's not wired yet but eventually will be

Soon: Field A's relays to the solenoids


We have PID control already tuned for CV2 (see yaml):

```
PID Kd 0.88600%
PID Ki 0.06830%
PID Kp 0.49200%
```


We have helpers for GPM:
```
{# Field flow = pump-curve flow − recycle.
   Pump curve fit 2026-08-25: P = 61.3 − 0.001165·Q²
   Recycle fit 2026-10-01: 5 gal / 130 s at 25% → 0.0923 GPM per % open, per valve #}
{% set p = states('sensor.pump_monitor_pump_pressure') | float %}
{% set d = 61.3 - p %}
{% set q = min((sqrt(d / 0.001165) if d > 0 else 0), 150) %}
{% set v = state_attr('valve.pump_monitor_valve_1', 'current_position') | float(0)
         + state_attr('valve.pump_monitor_valve_2', 'current_position') | float(0) %}
{{ max(q - 0.0923 * v, 0) | round(1) }}
```

We a helper for estimating pressure `sensor.pump_monitor_irrigation_est_pressure`:

```
{% set ns = namespace(heads=0) %}

{% for lineEntityId in states.input_boolean
  | selectattr('state', 'eq', 'on')
  | selectattr('entity_id', 'search', '^input_boolean\.field_[abc]_line_\d+$')
  | map(attribute='entity_id')
  | map('replace', 'input_boolean', 'input_number')
  | map('regex_replace', '$', '_heads') %}

  {% set ns.heads = ns.heads + states(lineEntityId) | float(0) %}
{% endfor %}
{% for zoneEntityId in states.switch
   | selectattr('state', 'eq', 'on')
   | selectattr('entity_id', 'search', '^switch.(home|pump)_controller_(home|pump)_lawn_zone_\d+$')
   | map(attribute='entity_id')
   | map('replace', 'switch', 'input_number')
   | map('regex_replace', '_controller_(home|pump)', '')
   | map('regex_replace', '$', '_heads') %}

  {% set ns.heads = ns.heads + states(zoneEntityId) | float(0) %}
{% endfor %}

{# Recycle fit 2026-10-01: 0.0923 GPM per % open, per valve. Heads fit: 4.7 GPM/head, P = 60.2 − 0.001265·Q² #}
{% set v = state_attr('valve.pump_monitor_valve_1', 'current_position') | float(0)
         + state_attr('valve.pump_monitor_valve_2', 'current_position') | float(0) %}
{% set q = 4.7 * ns.heads + 0.0923 * v %}

{{ 60.2 - 0.001265 * q * q }}
```

We have automations to see when lines are swapped `automation.irrigation_rotation_line_swap_detected`:

```
alias: Irrigation rotation - line swap detected
description: >-
  Pressure < 40 while the pump is running = a line swap in progress. Add today's
  scheduled lines immediately (union with the old line, so Est Pressure sees
  both open pipes during the fill), then once pressure recovers > 48, turn off
  everything running except today's lines.
triggers:
  - trigger: numeric_state
    entity_id: sensor.pump_monitor_pump_pressure
    below: 40
conditions:
  - condition: state
    entity_id: binary_sensor.pump_monitor_pump_running
    state: 'on'
actions:
  - action: input_boolean.turn_on
    target:
      entity_id: '{{ states(''sensor.pump_monitor_irrigation_lines'').split('','') }}'
  - wait_template: '{{ states(''sensor.pump_monitor_pump_pressure'') | float(0) > 48 }}'
    timeout:
      hours: 0
      minutes: 10
      seconds: 0
      milliseconds: 0
    continue_on_timeout: false
  - action: input_boolean.turn_off
    target:
      entity_id: |-
        {{ states.input_boolean
           | selectattr('entity_id', 'search', '^input_boolean\.field_[abc]_line_\d+$')
           | selectattr('state', 'eq', 'on')
           | map(attribute='entity_id')
           | reject('in', states('sensor.pump_monitor_irrigation_lines').split(','))
           | list }}
  - delay: '00:05:00'
mode: single

```

We have template for which is the next line to be used based on a list `sensor.pump_monitor_irrigation_lines`:

```
{% set t = now() - timedelta(hours=6) %}                       {# day = 6 AM→6 AM, PM = after 6 PM #}
{% set jan4 = as_datetime(t.year ~ '-01-04').date() %}
{% set week1_monday = jan4 - timedelta(days=jan4.weekday()) %}
{% set days = states('input_text.irrigation_schedule').split(',') %}
{% set n = (t.date() - week1_monday).days % (days | length) %}
{% set halves = days[n].split('|') %}
{% set pm = 1 if (halves | length > 1 and t.hour >= 12) else 0 %}
{% set ns = namespace(e=[]) %}
{% for code in (halves[pm] | trim).split('+') %}
  {% set c = code | trim %}
  {% set ns.e = ns.e + ['input_boolean.field_' ~ (c[0] | lower) ~ '_line_' ~ c[1]] %}
{% endfor %}
{{ ns.e | join(',') }}
```

I will be adding solenoid controls to Line A this week:
* switch.pump_controller_field_a_line_1
* switch.pump_controller_field_a_line_2
* switch.pump_controller_field_a_line_3
* switch.pump_controller_field_a_line_4

When these lines are in use -> there is a danger that something happens and the solenoid closes.

So - we should always turn on CV1 to 25% and CV2 to 25% - this is 5 gal per min to the pond

I made an automation for this based on the input_booleans `automation.auto_open_cv1`:

```
alias: Auto Open CV1
description: ''
triggers:
  - trigger: switch.turned_on
    target:
      entity_id:
        - input_boolean.field_a_line_1
        - input_boolean.field_a_line_2
        - input_boolean.field_a_line_3
        - input_boolean.field_a_line_4
    options:
      behavior: each
      for: '00:00:00'
conditions:
  - condition: valve.is_closed
    target:
      entity_id: valve.pump_monitor_valve_1
    options:
      behavior: any
      for: '00:00:00'
actions:
  - action: valve.set_valve_position
    metadata: {}
    target:
      entity_id: valve.pump_monitor_valve_1
    data:
      position: 25
mode: single
```

NOTE: it only does CV1 bc I was struggling to use PID control or just open CV2 to 25% (which I think is the right call).

When the other lines are running (opened by hand) -> the CV valves can be closed because mechanically there's no way for a valve to close "accidently".

There are lawn zones that run too:
Home Controller/Pump Controller (yaml for both are here)

I also have a shelly clamp on the pump `sensor.pump_power`:
* sensor.pump_power_pump_power
* sensor.pump_power_pump_energy
* sensor.pump_power_leg_1_current
* sensor.pump_power_leg_2_current


The goal is that pump_monitor is the sole souce of truth for:
* Which line is running and number of heads
* I want to keep track of amount of water for each line (how much water does each line accumulate/have/ran/need??)
* I want to keep track of amount of water for each lawn zone too (we'll have to look at this closer as it's not just volume/area) for every zone
* We can only run the Field A zones for 4 hours at a time due to flooding ... so we may need to run them 3 hours 2x ... for a day. Line 4 should run at night as it hits the chicken area and they are nested at night.
* What the pressure is and should be
* How much water is going to the field
* How much water is going to the pond
* How much power / cost (need cents per kWh field)
* Something is wrong: too much power, too much GPM, no GPM, etc


NOTE: If the CV1 / CV2 are open to the pond (I like the 25% each because of redundancy) then ICE should trip - a dead head is handled by the CVs

Keep track of how long a DEAD HEAD has been running ... we may put a limit on this

FUTURE: Weir control to keep the pond full
FUTURE: Field B, C, D, E with solenoid valves and lines of 7 falcon heads each


Create a new plan - new yaml - but don't flash it yet ... I need to dig the trenches for the conduit for the solenoids...


