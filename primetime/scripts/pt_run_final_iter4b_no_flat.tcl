# ======================================================================
# Final PrimeTime STA - Iter4B physical candidate
#
# Modes:
#   PT_MODE   = setup | hold
#   PT_CORNER = slow | typ | fast
#
# Policy:
#   - Fresh Iter4B physical netlist + SPEF
#   - No historical flat +/-15% hold derate
#   - Original Innovus SDC values preserved
#   - Mechanical PT compatibility transform only
# ======================================================================

set MODE   $::env(PT_MODE)
set CORNER $::env(PT_CORNER)

set BASE /project/verif/users/yitzhak2/ws/ex_vlsi_1/final_script
set OUT  report/final_iter4b_no_flat

file mkdir $OUT

set NLDM /data/tsmc/28HPCPMMWAVE/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM

set search_path [list \
    . \
    $NLDM/tcbn28hpcplusbwp30p140_180a \
    $NLDM/tphn28hpcpgv18_170a \
]

switch -- $CORNER {
    slow {
        set core tcbn28hpcplusbwp30p140ssg0p81v125c.db
        set pad  tphn28hpcpgv18ssg0p81v1p62v125c.db
        set spef top_slow.SPEF
    }

    typ {
        set core tcbn28hpcplusbwp30p140tt0p9v25c.db
        set pad  tphn28hpcpgv18tt0p9v1p8v25c.db
        set spef top_slow.SPEF
    }

    fast {
        set core tcbn28hpcplusbwp30p140ffg0p99vm40c.db
        set pad  tphn28hpcpgv18ffg0p99v1p98vm40c.db
        set spef top_fast.SPEF
    }

    default {
        puts "FATAL: unsupported PT_CORNER=$CORNER"
        exit 2
    }
}

set link_path "* $core $pad"

set si_enable_analysis true

puts "================================================================"
puts "FINAL PT ITER4B"
puts "MODE=$MODE"
puts "CORNER=$CORNER"
puts "CORE=$core"
puts "PAD=$pad"
puts "SPEF=$spef"
puts "DERATE_POLICY=NO_FLAT_15_PERCENT"
puts "================================================================"


# ----------------------------------------------------------------------
# Netlist
# ----------------------------------------------------------------------

read_verilog \
    $BASE/innovus/dataout/pt_hold_eco_iter4b_trial/top_post_layout.v

current_design top

link > $OUT/link_${MODE}_${CORNER}.log

set sh_continue_on_error true


# ----------------------------------------------------------------------
# PrimeTime-compatible SDC
#
# Mechanical changes only:
#   1. remove Innovus-only get_cells -quiet option
#   2. create empty collection without __NO_SUCH_CELL__
#   3. translate /main_gate -> _main_gate
#   4. remove one stale I-interpolator CG entry
# ----------------------------------------------------------------------

set _sdc_pt $OUT/top_pt_no_flat_derate.sdc

