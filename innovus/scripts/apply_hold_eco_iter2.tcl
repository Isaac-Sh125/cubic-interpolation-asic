# ======================================================================
# apply_hold_eco_iter2.tcl
#
# Physical Hold ECO iteration #2.
#
# Input:
#   final_hold_eco_trial.dat   (contains the physical 29-buffer ECO)
#
# Add:
#   2 x DEL025D1BWP30P140
#
# Output:
#   final_hold_eco_iter2_trial
#
# The previous databases are never overwritten.
# ======================================================================

setDesignMode -process 28
setMultiCpuUsage -local 8

puts "===== HOLD ECO ITER2: RESTORE ITER1 DB ====="

restoreDesign \
    ../dataout/design_saves/final_hold_eco_trial.dat \
    top


# ----------------------------------------------------------------------
# PT actual ECO iteration #2
# ----------------------------------------------------------------------

set eco_spec {
    {1 DEL025D1BWP30P140 I0/u_path_Q_u_interp/y0_reg_4_/D}
    {2 DEL025D1BWP30P140 I0/u_path_Q_u_interp/y0_reg_8_/D}
}


# ----------------------------------------------------------------------
# 1. Preflight
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: PREFLIGHT ====="

if {[llength $eco_spec] != 2} {
    error "HOLD_ECO_ITER2_BAD_SPEC_COUNT"
}

set iter1Bufs [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

puts "ITER1_BUFFER_COUNT=[llength $iter1Bufs]"

if {[llength $iter1Bufs] != 29} {
    error "HOLD_ECO_ITER2_BAD_ITER1_BUFFER_COUNT"
}

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]

    if {[llength $tp] != 1} {
        error "HOLD_ECO_ITER2_TARGET_NOT_UNIQUE: idx=$idx pin=$pin count=[llength $tp]"
    }

    if {[llength [get_db base_cells $cell]] != 1} {
        error "HOLD_ECO_ITER2_MASTER_NOT_UNIQUE: idx=$idx cell=$cell"
    }

    set oldMatches [lsearch -all -inline -glob \
        [get_db insts .name] "*U_PTECO2_HOLD_BUF${idx}"]

    if {[llength $oldMatches] != 0} {
        error "HOLD_ECO_ITER2_BUFFER_ALREADY_EXISTS: idx=$idx matches=$oldMatches"
    }

    puts "ITER2_TARGET idx=$idx pin=$pin oldNet=[get_db $tp .net.name]"
}

puts "HOLD_ECO_ITER2_PREFLIGHT_PASS"


# ----------------------------------------------------------------------
# 2. Remove standard-cell fillers only
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: REMOVE STANDARD FILLERS ====="

set stdFillBefore [llength [get_db insts FILL*]]
set ioFillBefore  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_BEFORE=$stdFillBefore"
puts "IO_FILL_BEFORE=$ioFillBefore"

deleteFiller -prefix FILL

puts "STD_FILL_AFTER_DELETE=[llength [get_db insts FILL*]]"
puts "IO_FILL_AFTER_DELETE=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] != 0} {
    error "HOLD_ECO_ITER2_FILLER_DELETE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "HOLD_ECO_ITER2_IO_FILLERS_CHANGED"
}


# ----------------------------------------------------------------------
# 3. Insert two logical buffers
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: INSERT TWO BUFFERS ====="

setEcoMode -updateTiming false

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]
    set oldNet [get_db $tp .net.name]

    set bufBase "U_PTECO2_HOLD_BUF${idx}"
    set netBase "net_PTECO2_HOLD_NET${idx}"

    puts "ITER2_INSERT idx=$idx cell=$cell pin=$pin"

    ecoAddRepeater \
        -term [list $pin] \
        -cell $cell \
        -name $bufBase \
        -newNetName $netBase \
        -noPlace

    set bufMatches [lsearch -all -inline -glob \
        [get_db insts .name] "*${bufBase}"]

    if {[llength $bufMatches] != 1} {
        error "HOLD_ECO_ITER2_INSERT_FAILED: idx=$idx matches=$bufMatches"
    }

    set bufFull [lindex $bufMatches 0]
    set ni [get_db insts $bufFull]

    if {[get_db $ni .base_cell.name] ne $cell} {
        error "HOLD_ECO_ITER2_MASTER_MISMATCH: idx=$idx"
    }

    set biNet [get_db [get_db pins ${bufFull}/I] .net.name]
    set bzNet [get_db [get_db pins ${bufFull}/Z] .net.name]
    set tpNet [get_db [get_db pins $pin] .net.name]

    if {$biNet ne $oldNet} {
        error "HOLD_ECO_ITER2_INPUT_NET_MISMATCH: idx=$idx"
    }

    if {[file tail $bzNet] ne $netBase} {
        error "HOLD_ECO_ITER2_OUTPUT_NET_MISMATCH: idx=$idx actual=$bzNet"
    }

    if {$tpNet ne $bzNet} {
        error "HOLD_ECO_ITER2_TARGET_NET_MISMATCH: idx=$idx"
    }

    puts "ITER2_INSERT_OK idx=$idx buffer=$bufFull oldNet=$oldNet newNet=$bzNet"
}

