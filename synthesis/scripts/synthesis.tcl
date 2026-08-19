# ==========================================================================
# Synthesis TCL Script for ASIC_Top
# ==========================================================================

# 1. Setup Libraries
set TECH_LIB_PATH "/data/tsmc/28HPCPMMWAVE/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM"
set search_path [list . "$TECH_LIB_PATH/tcbn28hpcplusbwp30p140_180a"]

# NOTE: You must replace "your_target_library.db" with the actual 
# standard cell .db file name located in the NLDM directory.
# (e.g., tcbn28hpcplusbwp30p140_ssg0p81v125c.db)
set target_library "tcbn28hpcplusbwp30p140ssg0p81v125c.db"

# Define DesignWare Synthetic Libraries
set synthetic_library "dw_foundation.sldb"
set link_library "* $target_library $synthetic_library"

# Define local WORK library
define_design_lib WORK -path "."

# 2. Read RTL Files
set RTL_FILES {
    ../datain/Control_Unit.v
    ../datain/SIPO.v
    ../datain/Interpolator.v
    ../datain/P2S_Interpolator.v
    ../datain/FIR_LPF_TRANSPOSED.v
    ../datain/MinAJ2_Datapath.v
    ../datain/ASIC_top.v
}

analyze -library WORK -format sverilog $RTL_FILES

# 3. Elaborate and Link Top Module
elaborate ASIC_Top -architecture verilog -library WORK
set TopModule ASIC_Top
current_design ASIC_Top

# Generate Post-Elaborate Reports
set filename "../report/post_elaborate.rpt"
redirect $filename { report_timing -delay_type max }
redirect -append $filename { report_timing -delay_type min }
redirect -append $filename { report_area }
redirect -append $filename { report_constraint -all_violators }
redirect -append $filename { check_design }

link

# 4. Read SDC Timing Constraints
source ../datain/ASIC_top.sdc
current_design ${TopModule}

# ==========================================================================
# Path Grouping 
# ==========================================================================
# Create input, output and feed through groups so the tool will focus on each path type separately
set ports_clock_root [filter_collection [get_attribute [get_clocks clk] sources] object_class==port]
group_path -name OUT -to [all_outputs]
group_path -name IN -from [remove_from_collection [all_inputs] $ports_clock_root]
group_path -name FEEDTHR -from [remove_from_collection [all_inputs] $ports_clock_root] -to [all_outputs]

# ==========================================================================
# Pre-Compile Settings 
# ==========================================================================
# Save initial DB for future debug
write -format ddc -hierarchy -output ../dataout/initial_${TopModule}.ddc ${TopModule}

# Compile ultra settings
set compile_delete_unloaded_sequential_cells true
set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_high_effort false

# Enable constant propagation through combinatorial cells (not FFs)
set case_analysis_with_logic_constants true
set template_separator_style "_"

# Disable register merging, LEC will pass easier
set_register_merging [ get_designs ${TopModule} ] false

# Clock Gating
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 3

# Fix VO-4 (Verilog assign statements) warning
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

# 5. Compile Design
puts -nonewline "\033\[1;31m"; #RED
puts "##### STARTING COMPILATION #####"
puts -nonewline "\033\[0m";# Reset
puts ""

# Create vsdc file to help LEC
set_vsdc compile.vsdc

compile_ultra -gate_clock

puts -nonewline "\033\[1;31m"; #RED
puts "##### FINISHED COMPILATION #####"
puts -nonewline "\033\[0m";# Reset
puts ""

# 6. Generate Reports (Pre-Scan)
file mkdir ../report
set rpt_filename "../report/post_compile.rpt"

redirect $rpt_filename { report_timing -delay_type max }
redirect -append $rpt_filename { report_timing -delay_type min }
redirect -append $rpt_filename { report_area }
redirect -append $rpt_filename { report_power }
redirect -append $rpt_filename { report_constraint -all_violators }
redirect -append $rpt_filename { check_design }


# ==========================================================================
# 7. Scan Chain Insertion
# ==========================================================================

# Enter scan chain, don't ignore Shift-registers
set scan_configuration -style multiplexed_flip_flop
set compile_seqmap_identify_shift_registers false

# Create scan ports
create_port -dir in scan_en
create_port -dir in {scan_in1 scan_in2 scan_in3}
create_port -dir out {scan_out1 scan_out2 scan_out3}

# Configure DFT signals
set_dft_signal -view existing_dft -type ScanClock -port clk -timing {45 55}
set_dft_signal -view existing_dft -type ScanEnable -port scan_en -active_state 1
set_dft_signal -view existing_dft -type ScanDataIn -port {scan_in1 scan_in2 scan_in3}
set_dft_signal -view existing_dft -type ScanDataOut -port {scan_out1 scan_out2 scan_out3}

# Set chain count to 3
set_scan_configuration -chain_count 3

# Do scan synthesis
create_test_protocol -infer_asynch
dft_drc -verbose
set_dft_configuration -scan enable
set_dft_configuration -fix_set enable
insert_dft

# Show all chains created in a file name scandef
write_scan_def -output ../dataout/scandef

# Generate Post-Scan Chain Reports
set rpt_scan_filename "../report/post_scan_chain.rpt"
redirect $rpt_scan_filename { report_timing -delay_type max }
redirect -append $rpt_scan_filename { report_timing -delay_type min }
redirect -append $rpt_scan_filename { report_area }
redirect -append $rpt_scan_filename { report_constraint -all_violators }
redirect -append $rpt_scan_filename { check_design }


# ==========================================================================
# 8. Netlist Output Configurations
# ==========================================================================
set verilogout_no_tri true
set verilog_show_unconnected_pins false
set verilog_unconnected_Prefix true
set hdlout_internal_busses true
set bus_inference_style {%s[%d]}
set verilogout_single_bit false
set bus_naming_style {%s[%d]}

# Force internal database names to match Verilog rules to eliminate naming assigns
change_names -rules verilog -hierarchy

# Write final files
write_file -format verilog -hierarchy -output ../dataout/ASIC_Top_netlist.v
write_sdc -nosplit ../dataout/ASIC_Top.sdc
write_test_protocol -out ../dataout/${TopModule}.spf
write -format ddc -hierarchy -output ../dataout/final_${TopModule}.ddc ${TopModule}

quit
