# Static Timing Analysis

## 1. Overview

Final post-layout static timing analysis of the CUBIC Interpolation DSP ASIC is
performed using Synopsys PrimeTime.

PrimeTime operates on the completed physical implementation exported from
Cadence Innovus.

The final analysis uses:

    flat post-layout gate-level netlist
    extracted SPEF parasitics
    TSMC 28 nm timing libraries
    propagated clock timing
    implementation timing constraints

The complete timing matrix evaluates:

    setup / slow
    setup / typical
    setup / fast

    hold / slow
    hold / typical
    hold / fast

This provides an independent post-layout timing analysis after placement,
clock-tree synthesis, routing and final physical ECO closure.


## 2. PrimeTime Flow

The final PrimeTime analysis script is:

    primetime/scripts/pt_run_final_iter4b_no_flat.tcl

The matrix runner is:

    primetime/run_pt_final_iter4b.tcsh

The runner executes all six combinations of:

    mode   = setup, hold
    corner = slow, typ, fast

The resulting reports are collected under:

    results/primetime/final_matrix_full/


## 3. Physical-Design Handoff

PrimeTime reads the final physical timing netlist:

    innovus/dataout/pt_hold_eco_iter4b_trial/top_post_layout.v

The netlist is generated from the completed routed Innovus database after the
final timing and electrical ECO sequence.

The PrimeTime top-level design is:

    top

Power and ground connectivity is removed from the timing netlist export so that
the file contains the logical timing representation required for STA.


## 4. Extracted Parasitics

The final Innovus implementation is extracted for two physical RC conditions:

    top_slow.SPEF
    top_fast.SPEF

The slow parasitic file is produced using the TSMC `cworst` QRC model.

The fast parasitic file is produced using the TSMC `cbest` QRC model.

These files contain the routed interconnect resistance and capacitance used by
PrimeTime for post-layout delay calculation.


## 5. Timing Library Corners

The PrimeTime flow evaluates three timing-library conditions.

### Slow Corner

Core library:

    tcbn28hpcplusbwp30p140ssg0p81v125c.db

Pad library:

    tphn28hpcpgv18ssg0p81v1p62v125c.db

This represents:

    core voltage : 0.81 V
    pad voltage  : 1.62 V
    temperature  : 125 C

The slow analysis uses:

    top_slow.SPEF


### Typical Corner

Core library:

    tcbn28hpcplusbwp30p140tt0p9v25c.db

Pad library:

    tphn28hpcpgv18tt0p9v1p8v25c.db

This represents:

    core voltage : 0.90 V
    pad voltage  : 1.80 V
    temperature  : 25 C

The final PrimeTime flow evaluates this library condition with:

    top_slow.SPEF


### Fast Corner

Core library:

    tcbn28hpcplusbwp30p140ffg0p99vm40c.db

Pad library:

    tphn28hpcpgv18ffg0p99v1p98vm40c.db

This represents:

    core voltage : 0.99 V
    pad voltage  : 1.98 V
    temperature  : -40 C

The fast analysis uses:

    top_fast.SPEF


## 6. Corner Matrix

The final PrimeTime analysis therefore uses the following combinations:

| Corner | Core Condition | Pad Condition | Parasitics |
|---|---|---|---|
| Slow | SS, 0.81 V, 125 C | 1.62 V, 125 C | Slow SPEF |
| Typical | TT, 0.90 V, 25 C | 1.80 V, 25 C | Slow SPEF |
| Fast | FF, 0.99 V, -40 C | 1.98 V, -40 C | Fast SPEF |

All three conditions are analyzed for both setup and hold.


## 7. Timing Constraints

PrimeTime uses the physical implementation constraints derived from the Innovus
constraint environment.

The principal functional clock is:

    clk

with period:

    1.04 ns

corresponding to approximately:

    961.5 MHz

The clock is defined at the physical clock-pad path and includes the same
functional timing requirements used during physical implementation.

For final PrimeTime signoff, the external asynchronous reset path `I6/I1/C` is
modeled with a minimum input delay of:

    0.06 ns

