# Final Results

## 1. Overview

This document consolidates the principal verified implementation results of the
CUBIC Interpolation DSP ASIC.

Detailed methodology and complete reports are available in the dedicated
architecture, verification, synthesis, physical-design, timing and power
documents.

The implementation targets a fully padded TSMC 28 nm ASIC and supports:

| Interpolation Factor | Input Word | Functional Clock | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| L=2 | 16 bits | 960 MHz | 60 MS/s | 120 MS/s |
| L=3 | 15 bits | 900 MHz | 60 MS/s | 180 MS/s |
| L=4 | 16 bits | 960 MHz | 60 MS/s | 240 MS/s |
| L=5 | 15 bits | 900 MHz | 60 MS/s | 300 MS/s |

Implementation timing is constrained with a:

    1.04 ns clock period

corresponding to approximately:

    961.5 MHz


## 2. Digital Functional Verification

The primary complete regression uses the L=5 operating configuration.

The canonical output contains:

    49,978 complex I/Q output samples

The following representations were compared against the same golden reference:

| Representation | Samples | Result |
|---|---:|---|
| RTL simulation | 49,978 | PASS |
| Synthesized gate-level simulation | 49,978 | PASS |
| Pad-level gate simulation | 49,978 | PASS |

All four files, including the golden reference, are byte-identical.

Their common SHA-256 digest is:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693


### System-Level MATLAB / Keysight VSA Verification

Keysight VSA was used to evaluate representative 64-QAM EVM for the MATLAB
reference processing chain and the final RTL processing chain.

The displayed VSA EVM is a live analyzer measurement, so the preserved values
are treated as representative captured readings rather than fixed constants.

| L | MATLAB post-FIR EVM | RTL post-FIR EVM | RTL Requirement |
|---:|---:|---:|---|
| 2 | ~215 m%rms | ~218 m%rms | PASS |
| 3 | ~197 m%rms | ~177 m%rms | PASS |
| 4 | ~227 m%rms | ~176 m%rms | PASS |
| 5 | ~228 m%rms | ~267 m%rms | PASS |

Across the preserved screenshots, representative RTL EVM is approximately
176-267 m%rms. All captured RTL modes satisfy the project requirement:

    EVM < 350 m%rms

The MATLAB reference uses a 64-tap FIR, while the final RTL uses a 10-tap
symmetric L-dependent FIR. These measurements therefore compare complete
signal-processing-chain quality rather than bit-exact post-filter equivalence.

Detailed evidence is available in:

    results/verification/keysight_vsa_summary.txt


## 3. Logical Equivalence

Hierarchical RTL-to-gate equivalence checking reports:

| Metric | Result |
|---|---:|
| Module pairs processed | 12 / 12 |
| Equivalent | 12 |
| Non-equivalent | 0 |
| Abort | 0 |
| Hierarchical comparison | Equivalent |

The synthesis transformation is therefore formally equivalent for the validated
hierarchical comparison.


## 4. Logic Synthesis

The final mapped implementation uses the TSMC 28 nm HPC+ standard-cell library.

Post-scan synthesis results are:

| Metric | Result |
|---|---:|
| Standard-cell count | 38,841 |
| Total cell area | 38,733.029556 |
| Reported setup slack | +0.05 ns |
| Reported hold slack | +0.00 ns |
| Clock-gating structures | 7 |
| Scan chains | 3 |
| Scan cells | 42 |

The pre-layout Design Compiler power estimate is approximately:

    2.0881 mW

This value is an early synthesis estimate and is separate from the final
post-route SAIF-based power characterization.


## 5. Physical Implementation

The final Cadence Innovus floorplan is:

| Physical Metric | Result |
|---|---:|
| Die | 880 x 880 um |
| Core | 560 x 560 um |
| Standard-cell density | 12.419% |
| Density including fillers | 96.411% |

The core power-distribution network uses:

    M8 / M9 core ring and stripe network

with separate core and pad power domains.


## 6. Clock Tree

The implemented functional clock tree contains:

| Metric | Result |
|---|---:|
| Clock sources | 1 |
| Clock-tree sinks | 1,138 |
| Constrained skew-group sinks | 1,132 |
| Unconstrained skew-group sinks | 6 |
| Clock gates | 6 |
| Clock buffers | 17 |
| Clock inverters | 0 |
| Buffering depth | 2 - 3 |
| Clock period | 1.04 ns |
| SlowDC setup skew | **16 ps** |
| FastDC hold skew | **13 ps** |
| SlowDC setup-late skew target | 23 ps |

