# ======================================================================
# apply_scan_en_fix_iter4.tcl
#
# Physical ECO iteration #4:
#   Fix max-fanout violation on scan_en pad.
#
# Input:
#   final_hold_eco_iter3_trial.dat
#
# Existing ECOs preserved:
#   29 x U_PTECO_HOLD_BUF*
#    2 x U_PTECO2_HOLD_BUF*
#    4 x U_PTECO3_CG_BUF*
#
# Add:
#    1 x BUFFD2BWP30P140
#
# Output:
#   final_hold_eco_iter4b_trial
# ======================================================================

setDesignMode -process 28
setMultiCpuUsage -local 8

puts "===== SCAN_EN ECO ITER4: RESTORE ITER3 DB ====="

restoreDesign \
    ../dataout/design_saves/final_hold_eco_iter3_trial.dat \
    top


# ----------------------------------------------------------------------
# 1. Preflight
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: PREFLIGHT ====="

set iter1 [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

set iter2 [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO2_HOLD_BUF*"]

set iter3 [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO3_CG_BUF*"]

puts "ITER1_BUFFER_COUNT=[llength $iter1]"
puts "ITER2_BUFFER_COUNT=[llength $iter2]"
puts "ITER3_BUFFER_COUNT=[llength $iter3]"

if {[llength $iter1] != 29} {
    error "SCAN_ECO_ITER4_BAD_ITER1_COUNT"
}

if {[llength $iter2] != 2} {
    error "SCAN_ECO_ITER4_BAD_ITER2_COUNT"
}

if {[llength $iter3] != 4} {
    error "SCAN_ECO_ITER4_BAD_ITER3_COUNT"
}

set sn [get_db nets wire_scan_en]

if {[llength $sn] != 1} {
    error "SCAN_ECO_ITER4_BAD_SCAN_NET_COUNT"
}

set scanLoads [lsort [get_db $sn .load_pins.name]]

puts "SCAN_DRIVER=[get_db $sn .driver_pins.name]"
puts "SCAN_LOAD_COUNT_BEFORE=[llength $scanLoads]"

if {[get_db $sn .driver_pins.name] ne "I9/I1/C"} {
    error "SCAN_ECO_ITER4_BAD_DRIVER"
}

if {[llength $scanLoads] != 42} {
    error "SCAN_ECO_ITER4_BAD_LOAD_COUNT"
}

foreach p $scanLoads {
    if {[file tail $p] ne "SE"} {
        error "SCAN_ECO_ITER4_NON_SE_LOAD: $p"
    }
}

if {[llength [get_db base_cells BUFFD2BWP30P140]] != 1} {
    error "SCAN_ECO_ITER4_BUFFD1_NOT_FOUND"
}

if {[llength [get_db insts U_SCAN_EN_BUF]] != 0} {
    error "SCAN_ECO_ITER4_BUFFER_ALREADY_EXISTS"
}

puts "SCAN_ECO_ITER4_PREFLIGHT_PASS"


# ----------------------------------------------------------------------
# 2. Remove standard-cell fillers only
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: REMOVE STANDARD FILLERS ====="

set stdFillBefore [llength [get_db insts FILL*]]
set ioFillBefore  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_BEFORE=$stdFillBefore"
puts "IO_FILL_BEFORE=$ioFillBefore"

deleteFiller -prefix FILL

puts "STD_FILL_AFTER_DELETE=[llength [get_db insts FILL*]]"
puts "IO_FILL_AFTER_DELETE=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] != 0} {
    error "SCAN_ECO_ITER4_FILLER_DELETE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "SCAN_ECO_ITER4_IO_FILLERS_CHANGED"
}


# ----------------------------------------------------------------------
# 3. Insert logical scan_en buffer
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: INSERT BUFFER ====="

setEcoMode -updateTiming false

ecoAddRepeater \
    -term $scanLoads \
    -cell BUFFD2BWP30P140 \
    -name U_SCAN_EN_BUF \
    -newNetName net_scan_en_buffered \
    -noPlace

set scanBufMatches [lsearch -all -inline -glob \
    [get_db insts .name] "*U_SCAN_EN_BUF*"]

if {[llength $scanBufMatches] != 1} {
    error "SCAN_ECO_ITER4_INSERT_FAILED: matches=$scanBufMatches"
}

set scanBuf [lindex $scanBufMatches 0]
set scanBufObj [get_db insts $scanBuf]

if {[get_db $scanBufObj .base_cell.name] ne "BUFFD2BWP30P140"} {
    error "SCAN_ECO_ITER4_WRONG_MASTER"
}

set upstreamNet [get_db [get_db pins ${scanBuf}/I] .net]
set downstreamNet [get_db [get_db pins ${scanBuf}/Z] .net]

set upDriver [get_db $upstreamNet .driver_pins.name]
set upLoads  [get_db $upstreamNet .load_pins.name]

set downDriver [get_db $downstreamNet .driver_pins.name]
set downLoads  [get_db $downstreamNet .load_pins.name]

puts "SCAN_BUF=$scanBuf"
puts "UPSTREAM_DRIVER=$upDriver"
puts "UPSTREAM_LOAD_COUNT=[llength $upLoads]"
puts "DOWNSTREAM_DRIVER=$downDriver"
puts "DOWNSTREAM_LOAD_COUNT=[llength $downLoads]"

if {$upDriver ne "I9/I1/C"} {
    error "SCAN_ECO_ITER4_UPSTREAM_DRIVER_MISMATCH"
}

if {[llength $upLoads] != 1} {
    error "SCAN_ECO_ITER4_UPSTREAM_LOAD_COUNT_BAD"
}

if {[llength $downLoads] != 42} {
    error "SCAN_ECO_ITER4_DOWNSTREAM_LOAD_COUNT_BAD"
}

puts "SCAN_ECO_ITER4_LOGICAL_PASS"


# ----------------------------------------------------------------------
# 4. Placement
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: PLACE ====="

ecoPlace \
    -fixPlacedInsts true \
    -timing_driven false

set scanBufObj [get_db insts $scanBuf]

puts "SCAN_BUF_STATUS=[get_db $scanBufObj .place_status]"
puts "SCAN_BUF_LOCATION=[get_db $scanBufObj .location]"

if {[get_db $scanBufObj .place_status] ne "placed"} {
    error "SCAN_ECO_ITER4_NOT_PLACED"
}

puts "SCAN_ECO_ITER4_PLACE_PASS"


# ----------------------------------------------------------------------
# 5. Route
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: ROUTE ====="

ecoRoute

setEcoMode -updateTiming true

puts "SCAN_ECO_ITER4_ROUTE_DONE"


# ----------------------------------------------------------------------
# 6. Restore fillers
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: RESTORE FILLERS ====="

addFiller -cell {FILL64BWP30P140 FILL32BWP30P140 FILL16BWP30P140 FILL8BWP30P140 FILL4BWP30P140 FILL3BWP30P140 FILL2BWP30P140} -prefix FILL

puts "STD_FILL_FINAL=[llength [get_db insts FILL*]]"
puts "IO_FILL_FINAL=[llength [get_db insts IO_FILLER*]]"

if {[llength [get_db insts FILL*]] == 0} {
    error "SCAN_ECO_ITER4_FILLER_RESTORE_FAILED"
}

if {[llength [get_db insts IO_FILLER*]] != $ioFillBefore} {
    error "SCAN_ECO_ITER4_IO_FILLER_FINAL_CHANGED"
}


# ----------------------------------------------------------------------
# 7. Connectivity + DRC
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: CONNECTIVITY ====="

verifyConnectivity \
    -type all \
    -error 100000 \
    -report scan_en_eco_iter4_verify_conn.rpt

set fh [open scan_en_eco_iter4_verify_conn.rpt r]
set txt [read $fh]
close $fh

if {[string first "Found no problems or warnings." $txt] < 0} {
    error "SCAN_ECO_ITER4_CONNECTIVITY_FAILED"
}

puts "SCAN_ECO_ITER4_CONNECTIVITY_PASS"


puts "===== SCAN_EN ECO ITER4: DRC ====="

verify_drc \
    -check_same_via_cell \
    -limit 100000 \
    -report scan_en_eco_iter4_verify_drc.rpt

set fh [open scan_en_eco_iter4_verify_drc.rpt r]
set txt [read $fh]
close $fh

if {[string first "No DRC violations were found" $txt] < 0} {
    error "SCAN_ECO_ITER4_DRC_FAILED"
}

puts "SCAN_ECO_ITER4_DRC_PASS"


# ----------------------------------------------------------------------
# 8. Confirm previous ECO generations remain
# ----------------------------------------------------------------------

set iter1Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO_HOLD_BUF*"]

set iter2Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO2_HOLD_BUF*"]

set iter3Final [lsearch -all -inline -glob \
    [get_db insts .name] "*U_PTECO3_CG_BUF*"]

puts "ITER1_BUFFER_COUNT_FINAL=[llength $iter1Final]"
puts "ITER2_BUFFER_COUNT_FINAL=[llength $iter2Final]"
puts "ITER3_BUFFER_COUNT_FINAL=[llength $iter3Final]"

if {[llength $iter1Final] != 29} {
    error "SCAN_ECO_ITER4_LOST_ITER1"
}

if {[llength $iter2Final] != 2} {
    error "SCAN_ECO_ITER4_LOST_ITER2"
}

if {[llength $iter3Final] != 4} {
    error "SCAN_ECO_ITER4_LOST_ITER3"
}


# ----------------------------------------------------------------------
# 9. Innovus timing + DRV reports
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: TIMING ====="

file mkdir timingReports

timeDesign \
    -postRoute \
    -numPaths 20 \
    -prefix scan_eco_iter4_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -numPaths 20 \
    -prefix scan_eco_iter4_hold \
    -outDir timingReports


# ----------------------------------------------------------------------
# 10. Save new trial DB
# ----------------------------------------------------------------------

puts "===== SCAN_EN ECO ITER4: SAVE ====="

saveDesign \
    ../dataout/design_saves/final_hold_eco_iter4b_trial

puts "##### SCAN_ECO_ITER4B_PHYSICAL_PASS #####"
puts "Saved: ../dataout/design_saves/final_hold_eco_iter4b_trial"

exit
