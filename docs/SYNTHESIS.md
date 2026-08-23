# Logic Synthesis

## 1. Overview

The synthesizable RTL of the CUBIC Interpolation DSP ASIC is mapped into a
TSMC 28 nm standard-cell implementation using Synopsys Design Compiler.

Logic synthesis performs the transition from the technology-independent RTL
architecture into a gate-level representation suitable for functional
gate-level verification and subsequent physical implementation.

The synthesis flow includes:

- RTL analysis and elaboration;
- timing constraint application;
- path-group definition;
- high-effort logic optimization;
- automatic clock-gating insertion;
- standard-cell technology mapping;
- timing, area and power reporting;
- scan-chain integration;
- final gate-level netlist generation;
- generation of implementation handoff constraints and test collateral.

The complete synthesis procedure is implemented in:

    synthesis/scripts/synthesis.tcl


## 2. Synthesis Tool

The implementation was synthesized using:

    Synopsys Design Compiler
    Version X-2025.06-SP4

The final synthesis reports are preserved under:

    results/synthesis/

The principal synthesis reports are:

    post_elaborate.rpt
    post_compile.rpt
    post_scan_chain.rpt
    area_summary.txt


## 3. Target Technology

The standard-cell mapping target is the TSMC 28 nm HPC+ library.

The target library used by Design Compiler is:

    tcbn28hpcplusbwp30p140ssg0p81v125c.db

The associated synthesis operating condition is:

    Process corner : SSG
    Core voltage   : 0.81 V
    Temperature    : 125 C

This slow operating corner is used for the synthesis optimization and
pre-layout timing analysis.

DesignWare support is enabled through:

    dw_foundation.sldb

The synthesis link environment therefore combines the TSMC standard-cell
library and the Synopsys DesignWare synthetic library.


## 4. RTL Input Set

The complete synthesizable RTL hierarchy is read by the synthesis flow.

Input RTL files are:

| File | Function |
|---|---|
| `Control_Unit.v` | Configuration and timing control |
| `SIPO.v` | Serial-to-parallel sample reconstruction |
| `Interpolator.v` | Cubic interpolation datapath |
| `P2S_Interpolator.v` | Interpolation-output scheduler |
| `FIR_LPF_TRANSPOSED.v` | Configurable ten-tap FIR |
| `MinAJ2_Datapath.v` | Per-channel DSP hierarchy |
| `ASIC_top.v` | Complete I/Q top-level integration |

The top-level synthesis design is:

    ASIC_Top

The RTL is analyzed as SystemVerilog-compatible source and elaborated before
technology mapping.


## 5. Elaboration and Design Linking

The synthesis flow first performs RTL analysis and top-level elaboration.

The elaborated design is linked against the target standard-cell and DesignWare
libraries before optimization.

A post-elaboration report is generated before the main compile stage and
contains:

- maximum-delay timing analysis;
- minimum-delay timing analysis;
- area information;
- constraint checks;
- design consistency checks.

An initial Design Compiler database is also preserved as:

    synthesis/dataout/initial_ASIC_Top.ddc

This provides a synthesis-stage representation of the elaborated design before
the final optimization and scan-insertion steps.


## 6. Clock Constraint

The complete ASIC implementation is synthesized against a single high-frequency
system clock.

The synthesis constraint is:

    Clock name   : clk
    Clock period : 1.04 ns

The corresponding implementation frequency is approximately:

    961.5 MHz

The clock waveform is defined with a nominal 50% duty cycle:

    rising edge  : 0.00 ns
    falling edge : 0.52 ns

This timing target covers the highest-frequency functional operating mode of
the design.


## 7. Timing Margins

The synthesis clock constraints include explicit timing margins:

    Clock uncertainty : 0.05 ns
    Clock transition  : 0.05 ns

The clock uncertainty is included in timing requirements to reserve margin for
clock-related uncertainty before physical clock-tree implementation.

The clock-transition value provides the synthesis engine with a defined clock
slew assumption for timing optimization.


## 8. I/O Timing Constraints

External input and output interfaces are constrained relative to the system
clock.

The synthesis SDC defines:

    Maximum input delay  : 0.20 ns
    Maximum output delay : 0.20 ns

The input constraint applies to all functional input ports except the clock
source itself.

These constraints model the timing budget assigned to the external interface
while reserving the remaining clock period for internal logic.


## 9. Timing Path Groups

The synthesis flow explicitly separates timing paths into groups so that the
optimization engine can independently consider the major interface classes.

The configured groups include:

    IN
    OUT
    FEEDTHR

These represent:

- input-to-register paths;
- register-to-output paths;
- input-to-output feed-through paths.

Register-to-register paths remain associated with the primary clock path group.

Path grouping improves timing visibility and provides structured optimization
across the different path classes.


## 10. Multicycle Timing Architecture

The RTL contains functional state that is intentionally updated at a lower rate
than the high-frequency system clock.

