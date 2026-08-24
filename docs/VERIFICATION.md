# Digital Verification

## 1. Verification Strategy

The verification methodology follows the actual project development sequence
and contains three complementary stages.

### 1.1 Pre-RTL Fixed-Point Feasibility

Before synthesizable RTL was developed, the project used:

    verification/matlab/cubic_hardware.m

as a hardware-oriented fixed-point MATLAB feasibility model.

The purpose of this model was to reproduce the expected finite-word-length
hardware behavior and verify the feasibility of the cubic interpolation
algorithm before committing to the RTL implementation.

The generated MATLAB I/Q outputs were evaluated in Keysight PathWave VSA using
the project-provided 64-QAM system reference.

This stage demonstrated acceptable signal quality before RTL development.

### 1.2 RTL Signal-Quality Validation

After the pre-RTL feasibility stage, the design was implemented in
synthesizable RTL.

The captured post-FIR RTL outputs for L=2, 3, 4 and 5 were then converted to
Keysight-compatible MAT files and evaluated using the same system-level
Keysight VSA methodology and reference.

All preserved RTL operating modes satisfy:

    EVM < 350 m%rms

The MATLAB and RTL results therefore represent two chronological system-level
validation stages.

They are not presented as a direct sample-by-sample or bit-exact
MATLAB-to-RTL comparison.

### 1.3 Downstream Digital Preservation

After the L=5 RTL implementation had already been validated at the system
level, its complete output sequence was preserved under the historical
filename:

    out/output_golden.txt

This file is a validated RTL-derived digital regression baseline.

The downstream digital regression verifies that later implementation stages
preserve the already validated RTL behavior:

    Validated L=5 RTL baseline
              |
              +----------------------+
              |                      |
              v                      v
       RTL regression          Gate-Level Simulation
              |                      |
              +----------+-----------+
                         |
                         v
                  Byte-Exact Compare

    Pad-Wrapped Gate Design
              |
              v
       Pad-Level Simulation
              |
              v
                  Byte-Exact Compare

Cadence Conformal LEC independently provides formal RTL-to-gate logical
equivalence checking.

The primary complete downstream digital regression uses L=5.


## 2. Validated RTL-Derived Regression Baseline

The file:

    out/output_golden.txt

contains the preserved validated L=5 RTL output sequence.

It is byte-identical to:

    results/verification/rtl_output_post_LPF/rtl_output_POST_LPF_L_5.txt

Both files contain:

    49,978 I/Q output samples

and share the SHA-256 digest:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

This was verified directly using both SHA-256 comparison and byte-for-byte
file comparison.

This RTL-derived regression baseline is distinct from the project-provided
64-QAM system reference used during Keysight VSA verification.

Its purpose is to verify preservation of already validated RTL behavior through
RTL regression, synthesized gate-level simulation and pad-level simulation.

## 3. RTL Functional Simulation

RTL simulation is executed using Synopsys VCS.

The simulation runner is:

    RTL/run_sim.tcsh

The testbench is:

    RTL/tb_asic.sv

The RTL compilation includes the synthesizable modules under `RTL/` and executes
the selected interpolation configuration using the corresponding serial I/Q
input vectors.

The simulation sequence is:

    reset
      |
      v
    configuration header
      |
      v
    wait for run_en
      |
      v
    serial I/Q streaming
      |
      v
    cubic interpolation
      |
      v
    P2S scheduling
      |
      v
    FIR filtering
      |
      v
    output_valid monitoring
      |
      v
    output file generation

For L=5, the RTL result is written to:

    out/rtl_output_POST_LPF_L_5.txt


## 4. RTL Regression Against the Validated Baseline

A fresh L=5 RTL regression output was compared directly against the preserved
validated RTL baseline using a byte-for-byte file comparison.

The compared files are:

    out/rtl_output_POST_LPF_L_5.txt
    out/output_golden.txt

Both files contain:

    49,978 lines

The exact comparison result is:

    RTL regression vs baseline: PASS

The two files also produce the same SHA-256 digest:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

This confirms exact agreement over the complete captured L=5 output sequence.


## 5. Gate-Level Simulation

After logic synthesis, the synthesized standard-cell netlist is subjected to
gate-level functional simulation.

The gate-level simulation runner is:

    GLS/run_gls.tcsh

The simulation uses Synopsys VCS together with the synthesized netlist and the
technology simulation models.

The canonical synthesized GLS is a functional gate-level simulation. No SDF
back-annotation is applied in this stage.

The purpose of this stage is to verify that the synthesized gate-level
representation preserves the observable functionality of the RTL under the same
input stimulus.

For the L=5 regression, the generated result is:

    GLS/work/GLS_with_chanis_rtl_output_POST_LPF_L_5.txt


## 6. Gate-Level Regression Against the Validated RTL Baseline

