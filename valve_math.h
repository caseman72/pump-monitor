#pragma once
// Valve position math shared by both valves and both positioning modes.
#include <cmath>

// ---- Flow % <-> ball position (fraction of full travel from the seat) ----
// Measured 2026-08-17 on a ~60 psi static supply (faucet bucket rig).
// Anchors <= 25% are solid (trickle sweep); 50-95% are provisional.
static const float VM_FLOW[]      = {0.0f,   2.0f,   5.0f,   10.0f,  15.0f,  25.0f,  50.0f, 80.0f, 95.0f, 100.0f};
static const float VM_OPEN_FRAC[] = {0.141f, 0.169f, 0.197f, 0.225f, 0.254f, 0.275f, 0.34f, 0.43f, 0.53f, 1.0f};
static const int   VM_N = 10;

// ---- Pulse positioning ----
// Counter 0 = seated. 1 = breakaway pulse (T - 15 x 0.2 s; ~water-zero).
// Each further count = +0.2 s of open travel. 16 = full open (= T).
static const float VM_PULSE_STEP_S = 0.2f;
static const int   VM_PULSE_MAX    = 16;

inline float vm_clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

inline float vm_flow_to_frac(float f) {
  f = vm_clampf(f, 0.0f, 100.0f);
  for (int i = 0; i < VM_N - 1; i++) {
    if (f <= VM_FLOW[i + 1]) {
      return VM_OPEN_FRAC[i] + (VM_OPEN_FRAC[i + 1] - VM_OPEN_FRAC[i]) * (f - VM_FLOW[i]) / (VM_FLOW[i + 1] - VM_FLOW[i]);
    }
  }
  return 1.0f;
}

inline float vm_frac_to_flow(float frac) {
  if (frac <= VM_OPEN_FRAC[0]) return 0.0f;
  if (frac >= 1.0f) return 100.0f;
  for (int i = 0; i < VM_N - 1; i++) {
    if (frac <= VM_OPEN_FRAC[i + 1]) {
      return VM_FLOW[i] + (VM_FLOW[i + 1] - VM_FLOW[i]) * (frac - VM_OPEN_FRAC[i]) / (VM_OPEN_FRAC[i + 1] - VM_OPEN_FRAC[i]);
    }
  }
  return 100.0f;
}

// Breakaway pulse length: whatever is left of full travel after 15 steps.
inline float vm_pulse_base_s(float T) { return T - (VM_PULSE_MAX - 1) * VM_PULSE_STEP_S; }

// Open travel (seconds from the seat) for a pulse counter value.
inline float vm_pulse_to_open_s(int c, float T) {
  if (c <= 0) return 0.0f;
  if (c > VM_PULSE_MAX) c = VM_PULSE_MAX;
  return vm_pulse_base_s(T) + VM_PULSE_STEP_S * (c - 1);
}

inline float vm_pulse_to_frac(int c, float T) { return vm_clampf(vm_pulse_to_open_s(c, T) / T, 0.0f, 1.0f); }

// Nearest pulse counter for a ball position (used to resync after a flow move).
inline int vm_frac_to_pulse(float frac, float T) {
  float t = vm_clampf(frac, 0.0f, 1.0f) * T;
  float base = vm_pulse_base_s(T);
  if (t < base * 0.5f) return 0;
  int c = 1 + (int) lroundf((t - base) / VM_PULSE_STEP_S);
  if (c < 1) c = 1;
  if (c > VM_PULSE_MAX) c = VM_PULSE_MAX;
  return c;
}
