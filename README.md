# CUBIC Interpolation DSP ASIC — TSMC 28 nm

ASIC implementation of a configurable cubic-interpolation DSP chain for
complex I/Q baseband samples, implemented and verified through an
RTL-to-post-layout flow in TSMC 28 nm technology.

The design accepts bit-serial I/Q input samples, reconstructs signed input
words, performs configurable cubic interpolation, schedules the interpolated
sample stream, applies an L-dependent 10-tap FIR low-pass filter, and produces
aligned signed 16-bit I/Q outputs with `output_valid`.

---

## Documentation

For a compact view of the final implementation metrics, start with
[Final Results](docs/RESULTS.md).

For reproducing the implementation flow, see
[Reproducing the Implementation Flow](docs/REPRODUCING.md).

Detailed documentation is organized as follows:

| Document | Contents |
|---|---|
| [System Architecture](docs/SYSTEM_ARCHITECTURE.md) | System-level DSP architecture, operating modes and rates |
| [RTL Architecture](docs/RTL_ARCHITECTURE.md) | Detailed synthesizable RTL and fixed-point implementation |
| [Digital Verification](docs/VERIFICATION.md) | RTL, GLS, pad-level regression, LEC and MATLAB/Keysight VSA verification |
| [Logic Synthesis](docs/SYNTHESIS.md) | Design Compiler flow, constraints, area, clock gating and scan |
| [Physical Design](docs/PHYSICAL_DESIGN.md) | Floorplan, PG, placement, CTS, routing and final ECO closure |
| [Static Timing Analysis](docs/STATIC_TIMING_ANALYSIS.md) | Final PrimeTime setup/hold matrix |
| [Power Analysis](docs/POWER_ANALYSIS.md) | SAIF-based post-route power and L5 core-domain IR/rail analysis |
| [Final Results](docs/RESULTS.md) | Consolidated final numerical results |
| [Reproducing the Flow](docs/REPRODUCING.md) | Makefile execution sequence and reproduction instructions |

---

## Project Overview

The implemented per-channel signal-processing chain is:

    Bit-Serial I/Q Input
            |
            v
           SIPO
            |
            v
     Cubic Interpolator
            |
            v
     P2S Sample Scheduler
            |
            v
     10-Tap FIR Low-Pass Filter
            |
            v
    Signed 16-Bit I/Q Output

A shared control unit coordinates the interpolation factor, serial word mode and
sample timing for both the I and Q channels.

The supported operating modes are:

| L | Input Word | Functional Clock | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| 2 | 16 bits | 960 MHz | 60 MS/s | 120 MS/s |
| 3 | 15 bits | 900 MHz | 60 MS/s | 180 MS/s |
| 4 | 16 bits | 960 MHz | 60 MS/s | 240 MS/s |
| 5 | 15 bits | 900 MHz | 60 MS/s | 300 MS/s |

`L = 5` is used as the primary complete digital regression case.

---

## RTL Architecture

The main RTL modules are:

| Module | Function |
|---|---|
| `ASIC_Top` | Top-level integration of the complete DSP |
| `Control_Unit` | Shared control and interpolation-rate timing |
| `MinAJ2_Datapath` | I/Q datapath wrapper |
| `SIPO` | Serial-to-parallel sample collection |
| `Interpolator` | Four-sample cubic interpolation datapath |
| `FIR_LPF_TRANSPOSED` | 10-tap symmetric transposed FIR filter |
| `P2S_Interpolator` | Time scheduling of parallel interpolation results |

The cubic interpolator operates on four neighboring samples and generates
intermediate samples according to the selected interpolation factor.

---

## Verification

Verification was performed at several abstraction levels.

### RTL Simulation

RTL simulation was performed with Synopsys VCS using the project streaming
testbench and input vectors.

For the main `L = 5` case, the RTL output contains **49,978 samples** and
matches the project golden output byte-for-byte.

### Gate-Level Simulation

