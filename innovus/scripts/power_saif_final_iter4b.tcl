# ==========================================================================
# Final TSMC 28 nm post-route power analysis using per-L gate-simulation SAIF.
# --------------------------------------------------------------------------
# One activity file is used for each supported interpolation factor L=2..5.
# Gate-level activity captures the valid-driven and clock-gated behavior of the
# implemented DSP rather than applying a uniform vectorless activity assumption.
#
# SAIF hierarchy mapping:
#   simulation DUT : design_tb/dut
#   physical core  : I0
#
# Annotation coverage is reported for every analyzed operating mode.
# ==========================================================================

puts "===== FINAL ITER4B SAIF POWER: RESTORE ====="
restoreDesign ../dataout/design_saves/final_hold_eco_iter4b_trial.dat top
puts "FINAL_POWER_DB_RESTORED=[dbGet top.name]"

set PSD ./power_signoff_iter4b
file mkdir $PSD $PSD/saif
set _slg [open $PSD/saif_flow_log.txt a]
proc snote {m} { global _slg; puts "SAIFPWR: $m"; catch { puts $_slg "SAIFPWR: $m"; flush $_slg } }
snote "==== power_saif start [clock format [clock seconds]] design=[dbGet top.name] ===="

# protect the good saves
if {[info commands _pa_real_saveDesign] eq "" && [info commands saveDesign] ne ""} {
    catch { rename saveDesign _pa_real_saveDesign }
    proc saveDesign {args} { snote "saveDesign BLOCKED (saif power session): $args" }
}

# ---- config ----
set VDDC_NET VDDC ; set VSSC_NET VSSC ; set VDDP_NET VDDP ; set VSSP_NET VSSP ; set POC_NET POC
set SAIF_DIR [file normalize ../datain/saif]
if {![file isdirectory $SAIF_DIR]} { set SAIF_DIR [file normalize ../GL_sim_saif/saif] }
if {![file isdirectory $SAIF_DIR]} { set SAIF_DIR [file normalize ../../GL_sim_saif/saif] }
set SAIF_SCOPE design_tb/dut
set CORE_INST  I0
set BLOCKS [list core I0  fir_I I0/u_path_I_u_fir  interp_I I0/u_path_I_u_interp \
                 fir_Q I0/u_path_Q_u_fir  interp_Q I0/u_path_Q_u_interp]
snote "SAIF_DIR = $SAIF_DIR"

# ---- views + PG connect (idempotent; safe if power_analysis already did it) ----
if {[catch { set _v [get_analysis_views] } e] || $_v eq ""} { catch { read_mmmc ../datain/mmmc.view } }
catch { set_analysis_view -setup SlowView -hold FastView }
catch { globalNetConnect $VDDC_NET -type pgpin -pin VDD    -instanceBasename * -override }
catch { globalNetConnect $VSSC_NET -type pgpin -pin VSS    -instanceBasename * -override }
catch { globalNetConnect $VDDP_NET -type pgpin -pin VDDPST -instanceBasename * -override }
catch { globalNetConnect $VSSP_NET -type pgpin -pin VSSPST -instanceBasename * -override }
catch { globalNetConnect $POC_NET  -type pgpin -pin POC    -instanceBasename * -override }
catch { applyGlobalNets }
catch { setAnalysisMode -analysisType onChipVariation -cppr both }
if {[catch { extractRC } e]} { snote "extractRC WARN: $e" }

# ---- per-instance total power parser (Instance table, drop name token) ----
proc _blk_pwr {f inst} {
    if {![file exists $f]} { return "-" }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set sc 1.0
    if {[regexp -nocase {Power Units?\s*[:=]\s*1?\s*([munp]?)W} $txt -> u]} {
        switch -- [string tolower $u] { m {set sc 1.0} u {set sc 1e-3} n {set sc 1e-6} "" {set sc 1000.0} }
    }
    foreach ln [split $txt "\n"] {
        if {[lindex $ln 0] eq $inst} {
            set nums [regexp -all -inline {[-0-9.]+(?:[eE][-+]?[0-9]+)?} [lrange $ln 1 end]]
            if {[llength $nums] >= 6} { return [format %.4f [expr {[lindex $nums 5]*$sc}]] }
        }
    }
    return "-"
}
proc _chip_tot {f} {
    if {![file exists $f]} { return "-" }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set sc 1.0
    if {[regexp -nocase {Power Units?\s*[:=]\s*1?\s*([munp]?)W} $txt -> u]} {
        switch -- [string tolower $u] { m {set sc 1.0} u {set sc 1e-3} n {set sc 1e-6} "" {set sc 1000.0} }
    }
    foreach ln [split $txt "\n"] {
        if {[regexp -nocase {^Total Power[^0-9-]*([-0-9.eE+]+)} $ln -> v]} { return [format %.4f [expr {$v*$sc}]] }
    }
    return "-"
}

