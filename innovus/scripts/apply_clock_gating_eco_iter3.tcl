# ======================================================================
# apply_clock_gating_eco_iter3.tcl
#
# Physical ECO iteration #3:
#   Fix 4 PrimeTime clock-gating Hold violations.
#
# Input:
#   final_hold_eco_iter2_trial.dat
#
# Existing ECOs which must remain:
#   29 x U_PTECO_HOLD_BUF*
#    2 x U_PTECO2_HOLD_BUF*
#
# Add:
#    4 x BUFFD0BWP30P140 on clock-gate A1 enable/data paths.
#
# Output:
#   final_hold_eco_iter3_trial
#
# No previous checkpoint is overwritten.
# ======================================================================

setDesignMode -process 28
setMultiCpuUsage -local 8

puts "===== CLOCK-GATING ECO ITER3: RESTORE ITER2 DB ====="

restoreDesign \
    ../dataout/design_saves/final_hold_eco_iter2_trial.dat \
    top


# ----------------------------------------------------------------------
# PrimeTime actual write_changes, Fast Hold / clock_gating_default
# ----------------------------------------------------------------------

set eco_spec {
    {1 BUFFD0BWP30P140 I0/u_path_I_u_fir/clk_gate_y_out_reg_main_gate/A1}
    {2 BUFFD0BWP30P140 I0/u_path_Q_u_sipo_clk_gate_shift_reg_reg_main_gate/A1}
    {3 BUFFD0BWP30P140 I0/u_path_Q_u_fir/clk_gate_y_out_reg_main_gate/A1}
    {4 BUFFD0BWP30P140 I0/u_path_Q_u_interp/clk_gate_sample_cnt_reg_main_gate/A1}
}


# ----------------------------------------------------------------------
# 1. Preflight
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: PREFLIGHT ====="

if {[llength $eco_spec] != 4} {
    error "CG_ECO_ITER3_BAD_SPEC_COUNT"
}

set iter1Bufs [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

set iter2Bufs [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO2_HOLD_BUF*"]

puts "ITER1_BUFFER_COUNT=[llength $iter1Bufs]"
puts "ITER2_BUFFER_COUNT=[llength $iter2Bufs]"

if {[llength $iter1Bufs] != 29} {
    error "CG_ECO_ITER3_BAD_ITER1_COUNT"
}

if {[llength $iter2Bufs] != 2} {
    error "CG_ECO_ITER3_BAD_ITER2_COUNT"
}

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]

    if {[llength $tp] != 1} {
        error "CG_ECO_ITER3_TARGET_NOT_UNIQUE: idx=$idx pin=$pin count=[llength $tp]"
    }

    if {[llength [get_db base_cells $cell]] != 1} {
        error "CG_ECO_ITER3_MASTER_NOT_UNIQUE: idx=$idx cell=$cell"
    }

    set existing [lsearch -all -inline -glob \
        [get_db insts .name] "*U_PTECO3_CG_BUF${idx}"]

    if {[llength $existing] != 0} {
        error "CG_ECO_ITER3_BUFFER_ALREADY_EXISTS: idx=$idx matches=$existing"
    }

    puts "CG_ITER3_TARGET idx=$idx pin=$pin oldNet=[get_db $tp .net.name]"
}

puts "CG_ECO_ITER3_PREFLIGHT_PASS"


# ----------------------------------------------------------------------
# 2. Remove standard-cell fillers only
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: REMOVE STANDARD FILLERS ====="

set stdFillBefore [llength [get_db insts FILL*]]
set ioFillBefore  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_BEFORE=$stdFillBefore"
puts "IO_FILL_BEFORE=$ioFillBefore"

deleteFiller -prefix FILL

puts "STD_FILL_AFTER_DELETE=[llength [get_db insts FILL*]]"
puts "IO_FILL_AFTER_DELETE=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] != 0} {
    error "CG_ECO_ITER3_FILLER_DELETE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "CG_ECO_ITER3_IO_FILLERS_CHANGED"
}


# ----------------------------------------------------------------------
# 3. Insert four logical BUFFD0 cells
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: INSERT 4 BUFFERS ====="

setEcoMode -updateTiming false

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]
    set oldNet [get_db $tp .net.name]

    set bufBase "U_PTECO3_CG_BUF${idx}"
    set netBase "net_PTECO3_CG_NET${idx}"

    puts "CG_ITER3_INSERT idx=$idx cell=$cell pin=$pin"

    ecoAddRepeater \
        -term [list $pin] \
        -cell $cell \
        -name $bufBase \
        -newNetName $netBase \
        -noPlace

    set matches [lsearch -all -inline -glob \
        [get_db insts .name] "*${bufBase}"]

    if {[llength $matches] != 1} {
        error "CG_ECO_ITER3_INSERT_FAILED: idx=$idx matches=$matches"
    }

    set bufFull [lindex $matches 0]
    set ni [get_db insts $bufFull]

    set actualMaster [get_db $ni .base_cell.name]

    if {$actualMaster ne $cell} {
        error "CG_ECO_ITER3_MASTER_MISMATCH: idx=$idx expected=$cell actual=$actualMaster"
    }

    set biNet [get_db [get_db pins ${bufFull}/I] .net.name]
    set bzNet [get_db [get_db pins ${bufFull}/Z] .net.name]
    set tpNet [get_db [get_db pins $pin] .net.name]

    if {$biNet ne $oldNet} {
        error "CG_ECO_ITER3_INPUT_NET_MISMATCH: idx=$idx expected=$oldNet actual=$biNet"
    }

    if {[file tail $bzNet] ne $netBase} {
        error "CG_ECO_ITER3_OUTPUT_NET_MISMATCH: idx=$idx actual=$bzNet"
    }

    if {$tpNet ne $bzNet} {
        error "CG_ECO_ITER3_TARGET_NET_MISMATCH: idx=$idx"
    }

    puts "CG_ITER3_INSERT_OK idx=$idx buffer=$bufFull oldNet=$oldNet newNet=$bzNet"
}

