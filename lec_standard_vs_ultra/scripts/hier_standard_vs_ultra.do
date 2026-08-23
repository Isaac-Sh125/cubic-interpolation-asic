// ============================================================================
// Current-project gate-to-gate LEC
// Golden  : standard compile -gate_clock + scan
// Revised : compile_ultra -gate_clock + scan
// ============================================================================

set log file ../logfile/lec_standard_vs_ultra.log -replace

// TSMC 28 nm standard-cell library
read library -Both -Replace -sensitive -Statetable -Liberty \
    /data/tsmc/28HPCPMMWAVE/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140ssg0p81v125c.lib

// GOLDEN = current standard-compile + scan netlist
read design ../../synthesis_standard_verify/dataout/ASIC_Top_netlist.v \
    -Verilog -Golden -sensitive \
    -continuousassignment Bidirectional \
    -nokeep_unreach

// REVISED = current final compile_ultra + scan netlist
read design ../../synthesis/dataout/ASIC_Top_netlist.v \
    -Verilog -Revised -sensitive \
    -continuousassignment Bidirectional \
    -nokeep_unreach -nosupply

// Both designs contain the scan interface.
// Force functional mode for the comparison.
add pin constraints 0 scan_en -Both
add pin constraints 0 scan_in1 scan_in2 scan_in3 -Both
add ignore outputs scan_out1 scan_out2 scan_out3 -Both

// Account for clock-gating implementation differences.
set flatten model -gated_clock

uniquify -all

// Generate hierarchical comparison dofile with datapath analysis.
write hier_compare dofile hier_standard_vs_ultra_compare.do \
    -replace \
    -prepend_string "analyze datapath -module -threads 4; usage; analyze datapath -wordlevel -verbose"

set dofile abort OFF

// This is the comparison where high solver effort is required.
set analyze option -auto
set compare effort high

run hier_compare hier_standard_vs_ultra_compare.do
