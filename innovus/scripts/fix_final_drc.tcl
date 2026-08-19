# ============================================================================
# fix_final_drc.tcl
#
# Deterministic post-route repairs validated on the historical final database.
#
# Repairs:
#   1. U9458 VDDC VIA1 array
#   2. U4485 VDDC VIA1 array
#   3. U9479 VDDC VIA1 array
#   4. Q/U163 B-pin signal access
#
# Required final result:
#   verifyConnectivity              : clean
#   verify_drc -check_same_via_cell : clean
# ============================================================================

proc final_drc_fail {msg} {
    puts "FINAL_DRC_REPAIR_ERROR: $msg"
    error $msg
}

proc final_drc_pg_stats {area} {
    set vv [dbQuery \
        -areas $area \
        -objType sViaInst \
        -layers VIA1 \
        -strict_via_inst_layer_check]

    set totalCuts 0

    foreach v $vv {
        set rows [dbGet $v.via.cutRows]
        set cols [dbGet $v.via.cutColumns]
        set totalCuts [expr {$totalCuts + $rows*$cols}]
    }

    return [list [llength $vv] $totalCuts]
}

proc final_drc_fix_pg {name area expectedInsts expectedCuts splitSpec} {

    puts ""
    puts "===== FINAL DRC REPAIR: $name ====="

    set stats [final_drc_pg_stats $area]
    set n    [lindex $stats 0]
    set cuts [lindex $stats 1]

    puts "BEFORE: VIA1_INSTS=$n TOTAL_CUTS=$cuts"

    # Makes the PG repair safe if the script is sourced again.
    if {$n == $expectedInsts && $cuts == $expectedCuts} {
        puts "$name already has validated repaired geometry - skipping."
        return
    }

    # Expected geometry in the historical final database.
    if {$n != 1 || $cuts != 30} {
        final_drc_fail \
            "$name has unexpected VIA1 geometry: insts=$n cuts=$cuts"
    }

    set vv [dbQuery \
        -areas $area \
        -objType sViaInst \
        -layers VIA1 \
        -strict_via_inst_layer_check]

    deselectAll
    select_obj $vv

    editPowerVia \
        -modify_vias 1 \
        -selected_vias 1 \
        -bottom_layer M1 \
        -top_layer M2 \
        -split_long_via $splitSpec

    deselectAll

    set statsAfter [final_drc_pg_stats $area]
    set nAfter    [lindex $statsAfter 0]
    set cutsAfter [lindex $statsAfter 1]

    puts "AFTER : VIA1_INSTS=$nAfter TOTAL_CUTS=$cutsAfter"

    if {$nAfter != $expectedInsts || $cutsAfter != $expectedCuts} {
        final_drc_fail \
            "$name repair produced unexpected geometry: insts=$nAfter cuts=$cutsAfter"
    }
}


puts ""
puts "============================================================"
puts "FINAL POST-ROUTE DRC REPAIR"
puts "============================================================"


# ----------------------------------------------------------------------------
# 1. Repair stale VDDC VIA1 arrays
# ----------------------------------------------------------------------------

final_drc_fix_pg \
    U9458 \
    {330.8 485.60 335.2 486.10} \
    2 26 \
    {2.0 2.26 0.87 1.74}

final_drc_fix_pg \
    U4485 \
    {330.8 379.40 335.2 379.90} \
    2 26 \
    {2.0 2.26 0.87 1.74}

final_drc_fix_pg \
    U9479 \
    {330.8 481.95 335.2 482.35} \
    4 24 \
    {2.0 1.01 0.425 0.83}


# ----------------------------------------------------------------------------
# 2. Repair Q/U163 B-pin signal access
# ----------------------------------------------------------------------------

puts ""
puts "===== FINAL DRC REPAIR: Q/U163 B ACCESS ====="

set BAD_B_NET \
    "I0/u_path_Q_u_interp/FE_OFN452_n9188"

set OLD_B_PICK_AREA \
    {487.29 624.05 487.32 624.35}

set oldBWires {}

foreach w [dbQuery \
    -areas $OLD_B_PICK_AREA \
    -objType wire \
    -layers M2] {

    if {[dbGet $w.net.name] eq $BAD_B_NET} {
        lappend oldBWires $w
    }
}

