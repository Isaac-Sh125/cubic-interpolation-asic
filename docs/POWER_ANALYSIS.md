# Power Analysis

## 1. Overview

Final post-route power analysis of the CUBIC Interpolation DSP ASIC is
performed on the completed Cadence Innovus physical implementation.

The analysis uses switching activity captured from gate-level simulation rather
than assigning a uniform vectorless activity factor to the complete design.

A separate SAIF file is generated for each supported interpolation mode:

    L = 2
    L = 3
    L = 4
    L = 5

This allows the final power results to reflect the different switching behavior
and sample-processing rate of each operating configuration.


## 2. Final Physical Database

Power analysis is performed on the completed routed physical database:

    final_hold_eco_iter4b_trial

The power script explicitly restores:

    innovus/dataout/design_saves/final_hold_eco_iter4b_trial.dat

before beginning activity annotation and power calculation.

Therefore, the reported power results correspond to the same completed
post-route implementation used for the final backend timing handoff.


## 3. Analysis Script

The final power flow is implemented in:

    innovus/scripts/power_saif_final_iter4b.tcl

The script performs the following principal operations:

    restore final physical database
              |
              v
       load MMMC environment
              |
              v
       apply PG connectivity
              |
              v
          extract RC
              |
              v
       read per-L SAIF file
              |
              v
      annotate core activity
              |
              v
        report chip power
              |
              v
       report block power
              |
              v
     generate per-L summary


## 4. Power Analysis Method

Cadence Innovus is configured for static power analysis using switching
activity provided by SAIF.

The analysis mode is configured with:

    method = static

and uses the physical implementation together with extracted RC information.

This is therefore a post-route, activity-annotated power analysis rather than a
pre-layout vectorless estimate.


## 5. Analysis Corner

The final SAIF-based power analysis uses:

    SlowView

The corresponding core timing condition is:

    SS
    0.81 V
    125 C

and the physical parasitic condition is:

    SlowRC
    cworst

The I/O power rails operate at their associated pad-domain voltage for this
corner.


## 6. Activity Source

Switching activity is captured from gate-level simulation of the DSP core.

The generated activity files are:

    innovus/datain/saif/core_L2.saif
    innovus/datain/saif/core_L3.saif
    innovus/datain/saif/core_L4.saif
    innovus/datain/saif/core_L5.saif

Each file represents operation of the actual gate-level design using stimulus
for the corresponding interpolation factor.


## 7. SAIF-to-Physical Hierarchy Mapping

The gate-level simulation hierarchy and physical hierarchy use different
top-level paths.

The simulation DUT is:

    design_tb/dut

while the physical DSP core is instantiated as:

    I0

The final power script therefore maps:

    SAIF scope  : design_tb/dut
    Innovus block: I0

This allows gate-level activity to be transferred onto the corresponding
physical standard-cell hierarchy.


## 8. Annotation Coverage

The final activity reports show:

    Annotated objects : 47,764
    Total objects     : 48,596

which corresponds to:

    98.287926%

annotation coverage.

The same high annotation coverage is observed in the retained per-L power
reports.

This confirms that the gate-level SAIF hierarchy is mapped successfully onto
the physical DSP implementation.


## 9. Per-Mode Power Analysis

Power is evaluated independently for all four supported interpolation factors.

The resulting whole-chip and DSP-core power values are:

| L | Whole-Chip Power | DSP Core `I0` |
|---:|---:|---:|
| 2 | 22.9837 mW | 4.3920 mW |
| 3 | 28.8508 mW | 5.0040 mW |
| 4 | 34.9646 mW | 5.7110 mW |
| 5 | **40.3975 mW** | **6.2380 mW** |


## 10. Power Scaling with Interpolation Factor

The measured activity-based power increases with interpolation factor.

The whole-chip result increases from:

    22.9837 mW at L=2

to:

    40.3975 mW at L=5

The DSP core similarly increases from:

    4.3920 mW at L=2

to:

    6.2380 mW at L=5

This trend is consistent with the architecture of the interpolator.

The reconstructed input rate remains approximately 60 MS/s, while increasing L
produces more interpolated output events per input interval.


## 11. Output Event Rate

The effective interpolated output rates are:

| L | Output Event Rate |
|---:|---:|
| 2 | 120 MS/s |
| 3 | 180 MS/s |
| 4 | 240 MS/s |
| 5 | 300 MS/s |

The higher event rate causes downstream valid-driven processing to advance more
frequently.

In particular, the FIR state advances only when a valid interpolated sample is
presented.

Therefore, increasing L increases active DSP switching without changing the
fundamental high-frequency system-clock architecture.


## 12. FIR Power Scaling

The I-channel FIR power shows a clear increase with L:

| L | FIR-I Power |
|---:|---:|
| 2 | 0.7344 mW |
| 3 | 1.0020 mW |
| 4 | 1.3320 mW |
| 5 | 1.5480 mW |

This behavior follows the increasing frequency of `x_valid` sample events
presented to the FIR.

The FIR accumulator state remains inactive during clock cycles without valid
interpolated data.


## 13. Interpolator Power

The interpolator power varies less strongly with interpolation factor than the
FIR power.

The retained I-channel interpolator results are:

| L | Interpolator-I Power |
|---:|---:|
| 2 | 1.1970 mW |
| 3 | 1.2270 mW |
| 4 | 1.2200 mW |
| 5 | 1.2590 mW |

The interpolation engine operates at the reconstructed input-sample cadence,
while the selected number of generated interpolation lanes changes with L.


## 14. Highest-Rate Operating Mode

L=5 is the highest-output-rate configuration.

For this mode:

    input sample rate  = approximately 60 MS/s
    output event rate  = approximately 300 MS/s

The L=5 case also produces the highest measured whole-chip and core power of the
four analyzed operating configurations.

The final L=5 whole-chip result is:

    40.39749739 mW


## 15. L5 Whole-Chip Power Breakdown

The detailed L=5 report gives:

| Component | Power | Percentage |
|---|---:|---:|
| Internal | 26.65038128 mW | 65.9704% |
| Switching | 11.66117741 mW | 28.8661% |
| Leakage | 2.08593870 mW | 5.1635% |
| **Total** | **40.39749739 mW** | **100%** |

Internal power is therefore the largest component in the final padded-chip
L=5 power result.


## 16. Internal Power

The final L=5 internal-power component is:

    26.65038128 mW

Internal power includes energy dissipated inside characterized library cells
during state transitions and clock/data activity.

For the complete padded chip this contribution is strongly influenced by the
I/O and pad-domain cells in addition to the DSP core.


## 17. Switching Power

The final L=5 net-switching contribution is:

    11.66117741 mW

This component represents capacitive charging and discharging associated with
the switching nets of the routed implementation.

The result includes the activity-dependent contribution of both the core and
pad-integrated signal network.


## 18. Leakage Power

The final L=5 leakage component is:

    2.08593870 mW

Leakage accounts for:

    5.1635%

of the reported whole-chip L=5 power.

The DSP-core hierarchy contains most of this reported leakage contribution.


## 19. Power by Supply Rail

The L=5 report also separates power by supply rail.

| Rail | Voltage | Total Power | Chip Percentage |
|---|---:|---:|---:|
| POC | 1.62 V | 23.68 mW | 58.61% |
| VDDP | 1.62 V | 9.787 mW | 24.23% |
| VDDC | 0.81 V | 6.932 mW | 17.16% |

The largest individual contribution is associated with the POC rail.


## 20. POC Rail

For L=5, the POC rail reports approximately:

    Internal power  = 23.66 mW
    Switching power = 0 mW
    Leakage power   = 0.01366 mW
    Total power     = 23.68 mW

This rail accounts for:

    58.61%

of the complete reported chip power.


## 21. VDDP Rail

The L=5 VDDP rail reports:

    Switching power = 9.787 mW
    Total power     = 9.787 mW

This represents:

    24.23%

of the whole-chip power result.


## 22. VDDC Core Rail

The core supply rail `VDDC` reports:

    Internal power  = 2.986 mW
    Switching power = 1.874 mW
    Leakage power   = 2.072 mW
    Total power     = 6.932 mW

This represents:

    17.16%

of the final whole-chip L=5 power.


## 23. Hierarchical Core Power

Power is also reported by physical hierarchy.

For the complete DSP core instance:

    I0

the L=5 result is:

| Component | Power |
|---|---:|
| Internal | 2.355 mW |
| Switching | 1.831 mW |
| Leakage | 2.052 mW |
| Total | **6.238 mW** |

The core instance accounts for:

    15.44%

of the complete L=5 padded-chip result.


## 24. Rail and Hierarchical Views

The rail-based and hierarchy-based power reports answer different questions.

The rail report classifies energy according to physical power supply.

The hierarchy report classifies energy according to design instance.

Therefore:

    VDDC power = 6.932 mW

and:

    I0 core power = 6.238 mW

are related but are not expected to be numerically identical.

The first includes all power associated with the VDDC supply rail, while the
second is restricted to the `I0` hierarchy.


## 25. I-Channel Interpolator Power

For L=5:

    I0/u_path_I_u_interp

reports:

| Component | Power |
|---|---:|
| Internal | 0.1942 mW |
| Switching | 0.1947 mW |
| Leakage | 0.8701 mW |
| Total | **1.259 mW** |


