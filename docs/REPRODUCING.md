# Reproducing the Implementation Flow

## 1. Purpose

This document describes how to reproduce the principal digital implementation
and analysis stages of the CUBIC Interpolation DSP ASIC repository.

The flow covers:

    RTL simulation
        |
        v
    logic synthesis
        |
        v
    gate-level simulation
        |
        v
    logical equivalence checking
        |
        v
    pad-level gate simulation
        |
        v
    Innovus physical implementation
        |
        v
    final post-route ECO closure
        |
        v
    final PrimeTime handoff
        |
        +------------------+
        |                  |
        v                  v
    PrimeTime STA     SAIF-based power

The repository uses the project `Makefile` as the primary command interface.


## 2. Environment

The implementation flow requires access to the configured university ASIC
design environment and the licensed EDA tools used by the project.

The principal tools are:

| Stage | Tool |
|---|---|
| RTL / GLS | Synopsys VCS |
| Logic synthesis | Synopsys Design Compiler |
| Logical equivalence | Cadence Conformal |
| Physical design | Cadence Innovus |
| Static timing analysis | Synopsys PrimeTime |

The physical and timing flows additionally require access to the configured
TSMC 28 nm technology libraries and extraction files.

The repository scripts load the required tool modules or invoke the configured
site wrappers.


## 3. Project Root

All commands in this document are executed from the repository root:

    /project/verif/users/yitzhak2/ws/ex_vlsi_1/final_script

For example:

    cd /project/verif/users/yitzhak2/ws/ex_vlsi_1/final_script


## 4. Interpolation-Factor Selection

Front-end simulation targets accept the interpolation factor through the
Makefile variable:

    L

Supported values are:

    2
    3
    4
    5

The default is:

    L=5

For example:

    make sim L=5

or:

    make sim L=3

The canonical repository golden comparison is defined for the primary L=5
regression.

For L values other than 5, the simulation output is generated but the
Makefile's canonical L=5 golden comparison is skipped.


## 5. Primary Full-Flow Sequence

The validated implementation sequence is:

    make sim
    make syn
    make gls
    make lec
    make gls_pads
    make pnr
    make final_eco
    make backend_prep_final
    make power
    make pt

Each stage is described below.


## 6. RTL Simulation

Run:

    make sim

The default configuration is L=5.

This target:

1. checks for the required RTL testbench and input vector;
2. invokes `RTL/run_sim.tcsh`;
3. compiles and runs the RTL using VCS;
4. writes the captured output under `out/`;
5. compares the L=5 output against the canonical golden reference.

The principal output is:

    out/rtl_output_POST_LPF_L_5.txt

The canonical reference is:

    out/output_golden.txt

A successful L=5 regression reports a passing exact comparison.


## 7. RTL Simulation for Other L Values

To execute another interpolation mode:

    make sim L=2
    make sim L=3
    make sim L=4

The corresponding input vector is selected from:

    in/input_hex_60M_L_<L>.txt

For these modes, the repository retains the generated simulation result without
performing the L=5 canonical golden comparison.


## 8. Logic Synthesis

Run:

    make syn

This invokes:

    synthesis/run_syn.tcsh

which executes the Design Compiler synthesis flow.

The synthesis stage performs:

- RTL analysis and elaboration;
- timing constraint application;
- clock-gating optimization;
- `compile_ultra`;
- timing, area and power reporting;
- scan-chain insertion;
- final netlist and constraint generation.

Principal generated outputs include:

    synthesis/dataout/ASIC_Top_netlist.v
    synthesis/dataout/ASIC_Top.sdc
    synthesis/dataout/scandef
    synthesis/dataout/ASIC_Top.spf
    synthesis/dataout/final_ASIC_Top.ddc


## 9. Gate-Level Simulation

After synthesis, run:

    make gls

This target verifies that the synthesized netlist is available and invokes:

    GLS/run_gls.tcsh

The synthesized gate-level design is simulated using VCS with the same primary
functional stimulus. This is a functional GLS without SDF back-annotation.

For L=5, the resulting output is compared against:

    out/output_golden.txt

The validated regression produces a byte-identical result.


## 10. Logical Equivalence Checking

Run:

    make lec

This invokes Cadence Conformal through:

    lec_rvg/run_lec.tcsh

using the hierarchical comparison flow:

    lec_rvg/scripts/hier.do

The validated project result is:

    12 / 12 module pairs equivalent
    NEQ   = 0
    ABORT = 0

A curated result is stored in:

    results/lec/LEC_SUMMARY.txt


## 11. Pad-Level Gate Simulation

Run:

    make gls_pads

This invokes:

    gentop/run_pads.tcsh

and simulates the pad-integrated gate-level hierarchy in zero-delay mode.

The canonical padded GLS uses the real TSMC 28 nm I/O Verilog model. The only
additional simulation stub is the mechanical `PCORNER_G` cell.

For the primary L=5 regression, the generated output is compared with the same
canonical golden reference.