The complete synthesized gate-level output was compared against the same
validated RTL-derived regression baseline.

Both files contain:

    49,978 lines

The exact comparison result is:

    Gate-Level Simulation vs RTL baseline: PASS

The gate-level output and validated RTL baseline also have the identical SHA-256
digest:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

Therefore, the synthesized implementation preserves the complete observed
L=5 output sequence used by the regression.


## 7. Logical Equivalence Checking

Simulation verifies selected dynamic behavior, while Logical Equivalence
Checking provides a complementary formal comparison between the RTL and
synthesized gate-level representations.

Cadence Conformal LEC is used for hierarchical equivalence checking.

The repository contains the LEC environment under:

    lec_rvg/

The execution wrapper is:

    lec_rvg/run_lec.tcsh

and the hierarchical comparison procedure is implemented in:

    lec_rvg/scripts/hier.do


## 8. Validated LEC Result

The validated hierarchical LEC result is available in:

    results/lec/LEC_SUMMARY.txt

The final equivalence result is:

| Metric | Result |
|---|---:|
| Module pairs processed | 12 / 12 |
| Equivalent | 12 |
| Non-equivalent | 0 |
| Abort | 0 |
| Hierarchical result | Equivalent |

The report concludes:

    Processed 12 out of 12 module pairs
    EQ: 12
    NEQ: 0
    ABORT: 0

and:

    Hierarchical compare : Equivalent

This provides formal evidence that the compared synthesized hierarchy is
logically equivalent to the RTL representation.


## 9. Complementary Role of Simulation and LEC

Gate-level simulation and formal equivalence checking address different
verification objectives.

Gate-level simulation confirms that the synthesized design produces the expected
sample sequence under representative application stimulus.

LEC verifies logical correspondence between the RTL and synthesized
representations without relying only on the finite set of simulation vectors.

Together, these checks provide both dynamic and formal verification of the
synthesis transition.


## 10. Pad-Level Integration Simulation

Following synthesis, the core is integrated with the pad-level top structure.

The pad-level simulation environment is located under:

    gentop/

The execution runner is:

    gentop/run_pads.tcsh

The simulation compiles the pad-integrated top-level representation together
with the real TSMC 28 nm I/O Verilog model and executes the same functional I/Q
stimulus flow. `pad_sim_stubs.v` supplies only the mechanical `PCORNER_G` cell,
which has no functional signal behavior.

The pad-level functional simulation is executed in zero-delay mode, focusing on
logical connectivity and preservation of the functional signal path through the
pad-integrated hierarchy.


## 11. Pad-Level Regression Against the Validated RTL Baseline

For the L=5 regression, the pad-level output is:

    gentop/work/rtl_output_POST_LPF_L_5.txt

The output contains:

    49,978 lines

The exact comparison result is:

    Pad-Level GLS vs RTL baseline: PASS

The pad-level output produces the same SHA-256 digest as the RTL baseline,
RTL regression and core gate-level results:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

This confirms preservation of the complete captured functional output sequence
through the pad-integrated simulation hierarchy.


## 12. Cross-Level Regression Result

The primary L=5 regression provides a direct comparison across four output
representations:

| Representation | Lines | Baseline Comparison |
|---|---:|---|
| Validated RTL baseline | 49,978 | Reference |
| RTL simulation | 49,978 | PASS |
| Synthesized GLS | 49,978 | PASS |
| Pad-level GLS | 49,978 | PASS |

All four files share the same SHA-256 digest:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

The result demonstrates exact byte-level consistency across the verified digital
implementation stages.


## 13. Verification Flow Commands

The main repository targets associated with digital verification are:

    make sim
    make gls
    make lec
    make gls_pads

The default interpolation configuration is L=5.

The RTL and gate-level runners also support selection of the other implemented
interpolation factors through the project `L` parameter and corresponding input
vector files.


## 14. Verification Artifacts

The primary verification-related source files are:

| Path | Purpose |
|---|---|
| `RTL/tb_asic.sv` | RTL stimulus and output capture |
| `RTL/run_sim.tcsh` | RTL simulation runner |
| `GLS/tb_asic.sv` | Gate-level testbench |
| `GLS/run_gls.tcsh` | Gate-level simulation runner |
| `gentop/tb_asic.sv` | Pad-level simulation testbench |
| `gentop/run_pads.tcsh` | Pad-level simulation runner |
| `lec_rvg/run_lec.tcsh` | Conformal LEC runner |
| `lec_rvg/scripts/hier.do` | Hierarchical LEC procedure |
| `out/output_golden.txt` | Validated RTL-derived L=5 regression baseline |
| `results/lec/LEC_SUMMARY.txt` | RTL-to-final-gate formal equivalence summary |
| `synthesis_standard_verify/scripts/synthesis_standard.tcl` | Isolated standard-compile synthesis verification flow |
| `synthesis_standard_verify/dataout/ASIC_Top_netlist.v` | Standard-compile gate netlist used for gate-to-gate LEC |
| `lec_standard_vs_ultra/scripts/hier_standard_vs_ultra.do` | Standard-vs-ultra hierarchical LEC procedure |
| `lec_standard_vs_ultra/run_lec_standard_vs_ultra.tcsh` | Standard-vs-ultra Conformal runner |
| `results/lec/LEC_STANDARD_VS_ULTRA_SUMMARY.txt` | Standard-vs-ultra curated equivalence result |
| `results/lec/LEC_STANDARD_VS_ULTRA_FULL_LOG.txt` | Preserved final standard-vs-ultra Conformal log |
| `results/verification/digital_verification_summary.txt` | Curated digital regression summary |
| `verification/matlab/cubic_hardware.m` | Configurable MATLAB fixed-point verification model |
| `verification/keysight/float_iq_to_vsa.m` | Floating-point I/Q to Keysight VSA MAT converter |
| `verification/keysight/hex_iq_to_vsa.m` | RTL hexadecimal I/Q to Keysight VSA MAT converter |
| `results/verification/keysight_vsa_summary.txt` | Keysight VSA signal-quality summary |
| `results/verification/matlab/` | MATLAB pre/post-FIR VSA screenshots |
| `results/verification/rtl/` | RTL post-FIR VSA screenshots |
| `results/verification/matlab_results/` | Preserved MATLAB numeric result files |
| `results/verification/rtl_output_post_LPF/` | Preserved RTL post-FIR numeric outputs |


## 15. Verification Coverage in the Current Repository

The current repository documents and preserves evidence for:

- RTL functional simulation;
- exact RTL-regression-to-baseline comparison;
- synthesized gate-level functional simulation;
- exact gate-level-to-RTL-baseline comparison;
- hierarchical RTL-to-gate logical equivalence;
- pad-integrated functional simulation;
- exact pad-level-to-RTL-baseline comparison;
- MATLAB floating-point and fixed-point signal-processing references;
- MATLAB pre-FIR and post-FIR Keysight VSA measurements for L=2..5;
- RTL post-FIR Keysight VSA measurements for L=2..5;
- preserved numeric MATLAB and RTL result files for all four interpolation factors.

The complete L=5 regression provides a 49,978-sample end-to-end digital
comparison across the validated RTL baseline, RTL regression, synthesized
gate-level and pad-level implementations.


## 16. Digital Verification Summary

The verified digital implementation demonstrates consistency across the major
front-end representation changes.

For the primary L=5 regression:

    RTL vs RTL baseline  : PASS
    GLS vs RTL baseline  : PASS
    Pad GLS vs RTL baseline : PASS

All compared output files contain 49,978 samples and are byte-identical.

Formal equivalence checking additionally reports:

    12 / 12 module pairs equivalent
    NEQ   = 0
    ABORT = 0

The combined simulation and formal results establish the functional consistency
of the digital implementation through synthesis and pad-level integration.


## 17. MATLAB and Keysight VSA Signal-Quality Verification

Keysight PathWave VSA verification was performed at two chronological stages
of the project.

The first stage occurred before RTL development and was used to establish
fixed-point algorithm feasibility.

The second stage occurred after RTL implementation and verified the
communication-signal quality of the implemented hardware datapath.

### 17.1 Pre-RTL Hardware-Oriented MATLAB Model

Before RTL implementation:

    verification/matlab/cubic_hardware.m

was used as a hardware-oriented fixed-point feasibility model.

The model supports:

    L = 2, 3, 4, 5

and processes a 60 MS/s 64-QAM input signal.

The fixed-point interpolation datapath uses signed 16-bit signal
representation with 14 fractional bits.

Interior interpolation uses Catmull-Rom cubic interpolation, while the sequence
edges use the implemented quadratic edge treatment.

The MATLAB feasibility model also contains a 64-tap fixed-point low-pass FIR
with normalized cutoff 1/L.

The generated MATLAB I/Q outputs were converted to Keysight-compatible MAT
files and evaluated using the project-provided 64-QAM system reference.

This was the pre-RTL feasibility checkpoint.

Only after this stage demonstrated acceptable signal quality was the design
implemented in synthesizable RTL.

### 17.2 RTL Signal-Quality Validation

After RTL implementation, the captured post-FIR RTL results were converted
using:

    verification/keysight/hex_iq_to_vsa.m

and evaluated using the same system-level Keysight VSA methodology and
project-provided reference.

The output sampling rates are:

| L | Output Sample Rate |
|---:|---:|
| 2 | 120 MS/s |
| 3 | 180 MS/s |
| 4 | 240 MS/s |
| 5 | 300 MS/s |