Rather than requiring these paths to complete as single-cycle paths, the
synthesis constraints preserve timing analysis while assigning the cycle budget
that corresponds to the functional update cadence.

Two principal multicycle classes are used.


## 11. Interpolator Multicycle Paths

The cubic interpolator output registers are updated only when the reconstructed
input-sample timing event occurs.

The synthesis constraints applied to the interpolation output registers are:

    Setup multicycle : 14 cycles
    Hold multicycle  : 13 cycles

Target registers include the generated interpolation result registers:

    y0
    y1
    y2
    y3
    y4

in both the I and Q datapaths.

These constraints reflect the lower update rate of the interpolation result
state relative to the system clock.


## 12. FIR Multicycle Paths

The FIR state advances only when a valid interpolated sample is presented by
the P2S scheduler.

The highest output-event density occurs in L=5 operation, where a new valid
sample is scheduled every three system-clock cycles.

The FIR timing constraints are therefore:

    Setup multicycle : 3 cycles
    Hold multicycle  : 2 cycles

This preserves timing analysis of the FIR datapath while matching its
valid-driven sample-processing cadence.


## 13. Pre-Compile Optimization Settings

Before `compile_ultra`, the flow configures several synthesis behaviors for the
DSP hierarchy.

The design preserves its hierarchical register organization by disabling
register merging for the top-level design.

This maintains stable structural correspondence between the RTL and synthesized
representations and supports hierarchical equivalence verification.

Constant propagation through combinational logic is enabled while sequential
mapping behavior is controlled explicitly.

Multiple-port nets and constants are normalized before final netlist
generation.


## 14. Clock-Gating Optimization

Automatic clock gating is enabled during high-effort synthesis.

The synthesis flow configures latch-based clock gating with:

    minimum gated width = 3 bits

and invokes:

    compile_ultra -gate_clock

This allows Design Compiler to identify groups of registers sharing common
enable behavior and implement clock gating where appropriate.

The generated synthesized netlist contains seven
`SNPS_CLOCK_GATE_HIGH` structures associated with control and datapath state.

Clock-gated structures appear in blocks including:

- control configuration state;
- interpolation state;
- FIR output state;
- SIPO state.

Clock gating reduces unnecessary sequential clock activity when the associated
state is not enabled.


## 15. High-Effort Logic Compilation

The principal synthesis operation is:

    compile_ultra -gate_clock

`compile_ultra` performs technology mapping and aggressive timing-oriented logic
optimization while simultaneously applying the configured clock-gating
strategy.

The output of this stage is the post-compile standard-cell implementation used
as the basis for pre-scan timing, area and power reporting.


## 16. Post-Compile Cell Count

After `compile_ultra`, the synthesized design contains:

    Number of cells = 38,840

This count represents the standard-cell implementation before the scan-chain
insertion stage.


## 17. Post-Compile Area

The post-compile area report gives:

| Area Category | Reported Area |
|---|---:|
| Combinational | 36,127.097678 |
| Buffer / Inverter | 987.210015 |
| Non-combinational | 2,573.927873 |
| Total cell area | **38,701.025551** |

The values are reported in the area units defined by the mapped standard-cell
library.

No macro or black-box area is included in this core synthesis result.


## 18. Post-Compile Setup Timing

The maximum-delay timing analysis reports all displayed timing paths as MET.

The most timing-critical reported register-to-register path has:

    Setup slack = +0.05 ns

The reported critical path originates from configuration state in the control
unit and terminates in the Q-channel FIR accumulator hierarchy.

The path is analyzed using the FIR multicycle timing requirement.

Positive setup slack at this stage indicates that the mapped core satisfies the
specified pre-layout setup requirement under the synthesis timing model.


## 19. Post-Compile Hold Timing

Minimum-delay timing analysis is also generated after synthesis.

The worst displayed hold result is reported as:

    Hold slack = +0.00 ns

at the report precision used by Design Compiler.

Final hold closure is subsequently evaluated using routed parasitics during
physical implementation and final PrimeTime analysis.


## 20. Pre-Layout Power Estimate

Design Compiler also produces a pre-layout power estimate after logic
compilation.

The report uses:

    Operating corner : SSG, 0.81 V, 125 C
    Analysis effort  : low
    Wire-load model  : ZeroWireload

The reported power components are:

| Component | Power |
|---|---:|
| Cell internal power | 146.9005 uW |
| Net switching power | 39.6698 uW |
| Total dynamic power | **186.5703 uW** |
| Cell leakage power | **1.9015 mW** |

The combined synthesis-level estimate is approximately:

    2.0881 mW

This value is a pre-layout synthesis estimate and is not used as the final ASIC
power result.

Final power analysis is performed after physical implementation using extracted
design data and measured SAIF switching activity. That analysis is documented
separately in `POWER_ANALYSIS.md`.


## 21. Scan Interface

After the primary synthesis optimization stage, the flow adds a scan-test
interface.