puts "HOLD_ECO_ITER2_LOGICAL_PASS"


# ----------------------------------------------------------------------
# 4. Placement
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: PLACE ====="

ecoPlace \
    -fixPlacedInsts true \
    -timing_driven false

foreach item $eco_spec {

    lassign $item idx cell pin

    set matches [lsearch -all -inline -glob \
        [get_db insts .name] "*U_PTECO2_HOLD_BUF${idx}"]

    if {[llength $matches] != 1} {
        error "HOLD_ECO_ITER2_PLACE_MATCH_FAILED: idx=$idx"
    }

    set ni [get_db insts [lindex $matches 0]]

    if {[get_db $ni .place_status] ne "placed"} {
        error "HOLD_ECO_ITER2_NOT_PLACED: idx=$idx status=[get_db $ni .place_status]"
    }

    puts "ITER2_PLACED idx=$idx inst=[get_db $ni .name] loc=[get_db $ni .location]"
}

puts "HOLD_ECO_ITER2_PLACE_PASS"


# ----------------------------------------------------------------------
# 5. ECO route
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: ROUTE ====="

ecoRoute

setEcoMode -updateTiming true

puts "HOLD_ECO_ITER2_ROUTE_DONE"


# ----------------------------------------------------------------------
# 6. Restore standard fillers
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: RESTORE STANDARD FILLERS ====="

addFiller -cell {FILL64BWP30P140 FILL32BWP30P140 FILL16BWP30P140 FILL8BWP30P140 FILL4BWP30P140 FILL3BWP30P140 FILL2BWP30P140} -prefix FILL

puts "STD_FILL_FINAL=[llength [get_db insts FILL*]]"
puts "IO_FILL_FINAL=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] == 0} {
    error "HOLD_ECO_ITER2_FILLER_RESTORE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "HOLD_ECO_ITER2_IO_FILLER_FINAL_CHANGED"
}


# ----------------------------------------------------------------------
# 7. Verify physical implementation
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: CONNECTIVITY ====="

verifyConnectivity \
    -type all \
    -error 100000 \
    -report hold_eco_iter2_verify_conn.rpt

set fh [open hold_eco_iter2_verify_conn.rpt r]
set txt [read $fh]
close $fh

if {[string first "Found no problems or warnings." $txt] < 0} {
    error "HOLD_ECO_ITER2_CONNECTIVITY_FAILED"
}

puts "HOLD_ECO_ITER2_CONNECTIVITY_PASS"


puts "===== HOLD ECO ITER2: DRC ====="

verify_drc \
    -check_same_via_cell \
    -limit 100000 \
    -report hold_eco_iter2_verify_drc.rpt

set fh [open hold_eco_iter2_verify_drc.rpt r]
set txt [read $fh]
close $fh

if {[string first "No DRC violations were found" $txt] < 0} {
    error "HOLD_ECO_ITER2_DRC_FAILED"
}

puts "HOLD_ECO_ITER2_DRC_PASS"


# ----------------------------------------------------------------------
# 8. Verify both ECO generations still exist
# ----------------------------------------------------------------------

set iter1Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

set iter2Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO2_HOLD_BUF*"]

puts "ITER1_BUFFER_COUNT_FINAL=[llength $iter1Final]"
puts "ITER2_BUFFER_COUNT_FINAL=[llength $iter2Final]"

if {[llength $iter1Final] != 29} {
    error "HOLD_ECO_ITER2_LOST_ITER1_BUFFERS"
}

if {[llength $iter2Final] != 2} {
    error "HOLD_ECO_ITER2_BAD_FINAL_BUFFER_COUNT"
}


# ----------------------------------------------------------------------
# 9. Innovus timing sanity
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: TIMING ====="

file mkdir timingReports

timeDesign \
    -postRoute \
    -numPaths 20 \
    -prefix hold_eco_iter2_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -numPaths 20 \
    -prefix hold_eco_iter2_hold \
    -outDir timingReports


# ----------------------------------------------------------------------
# 10. Save a NEW trial DB only
# ----------------------------------------------------------------------

puts "===== HOLD ECO ITER2: SAVE ====="

saveDesign \
    ../dataout/design_saves/final_hold_eco_iter2_trial

puts "##### HOLD_ECO_ITER2_PHYSICAL_PASS #####"
puts "Saved: ../dataout/design_saves/final_hold_eco_iter2_trial"

exit
