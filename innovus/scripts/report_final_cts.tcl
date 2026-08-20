# ============================================================================
# Final CCOpt clock-tree report
# Restores the completed physical implementation and writes read-only CTS
# metrics for the final clock tree and functional skew group.
# ============================================================================

setDesignMode -process 28
setMultiCpuUsage -local 8

restoreDesign ../dataout/design_saves/final_hold_eco_iter4b_trial.dat top

set OUT ../../results/innovus/final_cts_ccopt.rpt

file mkdir ../../results/innovus

redirect $OUT {
    puts "======================================================================"
    puts " CUBIC Interpolation DSP ASIC - Final CCOpt Clock Tree Report"
    puts "======================================================================"
    puts ""
    puts "Design      : [dbGet top.name]"
    puts "Clock trees : [get_ccopt_clock_trees]"
    puts "Skew groups : [get_ccopt_skew_groups]"
    puts ""
    puts "======================================================================"
    puts " SKEW GROUP REPORT"
    puts "======================================================================"
    puts ""
    report_ccopt_skew_groups
}

redirect -append $OUT {
    puts ""
    puts "======================================================================"
    puts " CLOCK TREE REPORT"
    puts "======================================================================"
    puts ""
    report_ccopt_clock_trees
}

if {![file exists $OUT]} {
    error "FINAL_CTS_REPORT_MISSING"
}

if {[file size $OUT] <= 0} {
    error "FINAL_CTS_REPORT_EMPTY"
}

puts "FINAL_CTS_REPORT=[file normalize $OUT]"
puts "FINAL_CTS_REPORT_SIZE=[file size $OUT]"
puts "##### FINAL_CTS_REPORT_PASS #####"

exit