The slow setup skew is therefore below the CCOpt-generated 23 ps target.

The worst slow-corner leaf slew is:

    49 ps

against a target of:

    50 ps

The final CCOpt clock tree reports zero max-capacitance, max-resistance,
max-length, max-fanout and slew violations.

The complete measured clock-tree report is:

    results/innovus/final_cts_ccopt.rpt


## 7. Final Innovus Timing

Final post-route Innovus timing is:

| Check | WNS | TNS | Violations |
|---|---:|---:|---:|
| Setup | +0.122 ns | 0.000 ns | 0 |
| Hold | +0.001 ns | 0.000 ns | 0 |


## 8. Final Electrical Constraints

The completed physical implementation reports:

| Electrical Constraint | Violations |
|---|---:|
| Maximum capacitance | 0 |
| Maximum transition | 0 |
| Maximum fanout | 0 |
| Maximum length | 0 |


## 9. Physical Verification

Final Innovus physical checks report:

| Check | Result |
|---|---|
| Innovus DRC | 0 violations |
| Connectivity | PASS |
| Connectivity warnings | 0 |

The physical database used for final analysis is therefore clean under the
implemented Innovus verification flow.


## 10. PrimeTime Setup Results

Final PrimeTime setup timing is:

| Corner | Data WNS | Clock-Gating WNS | Async WNS |
|---|---:|---:|---:|
| Slow | +0.092604 ns | +0.337834 ns | +0.261252 ns |
| Typical | +0.327260 ns | +0.370334 ns | +0.377244 ns |
| Fast | +0.360641 ns | +0.396282 ns | +0.505061 ns |

Negative setup paths:

    0

across all reported timing classes and analyzed corners.


## 11. PrimeTime Hold Results

Final PrimeTime hold timing is:

| Corner | Data WNS | Clock-Gating WNS | Async WNS |
|---|---:|---:|---:|
| Slow | +0.022842 ns | +0.058417 ns | +0.042381 ns |
| Typical | +0.010245 ns | +0.031253 ns | +0.026578 ns |
| Fast | +0.000004 ns | +0.010128 ns | +0.009833 ns |

All reported hold timing classes are non-negative across the analyzed corners.

The limiting overall hold margin is:

    +0.000004 ns
    +0.004 ps

at the fast timing condition.

The final PrimeTime interface model uses a minimum external reset input-delay
assumption of:

    0.06 ns

at the physical reset pad path `I6/I1/C`.

The final hold matrix contains zero negative paths.

## 12. Final Timing Summary

Across the analyzed PrimeTime corners:

| Timing Class | Slow | Typical | Fast |
|---|---|---|---|
| Setup data | PASS | PASS | PASS |
| Setup clock gating | PASS | PASS | PASS |
| Setup async | PASS | PASS | PASS |
| Hold data | PASS | PASS | PASS |
| Hold clock gating | PASS | PASS | PASS |
| Hold async | PASS | PASS | PASS |

All six setup/hold corner analyses report zero negative paths.

The limiting overall margins are:

    Setup WNS = +0.092604 ns
    Hold WNS  = +0.000004 ns

## 13. SAIF-Based Post-Route Power

Final power is evaluated independently for each interpolation factor using
gate-level SAIF activity.

Activity annotation coverage is:

    47,764 / 48,596
    98.287926%

The resulting power is:

| L | Whole-Chip Power | DSP Core Power |
|---:|---:|---:|
| 2 | 22.9837 mW | 4.3920 mW |
| 3 | 28.8508 mW | 5.0040 mW |
| 4 | 34.9646 mW | 5.7110 mW |
| 5 | **40.3975 mW** | **6.2380 mW** |

L=5 is the highest-rate and highest-power analyzed operating configuration.


## 14. L5 Power Breakdown

The final L=5 whole-chip power is:

    40.39749739 mW

with:

| Component | Power | Percentage |
|---|---:|---:|
| Internal | 26.65038128 mW | 65.9704% |
| Switching | 11.66117741 mW | 28.8661% |
| Leakage | 2.08593870 mW | 5.1635% |

The corresponding DSP-core hierarchy consumes:

    6.2380 mW


## 15. L5 Supply-Rail Power

The final L=5 supply-rail distribution is:

| Rail | Voltage | Power | Percentage |
|---|---:|---:|---:|
| POC | 1.62 V | 23.68 mW | 58.61% |
| VDDP | 1.62 V | 9.787 mW | 24.23% |
| VDDC | 0.81 V | 6.932 mW | 17.16% |

The result demonstrates the significant contribution of the pad-integrated power
domains to the complete chip result.


## 16. L5 DSP Block Power

Selected L=5 block-level results are:

| Block | Power |
|---|---:|
| I-channel Interpolator | 1.259 mW |
| Q-channel Interpolator | 1.266 mW |
| I-channel FIR | 1.548 mW |
| Q-channel FIR | 1.552 mW |

The similar I/Q values are consistent with the structurally symmetric channel
architecture.


## 17. Final L5 Core-Domain IR Drop

The final L=5 static rail analysis reports:

| Metric | Result |
|---|---:|
| Minimum VDDC node voltage | approximately 0.807 V |
| Worst VDDC drop | approximately 3.00 mV |
| Maximum VSSC bounce | approximately 2.55 mV |
| Minimum effective instance voltage | approximately 0.805 V |
| Voltage-threshold violations | 0 |
| Current taps matched | 39,509 / 39,509 (100.00%) |
| Dropped voltage sources | 0 |
| Voltus solver warnings | 0 |
| Voltus solver errors | 0 |

No physically disconnected instance is reported inside the DSP hierarchy `I0`.
The tech-only PGV model retains disconnected pad-ring/filler/pad/corner
sections outside the core hierarchy, so the result is scoped to the project-level
VDDC/VSSC core-domain analysis.

The detailed interpretation is available in:

    results/innovus/final_ir_drop_summary.txt


## 18. Final Implementation Snapshot

The principal final project results are:

| Category | Final Result |
|---|---|
| RTL regression | PASS, 49,978 samples byte-identical |
| Gate-level regression | PASS, 49,978 samples byte-identical |
| Pad-level regression | PASS, 49,978 samples byte-identical |
| Keysight VSA RTL EVM, L=2..5 | PASS, representative captured range ~176-267 m%rms; requirement <350 m%rms |
| LEC | 12 / 12 equivalent |
| Post-scan cells | 38,841 |
| Post-scan cell area | 38,733.029556 |
| Die | 880 x 880 um |
| Core | 560 x 560 um |
| Final SlowDC clock skew | 16 ps |
| Final FastDC clock skew | 13 ps |
| Innovus setup WNS | +0.122 ns |
| Innovus hold WNS | +0.001 ns |
| Innovus DRC | 0 |
| Innovus connectivity | PASS |
| PrimeTime limiting synchronous setup | +0.092604 ns |
| PrimeTime limiting synchronous hold | +0.000004 ns |
| L5 whole-chip power | 40.3975 mW |
| L5 DSP-core power | 6.2380 mW |
| SAIF annotation coverage | 98.287926% |
| L5 core-domain VDDC IR drop | approximately 3.00 mV |
| L5 minimum effective core voltage | approximately 0.805 V |


## 19. Detailed Evidence

Detailed supporting material is available in:

    docs/VERIFICATION.md
    docs/SYNTHESIS.md
    docs/PHYSICAL_DESIGN.md
    docs/STATIC_TIMING_ANALYSIS.md
    docs/POWER_ANALYSIS.md

Curated and full tool reports are stored under:

    results/synthesis/
    results/verification/
    results/lec/
    results/innovus/
    results/primetime/
    results/power/


## 20. Final Result Summary

The CUBIC Interpolation DSP ASIC was implemented through RTL verification,
technology mapping, fully padded physical design, activity-based post-route
power characterization, project-level core-domain rail analysis and extracted
post-layout static timing analysis.

The final implementation demonstrates:

- byte-identical RTL, gate-level and pad-level L=5 regression outputs;
- representative Keysight VSA RTL EVM below the 350 m%rms requirement for all
  preserved L=2..5 operating-mode measurements;
- validated hierarchical RTL-to-gate equivalence;
- zero final Innovus DRC and connectivity violations;
- zero final Innovus electrical design-rule violations;
- PrimeTime setup and hold closure with zero negative paths across all
  analyzed corners and timing classes;
- SAIF-based mode-dependent power characterization for L=2 through L=5;
- project-level L=5 VDDC/VSSC core-domain IR analysis with approximately
  3.00 mV worst VDDC drop and zero voltage-threshold violations.

The detailed reports in the repository provide traceable evidence for each
reported result.