set _sed_rc [catch {
    exec sed \
        -e {s/ -quiet//g} \
        -e {s#set out \[get_cells __NO_SUCH_CELL__\]#set out [remove_from_collection [get_cells *] [get_cells *]]#} \
        -e {s#/main_gate#_main_gate#g} \
        -e {\#I0/u_path_I_u_interp/clk_gate_sample_cnt_reg_main_gate#d} \
        $BASE/innovus/datain/top.sdc > $_sdc_pt
} _sed_msg]

if {$_sed_rc != 0} {
    puts "FATAL: SDC compatibility transform failed"
    puts $_sed_msg
    exit 2
}

source $_sdc_pt

if {[file exists $BASE/innovus/datain/extra_constraints.sdc]} {
    source $BASE/innovus/datain/extra_constraints.sdc
}

check_timing -verbose > $OUT/check_${MODE}_${CORNER}.rpt


# ----------------------------------------------------------------------
# Parasitics
# ----------------------------------------------------------------------

read_parasitics \
    -format SPEF \
    $BASE/innovus/dataout/pt_hold_eco_iter4b_trial/$spef


# ----------------------------------------------------------------------
# IMPORTANT:
# No flat 15% set_timing_derate is applied here.
# ----------------------------------------------------------------------

set_propagated_clock [all_clocks]

update_timing -full

set dt [expr {$MODE eq "hold" ? "min" : "max"}]


# ----------------------------------------------------------------------
# Helper: obtain WNS and negative-path count
# ----------------------------------------------------------------------

proc timing_stats {dt group_name} {

    if {$group_name eq ""} {

        set worst [get_timing_paths \
            -delay_type $dt \
            -nworst 1 \
            -max_paths 1]

        set neg [get_timing_paths \
            -delay_type $dt \
            -nworst 1 \
            -max_paths 1000 \
            -slack_lesser_than 0.0]

    } else {

        set worst [get_timing_paths \
            -delay_type $dt \
            -group $group_name \
            -nworst 1 \
            -max_paths 1]

        set neg [get_timing_paths \
            -delay_type $dt \
            -group $group_name \
            -nworst 1 \
            -max_paths 1000 \
            -slack_lesser_than 0.0]
    }

    set wns "NA"

    if {[sizeof_collection $worst] > 0} {
        set wns [get_attribute $worst slack]
    }

    return [list $wns [sizeof_collection $neg]]
}


# ----------------------------------------------------------------------
# Summary metrics
# ----------------------------------------------------------------------

set overall_stats [timing_stats $dt ""]
set data_stats    [timing_stats $dt "clk"]
set cg_stats      [timing_stats $dt {**clock_gating_default**}]
set async_stats   [timing_stats $dt {**async_default**}]

set overall_wns [lindex $overall_stats 0]
set overall_neg [lindex $overall_stats 1]

set data_wns [lindex $data_stats 0]
set data_neg [lindex $data_stats 1]

set cg_wns [lindex $cg_stats 0]
set cg_neg [lindex $cg_stats 1]

set async_wns [lindex $async_stats 0]
set async_neg [lindex $async_stats 1]


puts ""
puts "================================================================"
puts "FINAL_PT_RESULT"
puts "MODE=$MODE"
puts "CORNER=$CORNER"
puts "DELAY_TYPE=$dt"
puts "OVERALL_WNS=$overall_wns"
puts "OVERALL_NEGATIVE_PATHS=$overall_neg"
puts "DATA_WNS=$data_wns"
puts "DATA_NEGATIVE_PATHS=$data_neg"
puts "CLOCK_GATING_WNS=$cg_wns"
puts "CLOCK_GATING_NEGATIVE_PATHS=$cg_neg"
puts "ASYNC_WNS=$async_wns"
puts "ASYNC_NEGATIVE_PATHS=$async_neg"
puts "================================================================"


set fh [open $OUT/SUMMARY.txt a]

puts $fh [format \
    "%-5s %-5s OVERALL_WNS=%s OVERALL_NEG=%s DATA_WNS=%s DATA_NEG=%s CG_WNS=%s CG_NEG=%s ASYNC_WNS=%s ASYNC_NEG=%s" \
    $MODE \
    $CORNER \
    $overall_wns \
    $overall_neg \
    $data_wns \
    $data_neg \
    $cg_wns \
    $cg_neg \
    $async_wns \
    $async_neg \
]

close $fh


# ----------------------------------------------------------------------
# Detailed reports
# ----------------------------------------------------------------------

report_timing \
    -delay_type $dt \
    -nworst 1 \
    -max_paths 30 \
    -path_type full_clock \
    -nosplit \
    -slack_lesser_than 1000.0 \
    -significant_digits 6 \
    > $OUT/${MODE}_${CORNER}_TIMING.rpt

report_timing \
    -delay_type $dt \
    -group clk \
    -nworst 1 \
    -max_paths 30 \
    -path_type full_clock \
    -nosplit \
    -slack_lesser_than 1000.0 \
    -significant_digits 6 \
    > $OUT/${MODE}_${CORNER}_DATA.rpt

report_timing \
    -delay_type $dt \
    -group {**clock_gating_default**} \
    -nworst 1 \
    -max_paths 20 \
    -path_type full_clock \
    -nosplit \
    -slack_lesser_than 1000.0 \
    -significant_digits 6 \
    > $OUT/${MODE}_${CORNER}_CLOCK_GATING.rpt

report_timing \
    -delay_type $dt \
    -group {**async_default**} \
    -nworst 1 \
    -max_paths 20 \
    -path_type full_clock \
    -nosplit \
    -slack_lesser_than 1000.0 \
    -significant_digits 6 \
    > $OUT/${MODE}_${CORNER}_ASYNC.rpt

report_constraint \
    -all_violators \
    -verbose \
    > $OUT/${MODE}_${CORNER}_VIOLATORS.rpt


puts "##### FINAL_PT_RUN_PASS MODE=$MODE CORNER=$CORNER #####"

exit