This final external-interface assumption is applied by the PrimeTime analysis
script after the translated physical SDC has been loaded.


## 8. Clock Propagation

Final STA uses a propagated physical clock.

After the timing constraints and parasitic data have been loaded, PrimeTime
executes:

    set_propagated_clock [all_clocks]

followed by:

    update_timing -full

Therefore, final timing analysis uses the implemented clock-tree delays rather
than an ideal pre-CTS clock model.


## 9. Signal-Integrity Analysis

The PrimeTime flow enables signal-integrity timing analysis through:

    si_enable_analysis = true

The post-layout timing environment therefore includes the final routed timing
representation together with the extracted interconnect information.


## 10. Constraint Transfer

The physical Innovus SDC is translated into a PrimeTime-compatible form before
being sourced.

The translation preserves the implementation timing values while adapting
tool-specific collection and hierarchical naming syntax to PrimeTime.

The additional physical configuration constraints are also loaded from:

    innovus/datain/extra_constraints.sdc

After these implementation constraints are loaded, the final PrimeTime flow
applies the 0.06 ns minimum external reset input-delay assumption at
`I6/I1/C`.

This maintains the physical timing relationships while applying the final
external reset-interface model used for signoff STA.


## 11. Functional Mode

Final STA analyzes normal functional operation.

The implementation SDC disables scan operation through functional case analysis
on the scan-enable control.

Therefore, the primary synchronous timing matrix represents the functional
operating mode of the ASIC.


## 12. Multicycle Constraints

The architectural multicycle relationships are retained in PrimeTime.

The principal datapath constraints are:

| Functional Structure | Setup | Hold |
|---|---:|---:|
| Interpolator result state | 14 cycles | 13 cycles |
| FIR processing state | 3 cycles | 2 cycles |

Additional long-latency configuration-state relationships are loaded from the
physical constraint environment.

These constraints preserve timing checks while matching the functional update
rates of the corresponding RTL state.


## 13. Setup and Hold Analysis

PrimeTime maps the two analysis modes to:

    setup -> maximum-delay timing
    hold  -> minimum-delay timing

Each mode is independently evaluated at the slow, typical and fast timing
conditions.


## 14. Timing Path Classes

The final timing script separates the reported timing paths into four classes.

### Overall

The worst timing path across all active timing groups.

### Data

The synchronous functional clock group:

    clk

This group represents the main register-based functional datapaths.

### Clock Gating

PrimeTime clock-gating checks are reported through:

    **clock_gating_default**

These checks evaluate the timing requirements of the physically implemented
clock-gating controls.

### Asynchronous

Asynchronous timing checks are reported through:

    **async_default**

This group includes asynchronous recovery/removal-style timing relationships
associated with asynchronous sequential controls.


## 15. Summary Metric Extraction

For each analysis mode and corner, the final script extracts:

    worst slack
    number of negative timing paths

independently for:

    overall
    data
    clock gating
    asynchronous checks

This prevents a violation in one specialized timing class from being
incorrectly interpreted as a violation of every timing class.


## 16. Setup Timing Matrix

The final setup results are:

| Corner | Overall WNS | Data WNS | Clock-Gating WNS | Async WNS |
|---|---:|---:|---:|---:|
| Slow | +0.092604 ns | +0.092604 ns | +0.337834 ns | +0.261252 ns |
| Typical | +0.327260 ns | +0.327260 ns | +0.370334 ns | +0.377244 ns |
| Fast | +0.360641 ns | +0.360641 ns | +0.396282 ns | +0.505061 ns |

The negative-path count is zero in every setup category and corner.


## 17. Slow-Corner Setup

The slow-corner setup result is the limiting setup condition.

The overall setup WNS is:

    +0.092604 ns

The worst synchronous data-path setup slack is also:

    +0.092604 ns

The clock-gating setup margin is:

    +0.337834 ns

and the asynchronous setup margin is:

    +0.261252 ns

No negative setup path is reported.


## 18. Typical-Corner Setup

