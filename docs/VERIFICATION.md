# Digital Verification

## 1. Verification Strategy

The CUBIC Interpolation DSP ASIC was verified at multiple abstraction levels in
order to confirm functional consistency from the synthesizable RTL through the
gate-level and pad-integrated implementations.

The digital verification flow contains four complementary checks:

    Canonical Golden Reference
              |
              +----------------------+
              |                      |
              v                      v
       RTL Simulation          Gate-Level Simulation
              |                      |
              +----------+-----------+
                         |
                         v
                  Exact File Compare

    RTL Design
        |
        +------ Conformal LEC ------ Synthesized Netlist
        |
        v
    Hierarchical Equivalence

    Pad-Wrapped Gate Design
              |
              v
       Pad-Level Simulation
              |
              v
       Exact Golden Compare

The primary complete regression documented in this repository uses the L=5
operating configuration.


## 2. Canonical Golden Reference

The repository contains the canonical digital output reference:

    out/output_golden.txt

The reference consists of hexadecimal I/Q sample pairs representing the expected
post-interpolation and post-FIR output sequence.

For the primary L=5 regression, the reference contains:

    49,978 output samples

This file is used as the common comparison target for the RTL, synthesized
gate-level and pad-level simulations.


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


## 4. RTL-to-Golden Regression

The complete L=5 RTL output was compared directly against the canonical golden
reference using a byte-for-byte file comparison.

The compared files are:

    out/rtl_output_POST_LPF_L_5.txt
    out/output_golden.txt

Both files contain:

    49,978 lines

The exact comparison result is:

    RTL vs Golden: PASS

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


## 6. Gate-Level-to-Golden Regression

The complete synthesized gate-level output was compared against the same
canonical reference used for RTL verification.

Both files contain:

    49,978 lines

The exact comparison result is:

    Gate-Level Simulation vs Golden: PASS

The gate-level output and golden reference also have the identical SHA-256
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


## 11. Pad-Level-to-Golden Regression

For the L=5 regression, the pad-level output is:

    gentop/work/rtl_output_POST_LPF_L_5.txt

The output contains:

    49,978 lines

The exact comparison result is:

    Pad-Level GLS vs Golden: PASS

The pad-level output produces the same SHA-256 digest as the golden, RTL and
core gate-level results:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

This confirms preservation of the complete captured functional output sequence
through the pad-integrated simulation hierarchy.


## 12. Cross-Level Regression Result

The primary L=5 regression provides a direct comparison across four output
representations:

| Representation | Lines | Golden Comparison |
|---|---:|---|
| Canonical reference | 49,978 | Reference |
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
| `out/output_golden.txt` | Canonical digital output reference |
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
- exact RTL-to-golden comparison;
- synthesized gate-level functional simulation;
- exact gate-level-to-golden comparison;
- hierarchical RTL-to-gate logical equivalence;
- pad-integrated functional simulation;
- exact pad-level-to-golden comparison;
- MATLAB floating-point and fixed-point signal-processing references;
- MATLAB pre-FIR and post-FIR Keysight VSA measurements for L=2..5;
- RTL post-FIR Keysight VSA measurements for L=2..5;
- preserved numeric MATLAB and RTL result files for all four interpolation factors.

The complete L=5 regression provides a 49,978-sample end-to-end digital
comparison across the canonical reference, RTL, synthesized gate-level and
pad-level implementations.


## 16. Digital Verification Summary

The verified digital implementation demonstrates consistency across the major
front-end representation changes.

For the primary L=5 regression:

    RTL vs Golden        : PASS
    GLS vs Golden        : PASS
    Pad GLS vs Golden    : PASS

All compared output files contain 49,978 samples and are byte-identical.

Formal equivalence checking additionally reports:

    12 / 12 module pairs equivalent
    NEQ   = 0
    ABORT = 0

The combined simulation and formal results establish the functional consistency
of the digital implementation through synthesis and pad-level integration.


## 17. MATLAB and Keysight VSA Signal-Quality Verification

In addition to the exact digital regressions, system-level communication-signal
quality was evaluated using the project MATLAB model and Keysight PathWave
Vector Signal Analysis (VSA).

### 17.1 MATLAB Verification Model

The preserved MATLAB verification model uses a common 60 MS/s 64-QAM input
stimulus and evaluates interpolation factors L=2, 3, 4 and 5.