The validated pad-level result is byte-identical to the RTL and core GLS
outputs.


## 12. Main Place-and-Route Flow

Run:

    make pnr

This invokes:

    innovus/run_innovus.tcsh

which executes the top-level Innovus flow:

    innovus/scripts/full.tcl

The principal physical-design sequence is:

    init
      |
      v
    floorplan
      |
      v
    global power connection
      |
      v
    power ring / stripes
      |
      v
    placement
      |
      v
    clock-tree synthesis
      |
      v
    routing
      |
      v
    post-route optimization
      |
      v
    filler / final repair
      |
      v
    parasitic extraction

The baseline P&R flow creates saved Innovus implementation checkpoints under:

    innovus/dataout/design_saves/


## 13. What `make flow` Does

The convenience target:

    make flow

executes:

    sim
    syn
    gls
    lec
    gls_pads
    pnr

in that order.

Therefore:

    make flow

runs the project only through the baseline physical-design stage.

It does not automatically execute:

    final_eco
    backend_prep_final
    power
    pt

Those final stages must be launched separately.


## 14. Final Post-Route ECO Closure

After the baseline routed design is available, run:

    make final_eco

This invokes:

    innovus/run_final_eco.tcsh

The runner executes the validated post-route closure stages in order.

The closure sequence addresses:

- functional data hold timing;
- remaining focused data hold paths;
- clock-gating minimum-delay timing;
- scan-enable electrical distribution.

The final implementation database is:

    innovus/dataout/design_saves/final_hold_eco_iter4b_trial


## 15. Final ECO Completion Checks

The ECO runner checks for explicit completion markers from each physical stage:

    HOLD_ECO_29_PHYSICAL_PASS
    HOLD_ECO_ITER2_PHYSICAL_PASS
    CG_ECO_ITER3_PHYSICAL_PASS
    SCAN_ECO_ITER4B_PHYSICAL_PASS

The completed physical implementation is the database used by the subsequent
PrimeTime and power-analysis stages.


## 16. PrimeTime Handoff Generation

After final ECO closure, run:

    make backend_prep_final

This restores the completed physical database and invokes:

    innovus/scripts/backend_prep_hold_eco_iter4b.tcl

The handoff stage generates:

    top_post_layout.v
    top_slow.SPEF
    top_fast.SPEF

under:

    innovus/dataout/pt_hold_eco_iter4b_trial/

The script checks that all three outputs exist and are non-empty before
reporting:

    PT_HANDOFF_PASS


## 17. Final Handoff Contents

The three primary PrimeTime inputs are:

| File | Purpose |
|---|---|
| `top_post_layout.v` | Flat final post-layout timing netlist |
| `top_slow.SPEF` | SlowRC extracted parasitics |
| `top_fast.SPEF` | FastRC extracted parasitics |

These files represent the final routed and ECO-closed physical implementation.


## 18. SAIF Activity Files

Final power analysis requires one activity file for each supported interpolation
factor:

    innovus/datain/saif/core_L2.saif
    innovus/datain/saif/core_L3.saif
    innovus/datain/saif/core_L4.saif
    innovus/datain/saif/core_L5.saif

To regenerate all four activity files and stage them for Innovus, run:

    make saif_gen

This invokes `GL_sim_saif/run_saif.tcsh`, which performs one synthesized
gate-level activity simulation for each supported interpolation factor L=2..5.
The generated files are written under `GL_sim_saif/saif/` and copied into
`innovus/datain/saif/`.

The retained generated and staged files were verified byte-for-byte identical
for all four interpolation factors.

The activity was captured from gate-level simulation and is mapped from:

    design_tb/dut

onto the physical core instance:

    I0


## 19. Checking SAIF Availability

To check a specific interpolation mode:

    make saif L=5

For example:

    make saif L=2

The target checks that the corresponding staged SAIF file exists before power
analysis.


## 20. Final Post-Route Power Analysis

Run:

    make power

This executes:

    innovus/scripts/power_saif_final_iter4b.tcl

on the final routed physical database.

The script automatically discovers the staged per-L SAIF files and generates
independent power reports for the available interpolation factors.

The retained final project analysis includes:

    L=2
    L=3
    L=4
    L=5

Reports are preserved under:

    results/power/final_iter4b/


## 21. Power-Analysis Outputs

The retained reports include:

    chip_L2.rpt ... chip_L5.rpt
    core_L2.rpt ... core_L5.rpt

together with per-mode reports for:

    interp_I
    interp_Q
    fir_I
    fir_Q

The compact result table is:

    results/power/final_iter4b/saif_summary.txt

The reported activity annotation coverage is:

    98.287926%


## 22. Final L5 Core-Domain IR-Drop Analysis

Run:

    make ir

This executes:

    innovus/scripts/ir_rail_final_iter4b_l5.tcl

on the final Iter4B routed database.

The analysis uses the staged:

    innovus/datain/saif/core_L5.saif

