# ==========================================================================
# power_analysis.tcl   TSMC 28nm (28HPCPMMWAVE)  --  static signoff power
# --------------------------------------------------------------------------
# TSMC 28 nm post-route power-analysis flow. Assumes a POST-ROUTE design is
# ALREADY loaded (this script does NOT restore). Source it in a live session:
#     source ../scripts/power_analysis.tcl
#
# Every step is catch-guarded, so the session is never aborted.
#   0. blocks saveDesign  (report_power / Voltus poisons a later save)
#   1. ensures SlowView(setup,ss) / FastView(hold,ff) analysis views exist
#   2. globalNetConnect for the 5 PG pins + tiehi/tielo, applyGlobalNets
#   3. extractRC on the active (Slow/ss) corner
#   4. report_power (STATIC) at the ss corner (SlowView, 0.81V, 125C):
#        - full chip                                -> power_signoff/slowRC/chip_full.rpt
#        - VS-format (static currents for ir_rail)  -> .../chip_vs.rpt + *.ptiavg
#        - per block (I0 core, fir/interp I and Q)  -> .../<blk>.rpt
#   5. writes power_signoff/summary.txt  (mW, activity model stated)
#
# ACTIVITY MODEL: vectorless, set_default_switching_activity 0.2 @ 1.04 ns.
#   To use the gate-level VCD instead, set  ::PWR_USE_VCD 1  before sourcing
#   (6.8 GB at design_tb/dut -> I0 ; check annotation coverage in the log).
# ==========================================================================

set PSD ./power_signoff
file mkdir $PSD $PSD/slowRC
set _plg [open $PSD/flow_log.txt a]
proc pnote {m} { global _plg; puts "PWR: $m"; catch { puts $_plg "PWR: $m"; flush $_plg } }
pnote "==== power_analysis start [clock format [clock seconds]]  design=[dbGet top.name] ===="

# ---------------- config ----------------
set VDDC_NET VDDC ; set VSSC_NET VSSC
set VDDP_NET VDDP ; set VSSP_NET VSSP ; set POC_NET POC
set SS_VOLT 0.81
set PERIOD  1.04
if {![info exists ::PWR_USE_VCD]} { set ::PWR_USE_VCD 0 }
set VCD_FILE  /project/verif/users/yitzhak2/ws/ex_vlsi_1/Pchip/GL_sim/gl_sim.vcd
set VCD_SCOPE design_tb/dut

# per-block table: {tag hierInstance ...}. Non-existent ones are caught/skipped.
set BLOCKS [list \
  core     I0 \
  fir_I    I0/u_path_I_u_fir \
  interp_I I0/u_path_I_u_interp \
  fir_Q    I0/u_path_Q_u_fir \
  interp_Q I0/u_path_Q_u_interp ]

# ---------------- 0. make saveDesign a no-op for this session ----------------
if {[info commands _pa_real_saveDesign] eq ""} { catch { rename saveDesign _pa_real_saveDesign } }
proc saveDesign {args} { pnote "saveDesign BLOCKED (power session): $args" }
pnote "saveDesign disabled (protects the good routed .dat saves)"

# ---------------- 1. analysis views ----------------
set _need_views 0
if {[catch { set _views [get_analysis_views] } e]} { set _need_views 1 } \
elseif {$_views eq "" || $_views == 0} { set _need_views 1 }
if {$_need_views} {
    pnote "no analysis views in memory -> read_mmmc ../datain/mmmc.view"
    catch { read_mmmc ../datain/mmmc.view }
}
catch { set_analysis_view -setup SlowView -hold FastView }
catch { pnote "analysis views: [get_analysis_views]" }