puts "CG_ECO_ITER3_LOGICAL_PASS"


# ----------------------------------------------------------------------
# 4. Placement
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: PLACE ====="

ecoPlace \
    -fixPlacedInsts true \
    -timing_driven false

foreach item $eco_spec {

    lassign $item idx cell pin

    set matches [lsearch -all -inline -glob \
        [get_db insts .name] "*U_PTECO3_CG_BUF${idx}"]

    if {[llength $matches] != 1} {
        error "CG_ECO_ITER3_PLACE_MATCH_FAILED: idx=$idx"
    }

    set ni [get_db insts [lindex $matches 0]]
    set ps [get_db $ni .place_status]

    if {$ps ne "placed"} {
        error "CG_ECO_ITER3_NOT_PLACED: idx=$idx status=$ps"
    }

    puts "CG_ITER3_PLACED idx=$idx inst=[get_db $ni .name] loc=[get_db $ni .location]"
}

puts "CG_ECO_ITER3_PLACE_PASS"


# ----------------------------------------------------------------------
# 5. ECO routing
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: ROUTE ====="

ecoRoute

setEcoMode -updateTiming true

puts "CG_ECO_ITER3_ROUTE_DONE"


# ----------------------------------------------------------------------
# 6. Restore standard-cell fillers
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: RESTORE STANDARD FILLERS ====="

addFiller -cell {FILL64BWP30P140 FILL32BWP30P140 FILL16BWP30P140 FILL8BWP30P140 FILL4BWP30P140 FILL3BWP30P140 FILL2BWP30P140} -prefix FILL

puts "STD_FILL_FINAL=[llength [get_db insts FILL*]]"
puts "IO_FILL_FINAL=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] == 0} {
    error "CG_ECO_ITER3_FILLER_RESTORE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "CG_ECO_ITER3_IO_FILLER_FINAL_CHANGED"
}


# ----------------------------------------------------------------------
# 7. Connectivity + DRC
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: CONNECTIVITY ====="

verifyConnectivity \
    -type all \
    -error 100000 \
    -report clock_gating_eco_iter3_verify_conn.rpt

set fh [open clock_gating_eco_iter3_verify_conn.rpt r]
set txt [read $fh]
close $fh

if {[string first "Found no problems or warnings." $txt] < 0} {
    error "CG_ECO_ITER3_CONNECTIVITY_FAILED"
}

puts "CG_ECO_ITER3_CONNECTIVITY_PASS"


puts "===== CLOCK-GATING ECO ITER3: DRC ====="

verify_drc \
    -check_same_via_cell \
    -limit 100000 \
    -report clock_gating_eco_iter3_verify_drc.rpt

set fh [open clock_gating_eco_iter3_verify_drc.rpt r]
set txt [read $fh]
close $fh

if {[string first "No DRC violations were found" $txt] < 0} {
    error "CG_ECO_ITER3_DRC_FAILED"
}

puts "CG_ECO_ITER3_DRC_PASS"


# ----------------------------------------------------------------------
# 8. Confirm all ECO generations remain
# ----------------------------------------------------------------------

set iter1Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

set iter2Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO2_HOLD_BUF*"]

set iter3Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO3_CG_BUF*"]

puts "ITER1_BUFFER_COUNT_FINAL=[llength $iter1Final]"
puts "ITER2_BUFFER_COUNT_FINAL=[llength $iter2Final]"
puts "ITER3_CG_BUFFER_COUNT_FINAL=[llength $iter3Final]"

if {[llength $iter1Final] != 29} {
    error "CG_ECO_ITER3_LOST_ITER1_BUFFERS"
}

if {[llength $iter2Final] != 2} {
    error "CG_ECO_ITER3_LOST_ITER2_BUFFERS"
}

if {[llength $iter3Final] != 4} {
    error "CG_ECO_ITER3_BAD_FINAL_COUNT"
}


# ----------------------------------------------------------------------
# 9. Innovus timing sanity
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: TIMING ====="

file mkdir timingReports

timeDesign \
    -postRoute \
    -numPaths 20 \
    -prefix cg_eco_iter3_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -numPaths 20 \
    -prefix cg_eco_iter3_hold \
    -outDir timingReports


# ----------------------------------------------------------------------
# 10. Save NEW trial checkpoint only
# ----------------------------------------------------------------------

puts "===== CLOCK-GATING ECO ITER3: SAVE ====="

saveDesign \
    ../dataout/design_saves/final_hold_eco_iter3_trial

puts "##### CG_ECO_ITER3_PHYSICAL_PASS #####"
puts "Saved: ../dataout/design_saves/final_hold_eco_iter3_trial"

exit