puts "OLD_B_BRANCH_COUNT=[llength $oldBWires]"

if {[llength $oldBWires] > 1} {
    final_drc_fail \
        "More than one matching old U163/B M2 branch was found."
}

if {[llength $oldBWires] == 1} {

    set oldBWire [lindex $oldBWires 0]

    puts "Removing historical B branch:"
    puts "  NET    = [dbGet $oldBWire.net.name]"
    puts "  LAYER  = [dbGet $oldBWire.layer.name]"
    puts "  BOX    = [dbGet $oldBWire.box]"
    puts "  STATUS = [dbGet $oldBWire.status]"

    deselectAll
    select_obj $oldBWires

    editDelete \
        -selected \
        -object_type Wire \
        -type Regular \
        -layer M2 \
        -status ROUTED

    deselectAll

    # Confirm that the historical branch disappeared.
    set oldAfter {}

    foreach w [dbQuery \
        -areas $OLD_B_PICK_AREA \
        -objType wire \
        -layers M2] {

        if {[dbGet $w.net.name] eq $BAD_B_NET} {
            lappend oldAfter $w
        }
    }

    if {[llength $oldAfter] != 0} {
        final_drc_fail \
            "Old U163/B M2 branch still exists after editDelete."
    }

    # The net is now partially routed.
    # Route only this selected net and let NanoRoute choose a legal pin access.
    deselectAll
    selectNet [list $BAD_B_NET]

    puts "Routing selected net: $BAD_B_NET"

    setNanoRouteMode -route_selected_net_only true

    set routeError [catch {
        globalDetailRoute -select
    } routeMessage]

    setNanoRouteMode -reset -route_selected_net_only
    deselectAll

    if {$routeError} {
        final_drc_fail \
            "globalDetailRoute failed for $BAD_B_NET : $routeMessage"
    }

} else {

    puts "Historical U163/B M2 branch is already absent - skipping reroute."
}


# ----------------------------------------------------------------------------
# 3. Verify complete connectivity
# ----------------------------------------------------------------------------

puts ""
puts "===== FINAL DRC REPAIR: VERIFY CONNECTIVITY ====="

set CONN_RPT final_repair_verify_conn.rpt
file delete -force $CONN_RPT

verifyConnectivity \
    -type all \
    -error 100000 \
    -report $CONN_RPT

set fh [open $CONN_RPT r]
set connText [read $fh]
close $fh

if {![string match "*Found no problems or warnings.*" $connText]} {
    final_drc_fail \
        "verifyConnectivity is not clean. See $CONN_RPT"
}


# ----------------------------------------------------------------------------
# 4. Verify full-chip DRC, including same-cell via checks
# ----------------------------------------------------------------------------

puts ""
puts "===== FINAL DRC REPAIR: VERIFY DRC ====="

set DRC_RPT final_repair_verify_drc.rpt
file delete -force $DRC_RPT

verify_drc \
    -check_same_via_cell \
    -limit 100000 \
    -report $DRC_RPT

set fh [open $DRC_RPT r]
set drcText [read $fh]
close $fh

if {![string match "*No DRC violations were found*" $drcText]} {
    final_drc_fail \
        "verify_drc is not clean. See $DRC_RPT"
}


# ----------------------------------------------------------------------------
# 5. PG sanity after signal reroute
# ----------------------------------------------------------------------------

foreach check {
    {U9458 {330.8 485.60 335.2 486.10} 2 26}
    {U4485 {330.8 379.40 335.2 379.90} 2 26}
    {U9479 {330.8 481.95 335.2 482.35} 4 24}
} {
    set name          [lindex $check 0]
    set area          [lindex $check 1]
    set expectedInsts [lindex $check 2]
    set expectedCuts  [lindex $check 3]

    set stats [final_drc_pg_stats $area]

    if {[lindex $stats 0] != $expectedInsts || \
        [lindex $stats 1] != $expectedCuts} {

        final_drc_fail \
            "$name PG geometry changed after signal reroute."
    }
}


puts ""
puts "============================================================"
puts "FINAL_DRC_REPAIR_PASS"
puts "  verifyConnectivity : CLEAN"
puts "  verify_drc          : CLEAN"
puts "============================================================"