# ---------------- 2. global PG connect (5 pins) + tie ----------------
catch { globalNetConnect $VDDC_NET -type pgpin -pin VDD    -instanceBasename * -override }
catch { globalNetConnect $VSSC_NET -type pgpin -pin VSS    -instanceBasename * -override }
catch { globalNetConnect $VDDP_NET -type pgpin -pin VDDPST -instanceBasename * -override }
catch { globalNetConnect $VSSP_NET -type pgpin -pin VSSPST -instanceBasename * -override }
catch { globalNetConnect $POC_NET  -type pgpin -pin POC    -instanceBasename * -override }
catch { globalNetConnect $VDDC_NET -type tiehi -all }
catch { globalNetConnect $VSSC_NET -type tielo -all }
catch { applyGlobalNets }
pnote "globalNetConnect: core VDDC/VSSC ; pads VDDP/VSSP/POC ; tiehi/tielo"

# ---------------- 3. parasitics on the ss corner ----------------
catch { setAnalysisMode -analysisType onChipVariation -cppr both }
if {[catch { extractRC } e]} { pnote "extractRC WARN: $e" } else { pnote "extractRC done (active RC corner = SlowRC/cworst)" }

# ---------------- 4. static power at ss (SlowView) ----------------
catch { set_power_analysis_mode -reset }
catch { set_power_output_dir   -reset }
catch { set_default_switching_activity -reset }
catch { read_activity_file     -reset }
catch { set_power              -reset }
catch { set_dynamic_power_simulation -reset }

catch { set_power_analysis_mode -method static -create_binary_db true \
        -write_static_currents true -honor_negative_energy true \
        -ignore_control_signals true }
catch { set_power_output_dir $PSD/slowRC }

# activity
set ACT "DEFAULT(input=0.2 seq=0.2 @ ${PERIOD}ns)"
catch { set_default_switching_activity -input_activity 0.2 -period $PERIOD -seq_activity 0.2 }
if {$::PWR_USE_VCD} {
    if {[file exists $VCD_FILE]} {
        if {![catch { read_activity_file -format VCD -scope $VCD_SCOPE $VCD_FILE } e]} {
            set ACT "VCD($VCD_SCOPE)"
            pnote "VCD annotated from $VCD_SCOPE -- CHECK coverage percent in log before trusting numbers"
        } else { pnote "VCD read failed ($e) -> staying on default 0.2 activity" }
    } else { pnote "VCD not found ($VCD_FILE) -> default 0.2 activity" }
}
pnote "activity model = $ACT   corner = SlowView (ss 0.81V 125C, SlowRC/cworst)"

# full chip (human readable, used for the summary total)
if {[catch { report_power -outfile $PSD/slowRC/chip_full.rpt } e]} { pnote "report_power chip_full: $e" }
# VS format -> also emits static_<net>.ptiavg current files consumed by ir_rail.tcl
if {[catch { report_power -rail_analysis_format VS -outfile $PSD/slowRC/chip_vs.rpt } e]} { pnote "report_power VS: $e" }
# per block
foreach {tag inst} $BLOCKS {
    if {[catch { report_power -instances $inst -outfile $PSD/slowRC/${tag}.rpt } e]} {
        pnote "report_power block $tag ($inst): $e"
    }
}
pnote "static currents expected: $PSD/slowRC/static_${VDDC_NET}.ptiavg / static_${VSSC_NET}.ptiavg"

