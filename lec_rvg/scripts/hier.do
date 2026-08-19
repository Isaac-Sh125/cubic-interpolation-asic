// Open a logfile and replace the existing logfile (if exists)
set log file ../logfile/lec_run.log -replace

set compare effort low

// Read the TSMC 28nm standard cell library
read library -Both -Replace -sensitive -Statetable -Liberty \
    /data/tsmc/28HPCPMMWAVE/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140ssg0p81v125c.lib

// GOLDEN RTL
read design ../datain/RTL/Control_Unit.v \
    ../datain/RTL/SIPO.v \
    ../datain/RTL/Interpolator.v \
    ../datain/RTL/P2S_Interpolator.v \
    ../datain/RTL/FIR_LPF_TRANSPOSED.v \
    ../datain/RTL/MinAJ2_Datapath.v \
    ../datain/RTL/ASIC_top.v \
    -Verilog -Golden -continuousassignment Bidirectional -nokeep_unreach -norangeconstraint

// REVISED NETLIST
read design ../datain/netlist/ASIC_Top_netlist.v \
    -Verilog -Revised -sensitive -continuousassignment Bidirectional -nokeep_unreach -nosupply

// Neutralize scan chains (Tie scan_en to 0 to force functional mode)
add pin constraints 0 scan_en -Revised
add pin constraints 0 scan_in1 scan_in2 scan_in3 -Revised
add ignore outputs scan_out1 scan_out2 scan_out3 -Revised

// Disregard gated clocks as a reason for non-equivalence
set flatten model -gated_clock

// Read vsdc file from synthesis to aid datapath matching
read setup information compile.vsdc -type vsdc

uniquify -all

// Write Hierarchical dofile with wordlevel analysis
write hier_compare dofile hier_compare.do -replace -prepend_string "analyze datapath -module -threads 4; usage; analyze datapath -wordlevel -verbose"

set dofile abort OFF
set compare effort low

// Execute the comparison
run hier_compare hier_compare.do