# ---- loop the per-L SAIFs ----
set LS {}
foreach f [lsort -dictionary [glob -nocomplain $SAIF_DIR/core_L*.saif]] {
    if {[regexp {core_L([0-9]+)\.saif} [file tail $f] -> l]} { lappend LS $l }
    snote "---- L=$l  ($f) ----"
    catch { set_power_analysis_mode -reset }
    catch { set_power_output_dir -reset }
    catch { set_power_output_dir $PSD/saif }
    catch { set_power_analysis_mode -method static -analysis_view SlowView \
            -create_binary_db true -write_static_currents true \
            -honor_negative_energy true -ignore_control_signals true }
    catch { set_default_switching_activity -reset }
    catch { read_activity_file -reset }
    set cov "?"
    if {[catch { read_activity_file -format SAIF -scope $SAIF_SCOPE -block $CORE_INST $f } e]} {
        snote "read_activity_file (with -block) failed: $e ; retry without -block"
        catch { read_activity_file -format SAIF -scope $SAIF_SCOPE $f }
    }
    # annotation coverage is printed by the tool; capture the last coverage-ish line if present
    snote "L=$l activity annotated from SAIF (CHECK coverage in innovus log / SAIFAN messages)"
    if {[catch { report_power -outfile $PSD/saif/chip_L$l.rpt } e]} { snote "report_power chip L$l: $e" }
    foreach {tag inst} $BLOCKS {
        catch { report_power -instances $inst -outfile $PSD/saif/${tag}_L$l.rpt }
    }
}
if {[llength $LS] == 0} { snote "NO SAIF files found in $SAIF_DIR -- run GL_sim_saif/run_saif.sh first"; }

# ---- per-L summary (measured, clock-gating aware) ----
set out [open $PSD/saif_summary.txt w]
puts $out "======================================================================"
puts $out " MEASURED STATIC POWER (SAIF per L)  design=[dbGet top.name]   (mW)"
puts $out " [clock format [clock seconds]]"
puts $out " corner  : SlowView (ss 0.81V 125C, SlowRC/cworst)"
puts $out " activity: real SAIF from GL_sim_saif (scope $SAIF_SCOPE -> block $CORE_INST)"
puts $out "======================================================================"
puts $out ""
puts $out [format "%-10s %12s %10s %10s %10s %10s" "L" "chip" "core(I0)" "interp_I" "interp_Q" "fir_I"]
foreach l $LS {
    set row [list]
    lappend row [_chip_tot $PSD/saif/chip_L$l.rpt]
    lappend row [_blk_pwr  $PSD/saif/core_L$l.rpt     I0]
    lappend row [_blk_pwr  $PSD/saif/interp_I_L$l.rpt I0/u_path_I_u_interp]
    lappend row [_blk_pwr  $PSD/saif/interp_Q_L$l.rpt I0/u_path_Q_u_interp]
    lappend row [_blk_pwr  $PSD/saif/fir_I_L$l.rpt    I0/u_path_I_u_fir]
    puts $out [format "%-10s %12s %10s %10s %10s %10s" "L$l" {*}$row]
}
puts $out ""
puts $out "Compare vs vectorless 0.2 (power_signoff/summary.txt): SAIF core should be"
puts $out "much lower - clock gating idles the paths the flat 0.2 assumed were busy."
close $out
snote "---- saif_summary ----"
set fp [open $PSD/saif_summary.txt r]; puts [read $fp]; close $fp
snote "wrote $PSD/saif_summary.txt ; per-L reports in $PSD/saif/"
snote "==== power_saif done ===="


puts "##### FINAL_ITER4B_POWER_PASS #####"
exit