At the typical timing condition:

    Overall WNS      = +0.327260 ns
    Data WNS         = +0.327260 ns
    Clock-gating WNS = +0.370334 ns
    Async WNS        = +0.377244 ns

All setup categories remain non-negative.


## 19. Fast-Corner Setup

At the fast timing condition:

    Overall WNS      = +0.360641 ns
    Data WNS         = +0.360641 ns
    Clock-gating WNS = +0.396282 ns
    Async WNS        = +0.505061 ns

All analyzed setup paths remain non-negative.


## 20. Setup Closure

Across the complete three-corner matrix:

    synchronous setup negative paths   = 0
    clock-gating setup negative paths  = 0
    asynchronous setup negative paths  = 0

The minimum setup margin is:

    +0.092604 ns

at the slow timing condition.

The final implementation therefore satisfies the analyzed setup requirements
across all three PrimeTime library conditions.


## 21. Hold Timing Matrix

The final minimum-delay results are:

| Corner | Overall WNS | Data WNS | Clock-Gating WNS | Async WNS |
|---|---:|---:|---:|---:|
| Slow | +0.022842 ns | +0.022842 ns | +0.058417 ns | +0.042381 ns |
| Typical | +0.010245 ns | +0.010245 ns | +0.031253 ns | +0.026578 ns |
| Fast | +0.000004 ns | +0.000004 ns | +0.010128 ns | +0.009833 ns |

All three hold analyses contain zero negative paths.

## 22. Slow-Corner Hold

At the slow timing condition:

    Overall WNS      = +0.022842 ns
    Data WNS         = +0.022842 ns
    Clock-gating WNS = +0.058417 ns
    Async WNS        = +0.042381 ns

No negative hold path is reported.

## 23. Typical-Corner Hold

At the typical timing condition:

    Overall WNS      = +0.010245 ns
    Data WNS         = +0.010245 ns
    Clock-gating WNS = +0.031253 ns
    Async WNS        = +0.026578 ns

No negative hold path is reported.

## 24. Fast-Corner Functional Hold

The fast corner is the limiting minimum-delay condition.

The synchronous functional data group reports:

    Data WNS = +0.000004 ns

with:

    Data negative paths = 0

The margin is equivalent to:

    +0.004 ps

This is a very small but positive synchronous data-path hold margin.

The result is therefore reported precisely as non-negative rather than as a
large hold margin.


## 25. Fast-Corner Clock-Gating Hold

The fast-corner clock-gating group reports:

    Clock-gating WNS = +0.010128 ns

with:

    Clock-gating negative paths = 0

The detailed report shows positive minimum-delay margins for all six final
clock-gating checks.


## 26. Fast-Corner Asynchronous Checks

The asynchronous group reports:

    Async WNS = +0.009833 ns

with:

    Async negative paths = 0

The asynchronous recovery/removal timing checks therefore pass at the final
fast timing condition.

## 27. Final Asynchronous Removal Closure

The final PrimeTime fast-corner asynchronous analysis contains no negative
removal paths.

The limiting asynchronous minimum-delay margin is:

    +0.009833 ns
    +9.833 ps

The final analysis uses the 0.06 ns minimum external reset input-delay
assumption at `I6/I1/C`.

## 28. Interpretation of Fast Hold Overall WNS

The fast-corner timing classes report:

    Fast overall hold WNS   = +0.000004 ns
    Fast synchronous data   = +0.000004 ns
    Fast clock-gating WNS   = +0.010128 ns
    Fast asynchronous WNS   = +0.009833 ns

The limiting final fast-corner hold path is therefore a synchronous data path.

All fast-corner timing classes remain non-negative.

## 29. Hold-Path Classification

The final fast-corner negative-path counts are:

| Timing Class | Negative Paths |
|---|---:|
| Synchronous data | 0 |
| Clock gating | 0 |
| Asynchronous | 0 |
| Overall | 0 |

The complete final hold analysis is therefore clean across the reported timing
classes.

## 30. Synchronous Timing Result