# ---------------- 5. summary.txt ----------------
# report unit: header line "Power Units = 1mW" (this tool). scale to mW.
proc _unit_scale {txt} {
    if {[regexp -nocase {Power Units?\s*[:=]\s*1?\s*([munpMUNP]?)W} $txt -> u]} {
        switch -- [string tolower $u] {
            m  { return 1.0 }
            u  { return 0.001 }
            n  { return 1.0e-6 }
            p  { return 1.0e-9 }
            "" { return 1000.0 }
            default { return 1.0 }
        }
    }
    return 1.0
}
# design-level totals (top "Total ... Power:" summary block)
proc _chip_totals {f} {
    if {![file exists $f]} { return {- - - - -} }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set sc [_unit_scale $txt]
    set intn - ; set sw - ; set lk - ; set tot -
    foreach ln [split $txt "\n"] {
        if {[regexp -nocase {Total Internal Power[^0-9-]*([-0-9.eE+]+)}  $ln -> v]} { set intn [format %.4f [expr {$v*$sc}]] }
        if {[regexp -nocase {Total Switching Power[^0-9-]*([-0-9.eE+]+)} $ln -> v]} { set sw   [format %.4f [expr {$v*$sc}]] }
        if {[regexp -nocase {Total Leakage Power[^0-9-]*([-0-9.eE+]+)}   $ln -> v]} { set lk   [format %.4f [expr {$v*$sc}]] }
        if {[regexp -nocase {^Total Power[^0-9-]*([-0-9.eE+]+)}          $ln -> v]} { set tot  [format %.4f [expr {$v*$sc}]] }
    }
    return [list $intn $sw $lk $tot $sc]
}
# per-instance power from the bottom "Instance ... Total" table
proc _block_power {f inst} {
    if {![file exists $f]} { return "-" }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set sc [_unit_scale $txt]
    foreach ln [split $txt "\n"] {
        if {[lindex $ln 0] eq $inst} {
            # drop the instance-name token first (it may contain digits, e.g. I0)
            set nums [regexp -all -inline {[-0-9.]+(?:[eE][-+]?[0-9]+)?} [lrange $ln 1 end]]
            # cols after name: MaxTog TotTog Internal Switching Leakage Total Percentage
            if {[llength $nums] >= 6} { return [format %.4f [expr {[lindex $nums 5]*$sc}]] }
        }
    }
    return "-"
}
# rail table (Rail Voltage Internal Switching Leakage Total Percentage)
proc _rail_power {f rail} {
    if {![file exists $f]} { return "-" }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set sc [_unit_scale $txt]
    foreach ln [split $txt "\n"] {
        if {[lindex $ln 0] eq $rail} {
            set nums [regexp -all -inline {[-0-9.]+(?:[eE][-+]?[0-9]+)?} $ln]
            # cols: Voltage Internal Switching Leakage Total Percentage
            if {[llength $nums] >= 5} { return [format %.4f [expr {[lindex $nums 4]*$sc}]] }
        }
    }
    return "-"
}

set CF $PSD/slowRC/chip_full.rpt
set out [open $PSD/summary.txt w]
puts $out "======================================================================"
puts $out " STATIC POWER SUMMARY   design=[dbGet top.name]   (all values in mW)"
puts $out " [clock format [clock seconds]]"
puts $out " corner   : SlowView  (ss 0.81V, 125C, SlowRC=cworst)"
puts $out " activity : $ACT"
puts $out " method   : vectorless static (set_power_analysis_mode -method static)"
puts $out "======================================================================"
puts $out ""
set c [_chip_totals $CF]
puts $out "FULL CHIP:"
puts $out [format "   Internal  = %s mW" [lindex $c 0]]
puts $out [format "   Switching = %s mW" [lindex $c 1]]
puts $out [format "   Leakage   = %s mW" [lindex $c 2]]
puts $out [format "   TOTAL     = %s mW" [lindex $c 3]]
puts $out ""
puts $out "BY POWER RAIL (from chip report):"
puts $out [format "   %-6s %12s" "rail" "total(mW)"]
foreach r {VDDC VSSC VDDP VSSP POC} {
    set rp [_rail_power $CF $r]
    if {$rp ne "-"} { puts $out [format "   %-6s %12s" $r $rp] }
}
puts $out ""
puts $out "PER-BLOCK (core-internal instances, VDDC domain):"
puts $out [format "   %-10s %12s   %s" "block" "total(mW)" "instance"]
foreach {tag inst} $BLOCKS {
    set bp [_block_power $PSD/slowRC/${tag}.rpt $inst]
    puts $out [format "   %-10s %12s   %s" $tag $bp $inst]
}
close $out

pnote "---- summary ----"
set fp [open $PSD/summary.txt r]; puts [read $fp]; close $fp
pnote "wrote $PSD/summary.txt ; reports in $PSD/slowRC/ . saveDesign stays blocked."
pnote "==== power_analysis done ===="