All four preserved RTL operating modes satisfy the project requirement:

    EVM < 350 m%rms

### 17.3 MATLAB and RTL FIR Difference

The pre-RTL MATLAB feasibility model and final RTL use different FIR
implementations:

    MATLAB fixed-point FIR : 64 taps
    RTL hardware FIR       : 10 taps, symmetric, L-dependent coefficient bank

Therefore, the MATLAB post-FIR and RTL post-FIR sample sequences are not
expected to be bit-exact equivalents.

The MATLAB and RTL result sets should be interpreted as two chronological
system-level validation stages rather than as a direct MATLAB-to-RTL
sample-by-sample comparison.

### 17.4 Reference Terminology

Two different references appear in the complete project verification flow.

#### Keysight System Reference

The project-provided 64-QAM system reference was used during Keysight VSA
verification.

It was used first for the pre-RTL MATLAB feasibility model and later for the
RTL signal-quality verification.

#### RTL-Derived Digital Regression Baseline

The file:

    out/output_golden.txt

belongs to the later downstream digital-regression stage.

It is the preserved validated L=5 RTL output
sequence.

It is byte-identical to:

    results/verification/rtl_output_post_LPF/rtl_output_POST_LPF_L_5.txt

This RTL-derived baseline is used to verify preservation through RTL regression,
synthesized GLS and pad-level GLS.

The Keysight system reference and `out/output_golden.txt` are therefore
different references serving different verification purposes.

### 17.5 Representative EVM Measurements

Keysight VSA reports EVM continuously during analysis, so the displayed value
can vary slightly with the active measurement interval and analyzer state.

The preserved screenshots are treated as representative captured measurements.

| L | MATLAB pre-FIR | MATLAB post-FIR | RTL post-FIR |
|---:|---:|---:|---:|
| 2 | 223.44 m%rms | 215.39 m%rms | 217.53 m%rms |
| 3 | 192.98 m%rms | 196.82 m%rms | 177.20 m%rms |
| 4 | 201.39 m%rms | 227.29 m%rms | 176.42 m%rms |
| 5 | 221.91 m%rms | 228.30 m%rms | 267.23 m%rms |

The project requirement is:

    EVM < 350 m%rms

The preserved pre-RTL MATLAB measurements established acceptable fixed-point
signal quality before RTL development.

The later RTL measurements demonstrate that every implemented interpolation
mode also satisfies the required system-level EVM target.

Representative captured RTL EVM spans approximately:

    176-267 m%rms

### 17.6 Preserved VSA Evidence

Pre-RTL MATLAB VSA screenshots:

    results/verification/matlab/pre_filter/
    results/verification/matlab/post_filter/

MATLAB numeric results:

    results/verification/matlab_results/

RTL VSA screenshots:

    results/verification/rtl/

RTL post-FIR numeric outputs:

    results/verification/rtl_output_post_LPF/

Detailed VSA interpretation:

    results/verification/keysight_vsa_summary.txt

VSA conversion utilities:

    verification/keysight/float_iq_to_vsa.m
    verification/keysight/hex_iq_to_vsa.m

The preserved L=5 RTL output contains 49,978 samples and is byte-identical to
the later digital regression baseline `out/output_golden.txt`.

## 18. Standard-Compile vs Compile-Ultra Gate-to-Gate LEC

A separate gate-to-gate equivalence experiment evaluates whether the synthesis
optimization strategy changes the functional behavior of the design.

The Golden implementation is generated using:

    compile -gate_clock

The Revised implementation is the final synthesis implementation generated
using:

    compile_ultra -gate_clock

The two synthesis scripts otherwise use the same current RTL, constraints,
technology setup, clock-gating setup and scan flow. A direct script comparison
shows that the compilation command is the only functional difference.

The comparison is performed in functional scan mode:

    scan_en  = 0
    scan_in1 = 0
    scan_in2 = 0
    scan_in3 = 0

The scan outputs are excluded from the functional comparison.

Because standard compile and compile_ultra can generate substantially different
internal structures, this comparison uses:

    set analyze option -auto
    set compare effort high

The final hierarchical result is:

| Metric | Result |
|---|---:|
| Module pairs processed | 5 / 5 |
| Equivalent | 5 |
| Non-equivalent | 0 |
| Abort | 0 |
| Hierarchical comparison | Equivalent |

For the final ASIC_Top pair, Conformal compares:

| Point Type | Equivalent Points |
|---|---:|
| Primary outputs | 36 |
| DFF points | 83 |
| Black-box points | 4 |
| Total | 123 |

All 123 final top-level compared points are equivalent.

Detailed evidence is stored in:

    results/lec/LEC_STANDARD_VS_ULTRA_SUMMARY.txt
    results/lec/LEC_STANDARD_VS_ULTRA_FULL_LOG.txt