## 26. Q-Channel Interpolator Power

For L=5:

    I0/u_path_Q_u_interp

reports:

| Component | Power |
|---|---:|
| Internal | 0.1984 mW |
| Switching | 0.1936 mW |
| Leakage | 0.8741 mW |
| Total | **1.266 mW** |

The I and Q interpolation paths therefore exhibit closely matched power, as
expected from their structurally symmetric RTL implementations.


## 27. I-Channel FIR Power

For L=5:

    I0/u_path_I_u_fir

reports:

| Component | Power |
|---|---:|
| Internal | 0.8220 mW |
| Switching | 0.5824 mW |
| Leakage | 0.1434 mW |
| Total | **1.548 mW** |


## 28. Q-Channel FIR Power

For L=5:

    I0/u_path_Q_u_fir

reports:

| Component | Power |
|---|---:|
| Internal | 0.8210 mW |
| Switching | 0.5872 mW |
| Leakage | 0.1435 mW |
| Total | **1.552 mW** |

The two FIR paths also show closely matched activity-based power.


## 29. I/Q Structural Symmetry

The power results provide an additional consistency check on the dual-channel
architecture.

At L=5:

    Interpolator I = 1.259 mW
    Interpolator Q = 1.266 mW

and:

    FIR I = 1.548 mW
    FIR Q = 1.552 mW

The small differences arise from the actual independent I/Q switching activity,
while the overall similarity reflects the identical RTL structure used for the
two channels.


## 30. Whole-Chip vs Core Power

For L=5:

    Whole chip = 40.3975 mW
    Core I0    =  6.2380 mW

The core therefore represents only a minority of the final padded-chip power.

This is consistent with the rail breakdown, which shows substantial
contribution from the 1.62 V pad-related power domains.

The final whole-chip value must therefore not be interpreted as the power of the
DSP standard-cell core alone.


## 31. Comparison with Synthesis Power Estimate

Design Compiler reported a pre-layout estimate of approximately:

    2.0881 mW

during logic synthesis.

That result and the final Innovus whole-chip power result are generated under
different analysis conditions.

The synthesis estimate uses:

    pre-layout design
    synthesis timing/power model
    ZeroWireload interconnect assumption
    low-effort power analysis

The final Innovus result uses:

    completed padded physical implementation
    extracted post-route RC
    pad and core power domains
    SAIF-based gate-level switching activity

Therefore, the synthesis estimate and final post-route whole-chip result should
not be compared as equivalent power measurements.


## 32. Core-Oriented Comparison

Even the final post-route core value:

    6.2380 mW at L=5

is not directly equivalent to the synthesis estimate because the activity and
physical parasitic assumptions are different.

The synthesis value is useful as an early implementation estimate.

The SAIF-annotated post-route analysis is used as the final project power
characterization.


## 33. Importance of SAIF Activity

A uniform vectorless activity factor cannot accurately represent the
valid-driven behavior of this architecture.

Examples include:

- clock-gated register groups;
- the 60 MS/s interpolator update cadence;
- the L-dependent P2S output cadence;
- the valid-driven FIR accumulator.

SAIF activity captures the switching behavior observed during actual gate-level
simulation and therefore provides a more representative activity model for the
implemented DSP modes.


## 34. Clock Gating and Activity

The synthesized implementation contains clock-gated state.

When the corresponding enable condition is inactive, unnecessary sequential
clock activity is reduced.

Because the power analysis uses gate-level SAIF data, this lower activity is
reflected in the annotated switching behavior rather than being replaced by a
uniform assumed switching factor.


## 35. Power Analysis Artifacts

The final retained reports are stored under:

    results/power/final_iter4b/

The directory contains whole-chip reports:

    chip_L2.rpt
    chip_L3.rpt
    chip_L4.rpt
    chip_L5.rpt

core reports:

    core_L2.rpt
    core_L3.rpt
    core_L4.rpt
    core_L5.rpt

and separate reports for:

    interp_I
    interp_Q
    fir_I
    fir_Q

for every supported L.


## 36. Power Summary Artifacts

The compact automatically generated per-L table is:

    results/power/final_iter4b/saif_summary.txt

The curated final interpretation is:

    results/power/final_iter4b/power_interpretation_summary.txt

These provide rapid access to the principal project power results while the
full reports preserve the detailed analysis evidence.


## 37. Reproducing Power Analysis

The final power flow can be launched from the project root using:

    make power

The target executes the final Iter4B SAIF-based power analysis on the completed
physical database.

The script verifies the presence of the per-L SAIF activity files and generates
independent reports for the four supported interpolation factors.


## 38. Final Power Result

The highest-power supported operating configuration is L=5.

Its final post-route SAIF-based result is:

    Whole-chip power = 40.3975 mW