The test ports are:

    scan_en

    scan_in1
    scan_in2
    scan_in3

    scan_out1
    scan_out2
    scan_out3

The functional system clock is also defined as the scan clock for the generated
test structure.


## 22. Scan Configuration

The scan architecture uses:

    multiplexed-flip-flop scan style

and is configured for:

    3 scan chains

Design Compiler creates the test protocol and performs DFT rule checking before
scan insertion.

The final ScanDEF confirms:

    SCANCHAINS 3

with independent input/output pairs:

    scan_in1 -> scan_out1
    scan_in2 -> scan_out2
    scan_in3 -> scan_out3


## 23. Generated Scan Structure

The final synthesized netlist contains:

    42 SDFCNQD0BWP30P140 scan flip-flops

The generated ScanDEF distributes these cells evenly across the three chains:

    Chain 1 : 14 scan cells
    Chain 2 : 14 scan cells
    Chain 3 : 14 scan cells

The resulting 42 scan cells do **not** represent full-scan coverage. The DFT
analysis reported 1,138 sequential elements in the design, while only 42 cells
were valid and accessible for scan insertion. Most of the remaining sequential
elements are located behind clock-gated branches without a dedicated test-mode
clock-gating bypass.

The final synthesized implementation therefore contains three 14-cell scan chains as a
**partial scan insertion**. A future full-DFT implementation should make the
clock-gating structure test-aware so that the remaining sequential elements can
be reached during scan operation.

The scan structure includes selected control, scheduler, FIR-valid and
top-level sequential state.

The ScanDEF is exported for physical implementation, allowing Innovus to retain
the generated scan-chain connectivity information during placement and routing.


## 24. Post-Scan Cell Count

After scan insertion, the standard-cell count becomes:

    Number of cells = 38,841

The scan stage therefore produces the final synthesized implementation used for
the gate-level and backend handoff.


## 25. Post-Scan Area

The post-scan area report gives:

| Area Category | Reported Area |
|---|---:|
| Combinational | 36,132.641678 |
| Buffer / Inverter | 992.754015 |
| Non-combinational | 2,600.387877 |
| Total cell area | **38,733.029556** |

The post-scan total cell area is used as the principal synthesis-area result in
the project summary.


## 26. Post-Scan Timing

The post-scan timing reports retain approximately the same limiting margins as
the post-compile design.

The reported critical setup slack is:

    +0.05 ns

and the minimum-delay result is approximately:

    +0.00 ns

at the report precision used during synthesis.

These values are pre-layout timing results. Final setup and hold closure is
evaluated after placement, clock-tree synthesis, routing and parasitic
extraction using the physical implementation.


## 27. Generated Synthesis Artifacts

The synthesis flow exports the following principal implementation artifacts:

| Artifact | Function |
|---|---|
| `ASIC_Top_netlist.v` | Final mapped gate-level netlist |
| `ASIC_Top.sdc` | Exported synthesis timing constraints |
| `scandef` | Three-chain scan definition |
| `ASIC_Top.spf` | Generated test protocol |
| `initial_ASIC_Top.ddc` | Pre-compile Design Compiler database |
| `final_ASIC_Top.ddc` | Final Design Compiler database |

The final gate-level netlist is approximately 4.9 MB and forms the functional
core used by the subsequent gate-level verification and physical-design stages.


## 28. Backend Handoff

The mapped netlist and associated implementation collateral are transferred to
the physical-design environment.

The principal handoff includes:

    gate-level Verilog
    timing constraints
    scan-chain definition

The pad-integrated top-level design is then constructed around the synthesized
core before Innovus physical implementation.

The scan definition is preserved as part of the backend input set.


## 29. Synthesis Verification

Two independent verification mechanisms are used to validate the synthesis
transition.

First, the synthesized gate-level netlist is simulated using the same primary
L=5 regression stimulus as the RTL.

The complete 49,978-sample gate-level output is byte-identical to the canonical
golden output.

Second, hierarchical logical equivalence checking is performed between the RTL
and synthesized representation.

The validated LEC result reports:

    12 / 12 module pairs equivalent
    NEQ   = 0
    ABORT = 0

These results verify that the synthesis transformation preserves the intended
digital functionality.


## 30. Synthesis Result Summary

The final synthesis stage establishes a technology-mapped TSMC 28 nm
implementation suitable for physical design.

Key post-scan results are:

| Metric | Result |
|---|---:|
| Standard-cell count | **38,841** |
| Total cell area | **38,733.029556** |
| Reported setup slack | **+0.05 ns** |
| Reported hold slack | **+0.00 ns** |
| Scan chains | **3** |
| Scan cells | **42** |
| Generated clock-gating structures | **7** |

The post-compile pre-layout power estimate is approximately 2.0881 mW under the
synthesis analysis assumptions.

Final timing and power signoff are performed after physical implementation and
are documented separately in the physical-design, static-timing and power
analysis documentation.
