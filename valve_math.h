#pragma once
// Valve pulse-position math shared by both valves.
#include <cmath>

// ---- Pulse positioning ----
// Counter 0 = seated. 1 = breakaway pulse (T - 15 x 0.2 s; ~water-zero).
// Each further count = +0.2 s of open travel. 16 = full open (= T).
// (The 2026-08-17 flow-vs-ball-position table lives in README.md as
// reference only; the firmware positions purely by pulse count.)
static const float VM_PULSE_STEP_S = 0.2f;
static const int   VM_PULSE_MAX    = 16;

inline float vm_clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

// Breakaway pulse length: whatever is left of full travel after 15 steps.
inline float vm_pulse_base_s(float T) { return T - (VM_PULSE_MAX - 1) * VM_PULSE_STEP_S; }

// Open travel (seconds from the seat) for a pulse counter value.
inline float vm_pulse_to_open_s(int c, float T) {
  if (c <= 0) return 0.0f;
  if (c > VM_PULSE_MAX) c = VM_PULSE_MAX;
  return vm_pulse_base_s(T) + VM_PULSE_STEP_S * (c - 1);
}