with DSP-core power of:

    Core I0 power = 6.2380 mW

The complete whole-chip L=5 breakdown is:

    Internal  = 26.65038128 mW
    Switching = 11.66117741 mW
    Leakage   =  2.08593870 mW
    Total     = 40.39749739 mW

The activity annotation coverage is:

    98.287926%

The complete L=2 through L=5 results and detailed block reports are preserved in
the repository.


## 39. Power Analysis Summary

The final power-analysis methodology combines the completed routed physical
implementation with activity obtained from gate-level simulation.

All four interpolation modes are analyzed independently using their own SAIF
activity files.

Whole-chip power increases from:

    22.9837 mW at L=2

to:

    40.3975 mW at L=5

while the DSP core increases from:

    4.3920 mW

to:

    6.2380 mW

over the same operating range.

The results show the effect of interpolation-dependent activity on the core
datapath and also demonstrate that the pad-integrated power domains contribute
substantially to the final whole-chip power result.

## 40. Final Core-Domain IR-Drop Analysis

A final static rail analysis is performed on the completed Iter4B routed
implementation.

The retained analysis uses:

    database       : final_hold_eco_iter4b_trial
    activity       : L=5 gate-level SAIF
    SAIF mapping   : design_tb/dut -> I0
    analysis view  : SlowView
    library corner : SS, 0.81 V, 125 C
    RC condition   : cworst
    power domain   : VDDC / VSSC
    rail model     : run-local 28 nm tech-only PGV

L=5 is used because it is the highest-rate and highest-power supported operating
mode in the retained SAIF characterization.

The rail PGV is stored inside the IR-analysis output directory rather than using
the older shared PGV database.


## 41. Final IR-Drop Result

The final analyzed core-domain result is:

| Metric | Result |
|---|---:|
| Nominal VDDC | 0.810 V |
| Minimum VDDC node voltage | approximately 0.807 V |
| Worst VDDC drop | approximately 3.00 mV |
| VDDC drop / nominal supply | approximately 0.37% |
| Maximum VSSC ground bounce | approximately 2.55 mV |
| Minimum effective instance voltage | approximately 0.805 V |
| Effective total drop | approximately 5.00 mV |
| Effective drop / nominal VDDC | approximately 0.62% |
| Voltage-threshold violations | 0 |

The VDDC threshold used by the project-level check is:

    0.7695 V

which corresponds to 95% of the 0.81 V nominal core supply.

The reported "worst" drop is the worst spatial location within the analyzed
SlowView. It should not be interpreted as an exhaustive sweep over every
possible power/rail PVT condition.


## 42. Rail-Solver Integrity and Scope

The final Voltus rail solver reports:

    Current taps matched    : 39,509 / 39,509 (100.00%) on both rails
    Dropped voltage sources : 0
    Voltus warnings         : 0
    Voltus errors           : 0

The final VDDC rail current is approximately:

    7.739 mA

At 0.81 V this corresponds to approximately:

    6.27 mW

which is close to the independently reported L=5 DSP-core hierarchy power:

    I0 power = 6.2380 mW

This agreement provides an additional consistency check that the analyzed rail
load represents the DSP core power at the expected magnitude.

The fully padded top-level tech-only-PGV representation still reports physically
disconnected pad-ring/filler/pad/corner sections. The retained integrity reports
contain 2,248 such top-level instances on each analyzed rail, but:

    physically disconnected instances inside I0 = 0

Voltus also reports disconnected current-source/node sections associated with
the same top-level representation. These counts are retained in the raw reports
rather than hidden.

For this reason the project result is stated as a successful **core-domain static
IR analysis under the documented tech-only-PGV model**. It is not claimed as
unrestricted full-chip commercial rail signoff.


## 43. IR Analysis Artifacts

The final IR script is:

    innovus/scripts/ir_rail_final_iter4b_l5.tcl

The curated interpretation is:

    results/innovus/final_ir_drop_summary.txt

The tool-generated final summary is:

    results/innovus/final_ir_tool_summary.txt

Retained raw evidence includes:

    results/innovus/final_ir_vddc.rpt
    results/innovus/final_ir_vssc.rpt
    results/innovus/final_ir_vddc_pg_integrity.rpt
    results/innovus/final_ir_vssc_pg_integrity.rpt
    results/innovus/final_ir_voltus_rail.txt


## 44. Reproducing IR Analysis

From the project root, run:

    make ir

The target restores the final Iter4B routed database, annotates the L=5
gate-level SAIF activity, generates static VDDC/VSSC current data, generates or
reuses the run-local 28 nm tech-only PGV model, places ideal voltage sources at
the identified core-supply pads, and runs static Voltus rail analysis on the
VDDC/VSSC core domain.