The original per-L input copies were verified byte-for-byte identical before
being consolidated into:

    results/verification/matlab_results/iqdata_60M_use.txt

Their common SHA-256 digest is:

    e99d42d73d85492f9651673bacf4e1d8c8b079dd0d3d88082ef9e003d083f07a

The fixed-point MATLAB interpolation datapath uses signed 16-bit signal
representation with 14 fractional bits. Interior interpolation uses Catmull-Rom
cubic interpolation and the sequence edges use the corresponding quadratic
edge treatment.

The MATLAB reference filtering stage uses a 64-tap FIR with normalized cutoff
1/L.

The configurable project-facing source is:

    verification/matlab/cubic_hardware.m

The preserved numeric results for each L contain:

- floating-point cubic reference output;
- fixed-point PRE-LPF output;
- fixed-point POST-LPF output.

### 17.2 MATLAB and RTL FIR Difference

The final RTL does not implement the coefficient-identical 64-tap MATLAB FIR.

Instead, the RTL uses a 10-tap symmetric hardware FIR with a dedicated
coefficient bank for each interpolation factor.

Keysight VSA is therefore used to evaluate the complete MATLAB and RTL
processing chains at the system-signal-quality level. The post-filter signals
are not presented as bit-exact MATLAB-to-RTL equivalents.

### 17.3 Keysight VSA Method

MATLAB I/Q text outputs are converted to Keysight-compatible MAT
files using:

    verification/keysight/float_iq_to_vsa.m

RTL hexadecimal outputs are converted using:

    verification/keysight/hex_iq_to_vsa.m

The RTL converter interprets the final FIR output as signed 16-bit fixed-point
data with 14 fractional bits.

The output sampling rates used by VSA are:

| L | Output Sample Rate |
|---:|---:|
| 2 | 120 MS/s |
| 3 | 180 MS/s |
| 4 | 240 MS/s |
| 5 | 300 MS/s |

### 17.4 Representative EVM Measurements

Keysight VSA reports EVM continuously. The displayed reading can vary slightly
with the active measurement interval and analyzer state.

For this reason, the preserved screenshots are treated as representative
point-in-time measurements rather than immutable exact constants.

Representative captured values are:

| L | MATLAB pre-FIR | MATLAB post-FIR | RTL post-FIR |
|---:|---:|---:|---:|
| 2 | ~223 m%rms | ~215 m%rms | ~218 m%rms |
| 3 | ~193 m%rms | ~197 m%rms | ~177 m%rms |
| 4 | ~201 m%rms | ~227 m%rms | ~176 m%rms |
| 5 | ~222 m%rms | ~228 m%rms | ~267 m%rms |

The corresponding screenshot readings at the captured instants were
approximately:

    L=2 : MATLAB pre 223.44, MATLAB post 215.39, RTL 217.53 m%rms
    L=3 : MATLAB pre 192.98, MATLAB post 196.82, RTL 177.20 m%rms
    L=4 : MATLAB pre 201.39, MATLAB post 227.29, RTL 176.42 m%rms
    L=5 : MATLAB pre 221.91, MATLAB post 228.30, RTL 267.23 m%rms

The project requirement is:

    EVM < 350 m%rms

All four preserved RTL operating-mode measurements satisfy this requirement.
The representative RTL readings span approximately 176-267 m%rms.

The FIR stage is intended primarily to suppress interpolation-generated
spectral images. The VSA measurements show that the EVM change across the
MATLAB FIR is mode-dependent, so the project does not claim that FIR filtering
monotonically reduces EVM.

### 17.5 Preserved VSA Evidence

MATLAB PRE-LPF screenshots:

    results/verification/matlab/pre_filter/

MATLAB POST-LPF screenshots:

    results/verification/matlab/post_filter/

RTL POST-LPF screenshots:

    results/verification/rtl/

The detailed VSA summary is:

    results/verification/keysight_vsa_summary.txt

### 17.6 Preserved RTL Outputs

The preserved post-FIR RTL result files contain:

| L | Captured Output Samples |
|---:|---:|
| 2 | 19,990 |
| 3 | 29,986 |
| 4 | 39,982 |
| 5 | 49,978 |

These files are stored under:

    results/verification/rtl_output_post_LPF/

The L=5 output is the same complete 49,978-sample sequence used by the
Golden/RTL/GLS/pad-level byte-for-byte regression described earlier.


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