activity file and analyzes the VDDC/VSSC core domain at the SlowView SS
0.81 V, 125 C / cworst condition.

The principal retained result is:

    results/innovus/final_ir_drop_summary.txt

with detailed VDDC/VSSC and PG-integrity reports also retained under:

    results/innovus/

The final project result is approximately 3.00 mV worst VDDC drop and
2.55 mV maximum VSSC bounce, with zero voltage-threshold violations.

The analysis is explicitly scoped to the DSP core domain. The tech-only PGV
representation contains disconnected pad-ring sections outside `I0`; these are
documented in the retained integrity reports.


## 23. Final PrimeTime STA

After generating the final post-layout handoff, run:

    make pt

This invokes:

    primetime/run_pt_final_iter4b.tcsh

The runner automatically executes six independent PrimeTime analyses:

    setup / slow
    setup / typ
    setup / fast

    hold / slow
    hold / typ
    hold / fast


## 24. PrimeTime Outputs

The final STA matrix produces separate reports for:

- overall timing;
- synchronous data timing;
- clock-gating timing;
- asynchronous timing;
- constraint violations;
- `check_timing`.

The curated full matrix is preserved under:

    results/primetime/final_matrix_full/

The compact result matrix is:

    results/primetime/final_sta_summary.txt


## 25. Recommended End-to-End Command Sequence

For a complete reproduction from the front-end through the final analyses, use:

    make sim
    make syn
    make gls
    make lec
    make gls_pads
    make pnr
    make final_eco
    make backend_prep_final
    make saif_gen
    make power
    make ir
    make pt

The order is important because later stages consume artifacts generated by
earlier stages.


## 26. Alternative Main-Flow Invocation

The first six stages may alternatively be executed using:

    make flow

followed by:

    make final_eco
    make backend_prep_final
    make power
    make pt

This is functionally equivalent to invoking the main front-end and P&R targets
individually in sequence.


## 27. Individual P&R Stage Execution

The Makefile also provides:

    make pnr_stage

for targeted physical-design execution from an existing saved state.

The configurable parameters are:

    STAGE
    PREV

For example, this mechanism can be used when working with a specific Innovus
implementation stage rather than executing the full P&R sequence.

The final documented project result, however, is based on the complete
validated final implementation flow.


## 28. Generated vs Retained Artifacts

The EDA flows produce a large number of temporary work files, databases and
logs.

The repository retains selected source files and final evidence needed to
document the project result.

Curated final evidence is organized under:

    results/

while detailed tool working directories remain under the corresponding flow
directories.


## 29. Cleaning Generated Work Files

The Makefile provides:

    make clean

to remove generated work-directory contents and common simulation artifacts.

A more extensive cleanup is available through:

    make clean_all

The cleanup targets preserve principal source inputs, staged project data and
selected retained artifacts according to the Makefile definitions.

Do not run cleanup commands if temporary tool outputs are still needed for an
active debugging or analysis session.


## 30. Getting Command Help

Run:

    make help

to display the repository's primary execution targets.

The help output separates:

- main flow stages;
- final physical implementation stages;
- final power and core-domain IR analysis;
- PrimeTime analysis;
- SAIF generation, staging and availability support;
- cleanup commands.


## 31. Primary Result Evidence

After reproducing the flow, the main result summaries are:

    results/verification/digital_verification_summary.txt
    results/synthesis/synthesis_summary.txt
    results/innovus/physical_design_summary.txt
    results/innovus/final_ir_drop_summary.txt
    results/primetime/final_sta_summary.txt
    results/primetime/sta_interpretation_summary.txt
    results/power/final_iter4b/saif_summary.txt
    results/power/final_iter4b/power_interpretation_summary.txt
    results/lec/LEC_SUMMARY.txt

The complete consolidated numerical result is documented in:

    docs/RESULTS.md


## 32. Documentation Map

Detailed flow explanations are available in:

    docs/SYSTEM_ARCHITECTURE.md
    docs/RTL_ARCHITECTURE.md
    docs/VERIFICATION.md
    docs/SYNTHESIS.md
    docs/PHYSICAL_DESIGN.md
    docs/STATIC_TIMING_ANALYSIS.md
    docs/POWER_ANALYSIS.md
    docs/RESULTS.md

These documents should be used together with the retained tool reports when
reviewing or reproducing the implementation.


## 33. Reproduction Summary

The repository exposes the complete validated implementation sequence through
Makefile targets and stage-specific `tcsh` wrappers.

The principal order is:

    RTL
     |
     v
    Synthesis
     |
     v
    GLS / LEC
     |
     v
    Pad Integration Verification
     |
     v
    Physical Design
     |
     v
    Final Physical ECO Closure
     |
     v
    Extracted Backend Handoff
     |
     v
    SAIF Power / Core-Domain IR
     |
     v
    PrimeTime STA

The retained result summaries and full reports provide the evidence needed to
verify the final outputs of each major stage.
