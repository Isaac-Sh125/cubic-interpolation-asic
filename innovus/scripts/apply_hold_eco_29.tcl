# ======================================================================
# apply_hold_eco_29.tcl
#
# Apply the 29-buffer PrimeTime Hold ECO to the canonical clean final.dat.
#
# Source DB:
#   ../dataout/design_saves/final.dat
#
# Output DB:
#   ../dataout/design_saves/final_hold_eco_trial
#
# The canonical final.dat is NEVER overwritten.
# ======================================================================

setDesignMode -process 28
setMultiCpuUsage -local 8

puts "===== HOLD ECO: RESTORE CLEAN FINAL ====="

restoreDesign \
    ../dataout/design_saves/final.dat \
    top


# ----------------------------------------------------------------------
# PrimeTime-proposed Hold ECO:
#   {index  cell  target_pin}
# ----------------------------------------------------------------------

set eco_spec {

    {1  DEL025D1BWP30P140 I0/u_path_I_u_fir/y_out_reg_15_/D}
    {2  DEL025D1BWP30P140 I0/u_path_I_u_fir/acc_stage_reg_4__9_/D}
    {3  DEL025D1BWP30P140 I0/u_path_I_u_interp/sample_cnt_reg_15_/D}
    {4  DEL025D1BWP30P140 I0/u_path_Q_u_interp/p0_reg_4_/D}
    {5  DEL025D1BWP30P140 I0/u_path_Q_u_fir/y_out_reg_5_/D}
    {6  DEL025D1BWP30P140 I0/u_path_I_u_interp/p3_reg_0_/D}
    {7  DEL025D1BWP30P140 I0/u_path_I_u_fir/y_out_reg_9_/D}
    {8  DEL025D1BWP30P140 I0/u_path_Q_u_interp/p1_reg_13_/D}
    {9  DEL025D1BWP30P140 I0/u_path_I_u_fir/y_out_reg_12_/D}

    {10 BUFFD0BWP30P140    I0/u_path_Q_u_fir/U1368/A1}

    {11 DEL025D1BWP30P140 I0/u_path_I_u_interp/p1_reg_15_/D}
    {12 DEL025D1BWP30P140 I0/u_path_Q_u_fir/y_out_reg_9_/D}

    {13 BUFFD0BWP30P140    I0/u_path_Q_u_fir/U1320/A1}

    {14 DEL025D1BWP30P140 I0/u_path_Q_u_interp/y0_reg_14_/D}
    {15 DEL025D1BWP30P140 I0/u_path_Q_u_interp/y0_reg_10_/D}
    {16 DEL025D1BWP30P140 I0/u_control_cfg_valid_reg/D}
    {17 DEL025D1BWP30P140 I0/u_path_Q_u_interp/p2_reg_14_/D}
    {18 DEL025D1BWP30P140 I0/u_path_Q_u_fir/acc_stage_reg_1__33_/D}
    {19 DEL025D1BWP30P140 I0/u_path_I_u_interp/p1_reg_11_/D}
    {20 DEL025D1BWP30P140 I0/u_path_I_u_interp/sample_cnt_reg_10_/D}
    {21 DEL025D1BWP30P140 I0/u_path_I_u_sipo_shift_reg_reg_15_/D}

    {22 BUFFD0BWP30P140    I0/u_path_Q_u_fir/U1366/A1}

    {23 DEL025D1BWP30P140 I0/u_path_Q_u_interp/p0_reg_8_/D}
    {24 DEL025D1BWP30P140 I0/u_path_Q_u_interp/p2_reg_2_/D}
    {25 DEL025D1BWP30P140 I0/u_path_I_u_interp/U11234/A1}
    {26 DEL025D1BWP30P140 I0/u_path_I_u_interp/y0_reg_8_/D}
    {27 DEL025D1BWP30P140 I0/u_path_Q_u_interp/p2_reg_4_/D}

    {28 BUFFD0BWP30P140    I0/u_path_I_u_fir/U1375/A1}

    {29 DEL025D1BWP30P140 I0/u_path_Q_u_fir/acc_stage_reg_2__0_/D}
}


# ----------------------------------------------------------------------
# 1. Hard preflight
# ----------------------------------------------------------------------

puts "===== HOLD ECO: PREFLIGHT ====="

