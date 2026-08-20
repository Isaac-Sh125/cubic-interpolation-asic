# Physical Design

## 1. Overview

The synthesized CUBIC Interpolation DSP ASIC is implemented as a fully padded
TSMC 28 nm physical design using Cadence Innovus.

The physical-design flow transforms the mapped gate-level implementation into a
placed, clock-routed and signal-routed layout representation with extracted
parasitics suitable for final static timing analysis.

The principal implementation sequence is:

    Padded Gate-Level Netlist
              |
              v
         Initialization
              |
              v
           Floorplan
              |
              v
       Global PG Connection
              |
              v
        Power Distribution
              |
              v
           Placement
              |
              v
     Clock-Tree Synthesis
              |
              v
            Routing
              |
              v
      Post-Route Optimization
              |
              v
      Physical Verification
              |
              v
    Targeted Timing / DRV ECO
              |
              v
      Final Physical Design
              |
              v
       Parasitic Extraction
              |
              v
       PrimeTime Handoff

The top-level physical flow is implemented in:

    innovus/scripts/full.tcl


## 2. Physical-Design Tool

The final implementation was produced using:

    Cadence Innovus
    Version 22.15-s091_1

The design is configured for:

    process = 28 nm

and uses eight local CPU workers during major implementation stages.


## 3. Technology and Physical Libraries

The design targets the TSMC 28 nm HPC+ technology.

The physical implementation environment loads:

- the TSMC 28 nm technology LEF;
- the TSMC 28 nm standard-cell LEF;
- the I/O pad LEF;
- the associated physical pad/bonding library information.

The selected technology configuration uses a nine-layer metal stack.

The physical library environment is defined in:

    innovus/datain/env.globals


## 4. Padded Top-Level Design

Physical implementation is performed on the pad-integrated top-level module:

    top

The synthesized DSP core is instantiated inside this wrapper, together with the
I/O and power-pad structures required by the physical implementation.

The top-level Verilog input is:

    innovus/datain/top.v

Pad placement information is provided through:

    innovus/datain/top.io

The design is therefore imported into Innovus as a complete padded-chip
hierarchy rather than as an isolated standard-cell core.


## 5. Initialization

The initialization stage is implemented in:

    innovus/scripts/init.tcl

The main initialization operations are:

- selection of the 28 nm process mode;
- loading of the netlist and physical libraries;
- loading of the I/O placement definition;
- loading of the MMMC timing environment;
- creation of the physical design database.

Synthesis-generated clock-gating wrapper modules are flattened during import so
that their underlying physical cells are available directly to the Innovus
placement and clock-tree engines.


## 6. MMMC Timing Environment

Physical implementation uses a multi-corner multi-mode timing configuration
defined in:

    innovus/datain/mmmc.view

The active implementation views are:

| Analysis | View | Library Condition | RC Corner |
|---|---|---|---|
| Setup | SlowView | Slow / SS | SlowRC |
| Hold | FastView | Fast / FF | FastRC |

The slow library set uses:

    Core : 0.81 V, 125 C
    I/O  : 1.62 V, 125 C

with the `cworst` QRC extraction technology.

The fast library set uses:

    Core : 0.99 V, -40 C
    I/O  : 1.98 V, -40 C

with the `cbest` QRC extraction technology.

The active Innovus analysis configuration is:

    Setup : SlowView
    Hold  : FastView


## 7. Physical Timing Constraints

The physical top-level clock enters through the clock pad and is defined at:

    I5/I1/C

The clock constraint is:

    period = 1.04 ns

with:

    clock uncertainty = 0.05 ns

The padded physical constraints include explicit minimum and maximum I/O delay
budgets at the core-facing sides of the pad cells.

Functional timing is analyzed with scan mode disabled using case analysis on
the scan-enable input.


## 8. Multicycle Timing Preservation

The architectural multicycle relationships defined during synthesis are
preserved in the physical implementation.

The principal multicycle constraints are:

| Structure | Setup | Hold |
|---|---:|---:|
| Interpolator output registers | 14 cycles | 13 cycles |
| FIR registers | 3 cycles | 2 cycles |

These constraints preserve timing analysis while reflecting the functional
update cadence of the corresponding state.

The padded physical implementation also constrains the configuration state
associated with `L_val` and `mode_15bit` as long-latency configuration paths,
since those values are established before the streaming operation and remain
stable during packet processing.


