# CUBIC Interpolation DSP ASIC — TSMC 28 nm

ASIC implementation of a configurable cubic-interpolation DSP chain for
complex I/Q baseband samples, implemented and verified using a complete
RTL-to-physical-design flow in TSMC 28 nm technology.

The design performs sample-rate interpolation using a cubic interpolator,
followed by a low-pass FIR filtering stage and serialized I/Q output.

---

## Project Overview

The implemented signal-processing chain is:

```text
Serial I/Q Input
      |
      v
     SIPO
      |
      v
Cubic Interpolator
      |
      v
 Transposed FIR LPF
      |
      v
     P2S
      |
      v
Serial I/Q Output
```

A shared control unit coordinates the interpolation factor and datapath timing
for both the I and Q channels. The hardware supports interpolation factors
`L = 2..5`, with `L = 5` used as the primary backend verification case.

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
| `P2S_Interpolator` | Parallel-to-serial output scheduling |

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
stimulus and compared against the golden reference.

The gate-level output matches the RTL/golden output.

### Pad-Level Gate Simulation

The pad-integrated chip-level netlist was also simulated to verify that I/O
integration preserved functional behavior.

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

The synthesized design contains approximately **38.8k standard-cell
instances**.

---
## Physical Design

Physical implementation was performed using Cadence Innovus.

### Floorplan

| Parameter | Value |
|---|---:|
| Technology | TSMC 28 nm |
| Die size | 880 × 880 µm |
| Core size | 560 × 560 µm |
| Final placement density | ~12.4% |
| Clock period | 1.04 ns |

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

All synchronous setup, functional data-hold, and clock-gating timing checks
are closed in the final implementation.

The compact final STA report is available at:

```text
results/primetime/final_sta_summary.txt
```

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
| Static Timing Analysis | Synopsys PrimeTime |

Technology: **TSMC 28 nm**

---

## Final Implementation Status

```text
RTL simulation          PASS
Gate-level simulation   PASS
Pad-level simulation    PASS
Logic equivalence       PASS
Synthesis               PASS
Placement and routing   PASS
Post-route connectivity PASS
Post-route DRC          PASS
Post-route DRVs         PASS
PrimeTime setup         PASS
PrimeTime data hold     PASS
PrimeTime clock gating  PASS
```

The project completes the RTL-to-physical-design flow through final
post-route static timing analysis.
