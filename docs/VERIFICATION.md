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
| `results/lec/LEC_SUMMARY.txt` | Validated formal equivalence summary |
| `results/verification/digital_verification_summary.txt` | Curated digital regression summary |


## 15. Verification Coverage in the Current Repository

The current repository documents and preserves evidence for:

- RTL functional simulation;
- exact RTL-to-golden comparison;
- synthesized gate-level functional simulation;
- exact gate-level-to-golden comparison;
- hierarchical RTL-to-gate logical equivalence;
- pad-integrated functional simulation;
- exact pad-level-to-golden comparison.

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