## 9. Floorplan

The floorplan is created in:

    innovus/scripts/fp.tcl

The final chip dimensions are:

| Region | Size |
|---|---:|
| Die | 880 x 880 um |
| Core | 560 x 560 um |

The die extends from:

    (0, 0) to (880, 880)

A 110 um pad depth is reserved from the die edge to the inner I/O boundary.

An additional 50 um channel separates the I/O boundary from the standard-cell
core.

The resulting core inset is:

    110 um + 50 um = 160 um

which produces the 560 x 560 um core region.


## 10. I/O Ring Completion

After floorplan creation, I/O filler cells are inserted around all four sides of
the die.

The I/O fillers close the pad ring and maintain physical continuity between
adjacent pad structures.

Fillers are inserted independently on:

    North
    South
    East
    West

and the floorplan is checked after insertion.


## 11. Power Domains and Global Nets

The physical implementation separates the core and pad power networks.

Core power rails are:

    VDDC
    VSSC

Pad-related power rails are:

    VDDP
    VSSP
    POC

Global power connectivity is established in:

    innovus/scripts/glnets.tcl

Standard-cell power pins are connected to:

    VDD -> VDDC
    VSS -> VSSC

while the corresponding pad power pins are associated with the pad-domain
supplies.


## 12. Core Power Ring

The core power-distribution network is implemented primarily on the upper metal
layers.

The core ring uses:

    horizontal segments : M9
    vertical segments   : M8

for both:

    VDDC
    VSSC

The ring geometry is:

| Parameter | Value |
|---|---:|
| Width | 10 um |
| Spacing | 10 um |
| Offset | 10 um |

The use of the upper metal layers provides a wide, low-resistance distribution
structure around the standard-cell core.


## 13. Power Stripes

The core ring is supplemented by an orthogonal internal stripe network.

Vertical stripes use:

    M8

Horizontal stripes use:

    M9

The stripe geometry is:

| Parameter | Value |
|---|---:|
| Stripe width | 4 um |
| VDD/VSS pair spacing | 4 um |
| Set-to-set distance | 70 um |
| Initial offset | 31 um |

Both `VDDC` and `VSSC` are distributed through the stripe network.


## 14. Power-Rail Stitching

Special routing is used to connect the standard-cell rails, internal stripes,
core power ring and core-supply pad connections.

The routing spans the available layer range:

    M1 through M9

and allows the tool to insert the layer transitions required to stitch the
hierarchical power network.

This creates the connection path:

    Standard-Cell Rails
            |
            v
       Power Stripes
            |
            v
        Core Ring
            |
            v
     Core-Supply Pads


## 15. Standard-Cell Placement

Placement is implemented in:

    innovus/scripts/place.tcl

The placement engine is configured to consider:

- timing;
- congestion;
- clock-gating structure;
- power.

The principal placement operation is:

    place_design

Scan-chain order is not used as the dominant placement objective, allowing
functional timing and physical quality to drive the core placement.


## 16. Tie-Cell Insertion

Dedicated TSMC tie-high and tie-low cells are inserted after placement.

The configured cells are:

    TIEHBWP30P140
    TIELBWP30P140

Tie connections use controlled distance and fanout limits.

This prevents direct constant connections from being implemented through
inappropriate standard-cell power connections.


## 17. Post-Placement Power Connectivity

After placement and tie-cell insertion, special routing is repeated for the core
power rails.

This ensures that newly placed and inserted cells are connected into the
`VDDC/VSSC` distribution structure.


## 18. Clock-Tree Synthesis

Clock-tree synthesis is implemented in:

    innovus/scripts/cts.tcl

Cadence CCOpt is used to create and optimize the physical clock network.

The sequence is:

    create_ccopt_clock_tree_spec
              |
              v
        source ccopt.spec
              |
              v
          ccopt_design
              |
              v
          refinePlace

The clock-tree source is the core-facing side of the clock input pad:

    I5/I1/C


## 19. Clock-Tree Configuration

The generated CCOpt specification defines:

    clock name   : clk
    clock period : 1.04 ns

The target maximum clock transition is:

    0.05 ns

for the slow delay corner.

A timing-based skew group is automatically created for the functional clock.


## 20. Clock-Tree Scale

The implemented clock tree contains:

    1 clock source
    1138 clock-tree sinks
    6 clock gates
    17 clock buffers
    0 clock inverters