The synthesized TSMC 28 nm gate-level netlist was simulated using the same
stimulus and compared against the golden reference. This is a functional
post-synthesis gate-level simulation; no SDF back-annotation is applied.

The gate-level output matches the RTL/golden output.

### Pad-Level Gate Simulation

The pad-integrated chip-level netlist was also simulated using the same L=5
stimulus. The padded simulation runs in zero-delay mode using the real TSMC
28 nm I/O Verilog model; only the mechanical `PCORNER_G` cell is represented
by a simulation stub. Its complete 49,978-sample output is byte-identical to
the canonical golden reference.

### Logic Equivalence Checking

Cadence Conformal LEC was used for hierarchical RTL-to-gate-netlist
equivalence verification.

Validated hierarchical comparison results:

```text
Equivalent module pairs : 12 / 12
Non-equivalent          : 0
Abort                   : 0
```

The LEC setup and runner are provided under `lec_rvg/`.

### Standard-Compile vs Compile-Ultra Equivalence

An additional gate-to-gate Conformal comparison was performed between a
current-project standard `compile -gate_clock` implementation and the final
`compile_ultra -gate_clock` synthesis implementation.

The two synthesis verification scripts differ only in the compilation command.
The functional comparison disables scan operation and uses:

    set analyze option -auto
    set compare effort high

Final hierarchical result:

    Equivalent module pairs : 5 / 5
    Non-equivalent          : 0
    Abort                   : 0

This demonstrates that the two synthesis optimization strategies preserve the
same functional behavior under the documented functional scan constraints.

The isolated standard-compile flow is under `synthesis_standard_verify/`, and
the gate-to-gate LEC flow is under `lec_standard_vs_ultra/`.

### MATLAB and Keysight VSA Signal-Quality Verification

System-level 64-QAM signal quality was also evaluated using the MATLAB
fixed-point model and Keysight PathWave Vector Signal Analysis (VSA).

The same underlying 60 MS/s I/Q stimulus was used for the preserved
L=2, 3, 4 and 5 evaluations.

The MATLAB algorithmic reference uses a 64-tap FIR, while the final RTL uses a
10-tap symmetric L-dependent hardware FIR. The MATLAB and RTL post-filter
signals are therefore compared at the system-signal-quality level and are not
claimed to be bit-exact equivalent.

Keysight VSA reports EVM continuously, so the displayed value can vary slightly
with the active measurement interval and analyzer state. Representative
captured RTL readings are approximately:

| L | Representative RTL EVM |
|---:|---:|
| 2 | ~218 m%rms |
| 3 | ~177 m%rms |
| 4 | ~176 m%rms |
| 5 | ~267 m%rms |

Across the preserved measurements, the RTL EVM is approximately
**176-267 m%rms**, below the project requirement of **350 m%rms** for every
supported interpolation factor.

The preserved screenshots and detailed interpretation are available under
`results/verification/`, and the conversion utilities are under
`verification/keysight/`.

---

## Synthesis

Logic synthesis was performed using Synopsys Design Compiler Ultra.

Key implementation constraints:

- Clock period: **1.04 ns**
- Clock uncertainty: **0.05 ns**
- Input maximum delay: **0.20 ns**
- Interpolator multicycle path: **14 setup / 13 hold**
- FIR multicycle path: **3 setup / 2 hold**
- Clock-gating optimization enabled

The post-scan synthesized implementation contains **38,841 cells** with a
reported total cell area of **38,733.029556** library area units.

---
## Physical Design

Physical implementation was performed using Cadence Innovus.

### Floorplan

| Parameter | Value |
|---|---:|
| Technology | TSMC 28 nm |
| Die size | 880 × 880 µm |
| Core size | 560 × 560 µm |
| Final placement density | 12.419% |
| Clock period | 1.04 ns |

Final CCOpt clock-tree metrics are:

| Clock-Tree Metric | Result |
|---|---:|
| Clock-tree sinks | 1,138 |
| Clock gates | 6 |
| Clock buffers | 17 |
| Clock inverters | 0 |
| SlowDC setup skew | **16 ps** |
| FastDC hold skew | **13 ps** |
| SlowDC setup-late skew target | 23 ps |

The complete measured CCOpt report is available at
`results/innovus/final_cts_ccopt.rpt`.

The backend implementation flow is:

```text
Synthesized Netlist
        |
        v
Pad Integration
        |
        v
Floorplanning
        |
        v
Placement
        |
        v
Clock Tree Synthesis
        |
        v
Routing
        |
        v
Post-route ECO
        |
        v
Physical Verification
        |
        v
PrimeTime STA
```

Post-route ECO optimization was used to close hold timing, clock-gating
timing, and the scan-enable distribution network.

---

## Final Innovus Results

The final physical implementation passes the post-route physical and timing
checks.

| Check | Final Result |
|---|---:|
| Connectivity | **PASS** |
| DRC violations | **0** |
| Max capacitance violations | **0** |
| Max transition violations | **0** |
| Max fanout violations | **0** |
| Max length violations | **0** |
| Setup WNS | **+0.122 ns** |
| Hold WNS | **+0.001 ns** |

---

## PrimeTime Static Timing Analysis

Final STA was performed using Synopsys PrimeTime on the post-route netlist
with extracted SPEF parasitics and corner-specific timing libraries.

### Setup Timing

| Corner | WNS | Violating Paths |
|---|---:|---:|
| Slow | **+0.092604 ns** | 0 |
| Typical | **+0.327260 ns** | 0 |
| Fast | **+0.360641 ns** | 0 |

### Functional Data Hold Timing

| Corner | WNS | Violating Paths |
|---|---:|---:|
| Slow | **+0.022842 ns** | 0 |
| Typical | **+0.010245 ns** | 0 |
| Fast | **+0.000004 ns** | 0 |

### Clock-Gating Hold Timing

| Corner | WNS | Violating Paths |
|---|---:|---:|
| Slow | **+0.058417 ns** | 0 |
| Typical | **+0.031253 ns** | 0 |
| Fast | **+0.010128 ns** | 0 |

### Asynchronous Hold Timing

| Corner | WNS | Violating Paths |
|---|---:|---:|
| Slow | **+0.042381 ns** | 0 |
| Typical | **+0.026578 ns** | 0 |
| Fast | **+0.009833 ns** | 0 |

All setup, functional data-hold, clock-gating, and asynchronous timing checks
are non-negative across the analyzed slow, typical and fast corners. The final
fast-corner overall hold WNS is **+0.000004 ns**, with zero negative paths.

The final PrimeTime flow uses a **0.06 ns** minimum external reset input-delay
assumption at `I6/I1/C`.

Detailed timing interpretation is available in
[Static Timing Analysis](docs/STATIC_TIMING_ANALYSIS.md).

The compact final STA report is available at:

```text
results/primetime/final_sta_summary.txt
```

---
## Area and Power Results

### Synthesis Area

Synopsys Design Compiler reports the following standard-cell area:

| Stage | Total Cell Area |
|---|---:|
| Post-compile | **38,701.025551** |
| Post-scan | **38,733.029556** |

The complete synthesis reports and the compact area summary are stored in `results/synthesis/`.

### Final Post-Route Power

Final post-route power was evaluated on the completed physical implementation
using per-L SAIF switching activity captured from gate-level simulation.

The analysis uses the SlowView corner (SS, 0.81 V, 125 C, SlowRC/cworst).
The final reports show **98.287926% SAIF annotation coverage**.

| Interpolation Factor | Chip Power | Core Power |
|---|---:|---:|
| L=2 | 22.9837 mW | 4.3920 mW |
| L=3 | 28.8508 mW | 5.0040 mW |
| L=4 | 34.9646 mW | 5.7110 mW |
| L=5 | **40.3975 mW** | **6.2380 mW** |

For the primary L=5 case:

| Component | Power |
|---|---:|
| Internal | **26.6504 mW** |
| Switching | **11.6612 mW** |
| Leakage | **2.0859 mW** |
| Total chip | **40.3975 mW** |

The complete per-L and per-block final power reports are stored in
`results/power/final_iter4b/`.

Detailed methodology and interpretation are available in
[Power Analysis](docs/POWER_ANALYSIS.md).

### Final L=5 Core-Domain IR Drop

Static rail analysis was also performed on the final routed implementation using
the L=5 gate-level SAIF activity and the SlowView SS 0.81 V, 125 C / cworst
analysis condition.

| Metric | Final Result |
|---|---:|
| Minimum VDDC node voltage | **~0.807 V** |
| Worst VDDC drop | **~3.00 mV** |
| Maximum VSSC bounce | **~2.55 mV** |
| Minimum effective instance voltage | **~0.805 V** |
| Voltage-threshold violations | **0** |
| Current taps matched | **39,509 / 39,509 (100%)** |
| Dropped voltage sources | **0** |
| Voltus solver errors | **0** |

The analysis covers the DSP-core VDDC/VSSC domain using the documented
28 nm tech-only PGV model at the stated L=5 SlowView condition.

Detailed rail-analysis methodology and integrity reports are provided in
[Power Analysis](docs/POWER_ANALYSIS.md) and under `results/innovus/`.

---

## Repository Structure

```text
.
├── RTL/                 RTL design and testbench
├── GLS/                 gate-level simulation environment
├── GL_sim_saif/         switching-activity simulation
├── synthesis/           Design Compiler synthesis flow
├── lec_rvg/             Cadence Conformal LEC flow
├── gentop/              pad integration and verification
├── innovus/             Innovus physical-design flow
├── primetime/           PrimeTime STA flow
├── docs/                detailed architecture and implementation documentation
├── results/             curated final implementation results
├── in/                  simulation input vectors
├── build.cud            RTL VCS compilation file
├── build_gls.cud        gate-level VCS compilation file
└── Makefile             project flow entry points
```

Large generated tool databases, simulation waveforms, foundry libraries,
SPEFs, and temporary work directories are intentionally excluded from the
repository.

---

## Main Tools

| Stage | Tool |
|---|---|
| RTL / Gate Simulation | Synopsys VCS |
| Logic Synthesis | Synopsys Design Compiler Ultra |
| Logic Equivalence | Cadence Conformal LEC |
| Place & Route | Cadence Innovus |
| Power / Rail Analysis | Cadence Innovus / Voltus |
| Static Timing Analysis | Synopsys PrimeTime |

Technology: **TSMC 28 nm**

---

## Final Implementation Status

| Stage / Check | Status |
|---|---|
| RTL simulation | PASS |
| Gate-level simulation | PASS |
| Pad-level simulation | PASS |
| RTL-to-gate logic equivalence | PASS - 12 / 12 equivalent |
| Standard-vs-ultra gate-level equivalence | PASS - 5 / 5 equivalent, NEQ=0, ABORT=0 |
| Keysight VSA EVM, L=2..5 | PASS - representative captured RTL EVM ~176-267 m%rms, requirement <350 m%rms |
| Synthesis | COMPLETE |
| Placement and routing | COMPLETE |
| Post-route connectivity | PASS |
| Post-route DRC | PASS |
| Post-route electrical DRVs | PASS |
| PrimeTime synchronous setup | PASS |
| PrimeTime functional data hold | PASS |
| PrimeTime clock-gating timing | PASS |
| PrimeTime asynchronous timing | PASS |
| SAIF power characterization L=2..5 | COMPLETE |
| L5 core-domain IR / rail analysis | PASS (core-domain) |

The final PrimeTime matrix is clean across all analyzed setup and hold
conditions, with zero negative paths in all six corner/mode runs.

The repository documents the implementation through final routed physical
design, SAIF-based post-route power characterization, project-level L5
core-domain IR/rail analysis, and extracted PrimeTime static timing analysis.