if {[llength $eco_spec] != 29} {
    error "HOLD_ECO_BAD_SPEC_COUNT: expected 29, got [llength $eco_spec]"
}

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]

    if {[llength $tp] != 1} {
        error "HOLD_ECO_TARGET_NOT_UNIQUE: idx=$idx pin=$pin count=[llength $tp]"
    }

    set bc [get_db base_cells $cell]

    if {[llength $bc] != 1} {
        error "HOLD_ECO_MASTER_NOT_UNIQUE: idx=$idx cell=$cell count=[llength $bc]"
    }

    set existingBufs [lsearch -all -inline -glob         [get_db insts .name] "*U_PTECO_HOLD_BUF${idx}"]

    if {[llength $existingBufs] != 0} {
        error "HOLD_ECO_BUFFER_ALREADY_EXISTS: idx=$idx matches=$existingBufs"
    }
}

puts "HOLD_ECO_PREFLIGHT_PASS"


# ----------------------------------------------------------------------
# 2. Remove only standard-cell fillers.
#    IO_FILLER* pad-ring cells must remain untouched.
# ----------------------------------------------------------------------

puts "===== HOLD ECO: REMOVE STANDARD FILLERS ====="

set stdFillBefore [llength [get_db insts FILL*]]
set ioFillBefore  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_BEFORE=$stdFillBefore"
puts "IO_FILL_BEFORE=$ioFillBefore"

deleteFiller -prefix FILL

set stdFillAfterDelete [llength [get_db insts FILL*]]
set ioFillAfterDelete  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_AFTER_DELETE=$stdFillAfterDelete"
puts "IO_FILL_AFTER_DELETE=$ioFillAfterDelete"

if {$stdFillAfterDelete != 0} {
    error "HOLD_ECO_FILLER_DELETE_FAILED"
}

if {$ioFillAfterDelete != $ioFillBefore} {
    error "HOLD_ECO_IO_FILLER_COUNT_CHANGED"
}


# ----------------------------------------------------------------------
# 3. Insert the 29 logical ECO buffers.
#    Disable per-command timing updates; timing is recomputed after routing.
# ----------------------------------------------------------------------

puts "===== HOLD ECO: INSERT 29 BUFFERS ====="

setEcoMode -updateTiming false

foreach item $eco_spec {

    lassign $item idx cell pin

    set tp [get_db pins $pin]
    set oldNet [get_db $tp .net.name]

    set bufBase "U_PTECO_HOLD_BUF${idx}"
    set netBase "net_PTECO_HOLD_NET${idx}"

    puts "HOLD_ECO_INSERT idx=$idx cell=$cell pin=$pin"

    ecoAddRepeater \
        -term [list $pin] \
        -cell $cell \
        -name $bufBase \
        -newNetName $netBase \
        -noPlace

    set bufMatches [lsearch -all -inline -glob         [get_db insts .name] "*${bufBase}"]

    if {[llength $bufMatches] != 1} {
        error "HOLD_ECO_INSERT_FAILED: idx=$idx matches=$bufMatches"
    }

    set bufFull [lindex $bufMatches 0]
    set ni [get_db insts $bufFull]

    set actualMaster [get_db $ni .base_cell.name]
    if {$actualMaster ne $cell} {
        error "HOLD_ECO_MASTER_MISMATCH: idx=$idx expected=$cell actual=$actualMaster"
    }

    set bi [get_db pins ${bufFull}/I]
    set bz [get_db pins ${bufFull}/Z]
    set tp [get_db pins $pin]

    set biNet [get_db $bi .net.name]
    set bzNet [get_db $bz .net.name]
    set tpNet [get_db $tp .net.name]

    if {$biNet ne $oldNet} {
        error "HOLD_ECO_INPUT_NET_MISMATCH: idx=$idx expected=$oldNet actual=$biNet"
    }

    if {[file tail $bzNet] ne $netBase} {
        error "HOLD_ECO_OUTPUT_NET_NAME_MISMATCH: idx=$idx expectedTail=$netBase actual=$bzNet"
    }

    if {$tpNet ne $bzNet} {
        error "HOLD_ECO_TARGET_NET_MISMATCH: idx=$idx bufferNet=$bzNet targetNet=$tpNet"
    }

    puts "HOLD_ECO_INSERT_OK idx=$idx buffer=$bufFull oldNet=$oldNet newNet=$bzNet"
}