The logical clock-buffering depth is:

    minimum depth = 2
    maximum depth = 3

The clock-gating depth is one level.

The functional skew group is:

    clk/TypCM

and contains:

    1 source
    1132 constrained sinks
    6 unconstrained sinks

for a total clock-tree sink count of 1138.


### Measured Clock Skew

A final CCOpt report was generated directly from the completed routed physical
database.

The measured skew is:

| Timing Corner | Minimum Insertion Delay | Maximum Insertion Delay | Reported Skew |
|---|---:|---:|---:|
| SlowDC setup | 0.123 ns | 0.140 ns | **0.016 ns (16 ps)** |
| FastDC hold | 0.081 ns | 0.093 ns | **0.013 ns (13 ps)** |

The displayed minimum and maximum insertion-delay values are rounded by the
report. The skew values above are the values reported directly by CCOpt.

For `SlowDC:setup.late`, CCOpt automatically computes a skew target of:

    0.023 ns = 23 ps

while the measured skew is:

    0.016 ns = 16 ps

so the implemented slow-corner skew is within the reported CCOpt target.


### Clock Slew

At the slow setup corner, the final clock tree reports:

    worst rising leaf slew  = 0.049 ns
    worst falling leaf slew = 0.049 ns
    worst rising trunk slew = 0.039 ns
    worst falling trunk slew= 0.039 ns

The extracted slow-corner slew target is:

    0.050 ns

Therefore, the reported final slow-corner leaf and trunk slew values remain
within the target.


### Clock-Tree Electrical Checks

The final CCOpt report contains zero clock-tree violations for:

    maximum capacitance
    maximum resistance
    maximum length
    maximum fanout
    slew

The complete final CCOpt report is preserved in:

    results/innovus/final_cts_ccopt.rpt


## 21. Post-CTS Timing State

The post-CTS timing summary reports:

    Setup WNS = +0.122 ns
    Setup TNS = 0.000 ns
    Setup violating paths = 0

The post-CTS placement density is:

    12.389%

and routing overflow is:

    Horizontal = 0.00%
    Vertical   = 0.00%

At this stage, the timing design is setup-clean and ready for detailed signal
routing and final electrical closure.


## 22. Signal Routing

Signal routing is implemented in:

    innovus/scripts/route.tcl

The router is configured for:

- timing-driven routing;
- signal-integrity-driven routing;
- antenna repair;
- on-chip-variation timing analysis;
- CPPR-aware timing analysis.

The main routing operation is:

    routeDesign


## 23. Post-Route Optimization

After detailed routing, Innovus performs:

    optDesign -postRoute

followed by:

    optDesign -postRoute -hold

The first pass optimizes routed setup timing and general post-route timing
quality.

The second pass specifically targets routed minimum-delay / hold timing.

A subsequent ECO routing pass is used to repair remaining routing-rule issues.


## 24. Post-Route Verification

Immediately after routing and optimization, the flow generates:

- post-route setup timing reports;
- post-route hold timing reports;
- DRC reports;
- connectivity reports.

These checks establish the physical state before final filler insertion and
final closure operations.


## 25. Standard-Cell Fillers

Standard-cell filler cells are inserted before the final implementation
checkpoint.

The filler set contains multiple cell widths in order to close placement-row
gaps efficiently.

Filler insertion provides physical row continuity and prepares the design for
the final Innovus physical-verification pass.


## 26. Final Physical Repair

The final write stage invokes:

    innovus/scripts/fix_final_drc.tcl

after filler insertion.

This stage performs the final targeted physical cleanup before the baseline
`final` database is saved.

Timing is re-evaluated after the repair using both setup and hold analysis.


## 27. Post-Route Closure Strategy

Following the routed baseline implementation, targeted ECO operations are used
to close the remaining minimum-delay and electrical constraints.

The final closure sequence addresses three principal objectives:

1. data-path hold timing;
2. clock-gating hold timing;
3. scan-enable electrical distribution.

Each closure stage performs physical insertion, legalization/routing,
connectivity verification, DRC verification and timing re-evaluation before
saving the next implementation checkpoint.


## 28. Data-Path Hold Closure

The first data-hold closure stage inserts 29 targeted delay/buffer cells.

The insertion set consists of:

    25 x DEL025D1BWP30P140
     4 x BUFFD0BWP30P140