Considering the synchronous implementation:

    setup data paths         : PASS at slow / typical / fast
    hold data paths          : PASS at slow / typical / fast
    clock-gating setup checks: PASS at slow / typical / fast
    clock-gating hold checks : PASS at slow / typical / fast

The limiting synchronous timing margins are:

    Setup : +0.092604 ns
    Hold  : +0.000004 ns


## 31. Comparison with Innovus Timing

The final Innovus implementation reports:

    Setup WNS = +0.122 ns
    Hold WNS  = +0.001 ns

The final PrimeTime analysis independently evaluates the exported post-layout
netlist and extracted parasitics across its three-corner timing matrix.

The Innovus and PrimeTime values therefore correspond to separate timing
analysis environments and should not be interpreted as numerically identical
reports.

PrimeTime provides the final detailed corner-by-corner timing classification
used in this repository.


## 32. Detailed Timing Reports

For every mode and corner, the repository preserves separate reports for:

    overall timing
    synchronous data timing
    clock-gating timing
    asynchronous timing
    timing constraints / violators
    check_timing

For example, fast-corner hold reports include:

    hold_fast_TIMING.rpt
    hold_fast_DATA.rpt
    hold_fast_CLOCK_GATING.rpt
    hold_fast_ASYNC.rpt
    hold_fast_VIOLATORS.rpt
    check_hold_fast.rpt


## 33. Report Precision

Detailed PrimeTime timing reports are generated with:

    significant_digits = 6

This is particularly important for the fast-corner functional hold result,
whose worst positive margin is only:

    0.000004 ns

The retained report precision prevents this result from being rounded to an
ambiguous `0.00 ns` value.


## 34. Worst-Path Reporting

The final PrimeTime reports retain passing worst paths as well as violating
paths.

This allows the repository to preserve the actual worst positive timing margin
even when a particular timing group contains no violations.

As a result, the final matrix records both:

    negative-path count

and:

    worst slack

for each timing class.


## 35. Timing Verification Matrix

The complete final timing status is:

| Check | Slow | Typical | Fast |
|---|---|---|---|
| Setup data | PASS | PASS | PASS |
| Setup clock gating | PASS | PASS | PASS |
| Setup async | PASS | PASS | PASS |
| Hold data | PASS | PASS | PASS |
| Hold clock gating | PASS | PASS | PASS |
| Hold async | PASS | PASS | PASS |

All analyzed timing classes are non-negative in the complete six-run
PrimeTime matrix.

## 36. PrimeTime Artifacts

The main final STA artifacts are:

| Path | Purpose |
|---|---|
| `results/primetime/final_sta_summary.txt` | Machine-readable WNS / negative-path matrix |
| `results/primetime/sta_interpretation_summary.txt` | Curated interpretation of final results |
| `results/primetime/final_matrix_full/` | Complete detailed STA reports |
| `primetime/scripts/pt_run_final_iter4b_no_flat.tcl` | Final STA analysis script |
| `primetime/run_pt_final_iter4b.tcsh` | Six-run corner/mode matrix runner |


## 37. Reproducing Final STA

The final PrimeTime matrix can be executed through:

    make pt

which invokes:

    primetime/run_pt_final_iter4b.tcsh

The runner performs:

    setup slow
    setup typical
    setup fast
    hold slow
    hold typical
    hold fast

and generates a complete summary after all six analyses.


## 38. Final Static Timing Summary

The final PrimeTime analysis demonstrates timing closure across the complete
slow, typical and fast setup/hold matrix.

All synchronous setup paths pass.

All synchronous functional data hold paths pass.

All clock-gating setup and hold checks pass.

All analyzed asynchronous recovery/removal checks pass.

The limiting overall margins are:

    Setup WNS = +0.092604 ns
    Hold WNS  = +0.000004 ns

The final PrimeTime matrix contains zero negative paths in all six analyzed
corner/mode runs.

The final external asynchronous-reset interface model uses a minimum input
delay of 0.06 ns at `I6/I1/C`.

The full timing matrix and detailed path reports are preserved in the
repository for independent review.