puts "HOLD_ECO_LOGICAL_INSERT_PASS"


# ----------------------------------------------------------------------
# 4. ECO placement
# ----------------------------------------------------------------------

puts "===== HOLD ECO: PLACE ====="

ecoPlace \
    -fixPlacedInsts true \
    -timing_driven false

set badPlaced {}

foreach item $eco_spec {

    lassign $item idx cell pin

    set bufMatches [lsearch -all -inline -glob         [get_db insts .name] "*U_PTECO_HOLD_BUF${idx}"]

    if {[llength $bufMatches] != 1} {
        lappend badPlaced "idx=$idx:MATCHES=$bufMatches"
        continue
    }

    set bufFull [lindex $bufMatches 0]
    set ni [get_db insts $bufFull]
    set ps [get_db $ni .place_status]

    if {$ps ne "placed"} {
        lappend badPlaced "$bufFull:$ps"
    }
}

if {[llength $badPlaced] != 0} {
    error "HOLD_ECO_UNPLACED_BUFFERS: $badPlaced"
}

puts "HOLD_ECO_PLACE_PASS"


# ----------------------------------------------------------------------
# 5. ECO routing
# ----------------------------------------------------------------------

puts "===== HOLD ECO: ROUTE ====="

ecoRoute

setEcoMode -updateTiming true

puts "HOLD_ECO_ROUTE_DONE"


# ----------------------------------------------------------------------
# 6. Restore standard-cell fillers
# ----------------------------------------------------------------------

puts "===== HOLD ECO: RESTORE STANDARD FILLERS ====="

addFiller -cell {FILL64BWP30P140 FILL32BWP30P140 FILL16BWP30P140 FILL8BWP30P140 FILL4BWP30P140 FILL3BWP30P140 FILL2BWP30P140} -prefix FILL

set stdFillFinal [llength [get_db insts FILL*]]
set ioFillFinal  [llength [get_db insts IO_FILLER*]]

puts "STD_FILL_FINAL=$stdFillFinal"
puts "IO_FILL_FINAL=$ioFillFinal"

if {$stdFillFinal == 0} {
    error "HOLD_ECO_FILLER_RESTORE_FAILED"
}

if {$ioFillFinal != $ioFillBefore} {
    error "HOLD_ECO_IO_FILLER_FINAL_COUNT_CHANGED"
}


# ----------------------------------------------------------------------
# 7. Physical verification
# ----------------------------------------------------------------------

puts "===== HOLD ECO: CONNECTIVITY ====="

verifyConnectivity \
    -type all \
    -error 100000 \
    -report hold_eco_verify_conn.rpt

set fh [open hold_eco_verify_conn.rpt r]
set connText [read $fh]
close $fh

if {[string first "Found no problems or warnings." $connText] < 0} {
    error "HOLD_ECO_CONNECTIVITY_FAILED"
}

puts "HOLD_ECO_CONNECTIVITY_PASS"


puts "===== HOLD ECO: DRC ====="

verify_drc \
    -check_same_via_cell \
    -limit 100000 \
    -report hold_eco_verify_drc.rpt

set fh [open hold_eco_verify_drc.rpt r]
set drcText [read $fh]
close $fh

if {[string first "No DRC violations were found" $drcText] < 0} {
    error "HOLD_ECO_DRC_FAILED"
}

puts "HOLD_ECO_DRC_PASS"


# ----------------------------------------------------------------------
# 8. Innovus timing sanity after physical ECO
# ----------------------------------------------------------------------

puts "===== HOLD ECO: INNOVUS TIMING ====="

file mkdir timingReports

timeDesign \
    -postRoute \
    -numPaths 20 \
    -prefix hold_eco_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -numPaths 20 \
    -prefix hold_eco_hold \
    -outDir timingReports


# ----------------------------------------------------------------------
# 9. Save ONLY the ECO trial DB.
#    Never overwrite canonical final.dat.
# ----------------------------------------------------------------------

puts "===== HOLD ECO: SAVE TRIAL ====="

saveDesign \
    ../dataout/design_saves/final_hold_eco_trial

puts "##### HOLD_ECO_29_PHYSICAL_PASS #####"
puts "Saved: ../dataout/design_saves/final_hold_eco_trial"

exit