The targets are selected from the routed minimum-delay analysis and include
interpolator, FIR, SIPO and control datapath endpoints.

A second focused data-hold stage adds:

    2 x DEL025D1BWP30P140

to the remaining critical data paths.

The final data-hold closure therefore contributes:

    31 targeted cells


## 29. Clock-Gating Hold Closure

Clock-gating enable/control paths are evaluated separately from the ordinary
functional data paths.

Four targeted buffers are inserted on the remaining clock-gating control paths:

    4 x BUFFD0BWP30P140

The buffers are placed on selected clock-gate control inputs in the I/Q FIR,
SIPO and interpolator hierarchy.

This closes the clock-gating minimum-delay requirements while preserving the
existing clock-tree structure.


## 30. Scan-Enable Electrical Closure

The scan-enable signal drives the scan-control inputs of the generated scan
structure.

A dedicated distribution buffer is inserted in the scan-enable network:

    U_SCAN_EN_BUF
    BUFFD2BWP30P140

The buffer separates the external scan-enable source from the downstream scan
load network and provides sufficient drive capability for the routed load.

The final implementation has no remaining:

    max_fanout
    max_capacitance
    max_transition
    max_length

violations.


## 31. Final Targeted ECO Count

The complete final post-route closure adds:

| Closure Class | Insertions |
|---|---:|
| Data hold | 31 |
| Clock-gating hold | 4 |
| Scan-enable distribution | 1 |
| Total | **36** |

These ECOs are applied to the routed physical implementation and are included in
the final database used for timing and power analysis.


## 32. Final Innovus Setup Timing

The final post-route setup result is:

    WNS = +0.122 ns
    TNS =  0.000 ns

The final report contains:

    Setup violating paths = 0

The register-to-register setup result is also:

    +0.122 ns

while the register-to-clock-gate timing group retains additional positive
margin.


## 33. Final Innovus Hold Timing

The final post-route hold result is:

    WNS = +0.001 ns
    TNS =  0.000 ns

The final report contains:

    Hold violating paths = 0

The register-to-clock-gate hold group reports:

    +0.012 ns

of worst slack.


## 34. Final Electrical Constraints

The final implementation reports zero violations in all primary electrical
design-rule categories:

| Constraint | Violating Nets / Terms |
|---|---:|
| Maximum capacitance | 0 |
| Maximum transition | 0 |
| Maximum fanout | 0 |
| Maximum length | 0 |

This confirms electrical closure of the routed design under the active Innovus
constraint environment.


## 35. Final Placement Density

The final standard-cell placement density is:

    12.419%

After insertion of physical fillers, the reported occupied density is:

    96.411%

The relatively large padded die provides substantial routing and implementation
space around the DSP core while allowing the I/O ring and core power
distribution structures to be integrated cleanly.


## 36. Final DRC Verification

The final Innovus DRC command reports:

    No DRC violations were found

Therefore:

    Final Innovus DRC violations = 0

The complete final DRC report is preserved in:

    results/innovus/final_drc.rpt


## 37. Final Connectivity Verification

The final connectivity analysis reports:

    Found no problems or warnings.

Therefore, the final routed implementation is connectivity-clean according to
the Innovus `verifyConnectivity` analysis.

The corresponding report is:

    results/innovus/final_connectivity.rpt


## 38. Final Physical Result

The final Innovus implementation result can be summarized as:

| Metric | Result |
|---|---:|
| Setup WNS | **+0.122 ns** |
| Setup TNS | **0.000 ns** |
| Setup violations | **0** |
| Hold WNS | **+0.001 ns** |
| Hold TNS | **0.000 ns** |
| Hold violations | **0** |
| Max-cap violations | **0** |
| Max-tran violations | **0** |
| Max-fanout violations | **0** |
| Max-length violations | **0** |
| DRC violations | **0** |
| Connectivity | **PASS** |
| Standard-cell density | **12.419%** |


## 39. Final Physical Database

The completed implementation used for backend timing and power analysis is the
final Iter4B physical database.

Its implementation checkpoint is restored by the final backend and power
scripts before extraction or analysis.

This protects the completed routed design while allowing the analysis stages to
generate fresh output artifacts.


## 40. Parasitic Extraction

Final parasitic extraction is performed for both physical RC extremes.

The implemented RC corners are:

    SlowRC
    FastRC

Before each extraction:

    reset_parasitics

is executed, followed by:

    extractRC

The extracted parasitic information is written in SPEF format for external
static timing analysis.


## 41. SlowRC Extraction

The slow parasitic model uses the TSMC:

    cworst

QRC technology at:

    125 C

The resulting handoff file is:

    top_slow.SPEF

This parasitic view is used for maximum-delay / setup-oriented analysis.


## 42. FastRC Extraction

The fast parasitic model uses the TSMC:

    cbest

QRC technology at:

    -40 C

The resulting handoff file is:

    top_fast.SPEF

This parasitic view is used for minimum-delay / hold-oriented analysis.


## 43. PrimeTime Netlist Handoff

The final physical database is exported as a flat timing netlist using:

    saveNetlist

with:

    -flat
    -removePowerGround

The resulting timing netlist is:

    top_post_layout.v

This representation contains the physically implemented cell and routing-related
ECO structure required by final static timing analysis.


## 44. PrimeTime Handoff Package

The final PrimeTime handoff contains three primary files:

| File | Purpose |
|---|---|
| `top_post_layout.v` | Flat post-layout timing netlist |
| `top_slow.SPEF` | SlowRC extracted parasitics |
| `top_fast.SPEF` | FastRC extracted parasitics |

The handoff-generation script verifies that each output exists and is non-empty
before reporting completion.


## 45. Physical-Design Source Map

The principal physical-design scripts are:

| Path | Function |
|---|---|
| `innovus/scripts/full.tcl` | Complete P&R sequence |
| `innovus/scripts/init.tcl` | Design import and initialization |
| `innovus/scripts/fp.tcl` | Die/core floorplan and I/O filler insertion |
| `innovus/scripts/glnets.tcl` | Global core/pad power connection |
| `innovus/scripts/power87.tcl` | Core ring and stripe generation |
| `innovus/scripts/place.tcl` | Placement, tie cells and PG stitching |
| `innovus/scripts/cts.tcl` | CCOpt clock-tree synthesis |
| `innovus/scripts/report_final_cts.tcl` | Final routed CCOpt clock-tree report |
| `innovus/scripts/route.tcl` | Routing and post-route optimization |
| `innovus/scripts/write_data.tcl` | Fillers, final repair and extraction |
| `innovus/scripts/apply_hold_eco_29.tcl` | Main data-hold closure |
| `innovus/scripts/apply_hold_eco_iter2.tcl` | Focused data-hold closure |
| `innovus/scripts/apply_clock_gating_eco_iter3.tcl` | Clock-gating hold closure |
| `innovus/scripts/apply_scan_en_fix_iter4b.tcl` | Scan-enable electrical closure |
| `innovus/scripts/backend_prep_hold_eco_iter4b.tcl` | Final PrimeTime handoff |


## 46. Physical-Design Reports

Curated final implementation reports are stored under:

    results/innovus/

The principal summaries are:

    final_setup_summary.txt
    final_hold_summary.txt
    final_drc.rpt
    final_connectivity.rpt
    final_cts_ccopt.rpt
    physical_design_summary.txt

Detailed final Innovus timing and electrical reports are stored under:

    results/innovus/final_stage_full/


## 47. Reproducible Final ECO Flow

The four final closure stages are wrapped by:

    innovus/run_final_eco.tcsh

This runner applies the validated ECO sequence in the required order and checks
for a completion marker after each physical stage.

The final backend handoff is then generated using:

    make backend_prep_final

This produces the extracted timing package consumed by PrimeTime.


## 48. Physical-Design Summary

The CUBIC ASIC physical implementation completes the transition from the
synthesized padded design to a routed TSMC 28 nm implementation with final
electrical and timing closure.

The final design uses an 880 x 880 um die and a 560 x 560 um standard-cell core.

Power is distributed through a dedicated M8/M9 ring-and-stripe network, and the
functional clock is distributed to 1138 sinks using Cadence CCOpt.

Post-route timing and electrical closure is completed using focused ECO
insertions while preserving physical connectivity and DRC cleanliness.

The final Innovus implementation reports:

    Setup WNS        = +0.122 ns
    Hold WNS         = +0.001 ns
    Timing violations= 0
    Electrical DRVs  = 0
    DRC violations   = 0
    Connectivity     = PASS

SlowRC and FastRC parasitic models are extracted from the completed physical
database and exported together with the flat post-layout netlist for final
PrimeTime static timing analysis.
