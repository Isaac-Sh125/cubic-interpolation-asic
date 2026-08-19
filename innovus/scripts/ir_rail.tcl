# ==========================================================================
# ir_rail.tcl   TSMC 28nm (28HPCPMMWAVE)  --  static IR / rail analysis (VDDC/VSSC)
# --------------------------------------------------------------------------
# Ported from khamaysi 65nm ir_rail.tcl. KEY 28nm DIFFERENCE: there are NO
# prebuilt Voltus PGV (.cl) libraries for 28HPCPMMWAVE (65nm had voltage_storm
# tcbn65lp*.cl). So this script GENERATES a techonly PGV from LEF+QRC first
# (standard cells modelled as resistive rails + current sinks), then runs
# static rail analysis. Assumes power_analysis.tcl already produced the static
# current files (power_signoff/slowRC/static_VDDC.ptiavg / static_VSSC.ptiavg).
#
# Source in a live post-route session AFTER power_analysis.tcl:
#     source ../scripts/ir_rail.tcl
# Every step catch-guarded; if PGV/rail is infeasible it documents why and
# still reports grid integrity (verifyConnectivity special).
# Writes everything under work/power_signoff/.
# ==========================================================================

set PSD ./power_signoff
file mkdir $PSD
set _ilg [open $PSD/ir_flow_log.txt a]
proc inote {m} { global _ilg; puts "IR: $m"; catch { puts $_ilg "IR: $m"; flush $_ilg } }
inote "==== ir_rail start [clock format [clock seconds]]  design=[dbGet top.name] ===="

# keep the good routed saves safe
if {[info commands _pa_real_saveDesign] eq "" && [info commands saveDesign] ne ""} {
    catch { rename saveDesign _pa_real_saveDesign }
    proc saveDesign {args} { inote "saveDesign BLOCKED (rail session): $args" }
}

# ---------------- config ----------------
set VDDC_NET VDDC ; set VSSC_NET VSSC
set SS_VOLT     0.81
set VDD_THRESH  0.7695   ;# 95% of 0.81
set VSS_THRESH  0.081    ;# 10% bounce budget on ground
set TEMP        125
set QRC_SLOW    /data/tsmc/28HPCPMMWAVE/QRC/1.8a/9m/cworst/qrcTechFile
set PGV_DIR     ./pgv_techonly
set PGV_PREFIX  pgv28
set VSRC_SEARCH 60       ;# um; snap ideal source to the nearest VDDC/VSSC node
# activity note = whatever power_analysis.tcl used to make the static currents
set ACT_NOTE    "static currents from power_analysis.tcl (default 0.2 unless VCD was enabled)"

# static current files from power_analysis.tcl
set I_VDD $PSD/slowRC/static_${VDDC_NET}.ptiavg
set I_VSS $PSD/slowRC/static_${VSSC_NET}.ptiavg

set IRSUM [open $PSD/ir_summary.txt w]
proc irs {m} { global IRSUM; puts $IRSUM $m; flush $IRSUM }
irs "======================================================================"
irs " STATIC IR / RAIL ANALYSIS   design=[dbGet top.name]"
irs " [clock format [clock seconds]]"
irs " nets: VDDC (0.81V, thr 0.7695=95%) / VSSC (0V, thr 0.081)"
irs " corner: SlowView (ss), QRC=cworst, T=125C"
irs "======================================================================"

# ---------------- 0. grid integrity (always reported) ----------------
if {[catch { set vc [verifyConnectivity -type special -nets [list $VDDC_NET $VSSC_NET] -error 100 -warning 100] } e]} {
    inote "verifyConnectivity special ERR: $e" ; irs "grid integrity: verifyConnectivity ERROR ($e)"
} else {
    inote "verifyConnectivity special (VDDC,VSSC) done -> see verify_conn log"
    irs "grid integrity: verifyConnectivity -type special ran (see ir_flow_log / innovus log for opens/shorts)"
}

# ---------------- 1. techonly PGV generation ----------------
set PGV_OK 0
set PGV_CL ""
if {[info commands generate_pg_library] eq "" || [info commands set_pg_library_mode] eq ""} {
    inote "generate_pg_library / set_pg_library_mode NOT available in this build -> cannot make PGV"
    irs "PGV: NOT GENERATED (Voltus generate_pg_library command absent)"
} elseif {![file exists $QRC_SLOW]} {
    inote "QRC tech file missing: $QRC_SLOW -> cannot make techonly PGV"
    irs "PGV: NOT GENERATED (QRC tech file missing: $QRC_SLOW)"
} else {
    # reuse an already-generated PGV if present
    set _existing [lsort -dictionary [glob -nocomplain $PGV_DIR/*.cl]]
    if {[llength $_existing] > 0} {
        set PGV_CL [lindex $_existing end]
        set PGV_OK 1
        inote "reusing existing PGV: $PGV_CL"
    } else {
        file mkdir $PGV_DIR
        inote "generating techonly PGV (cells as resistive rails) into $PGV_DIR ..."
        if {[catch {
            set_pg_library_mode -reset
        }]} {}
        if {[catch {
            set_pg_library_mode \
                -celltype techonly \
                -extraction_tech_file $QRC_SLOW \
                -temperature $TEMP \
                -power_pins [list VDD $SS_VOLT] \
                -ground_pins VSS \
                -default_area_cap 0.0 \
                -current_distribution propagation
        } e]} {
            inote "set_pg_library_mode FAILED: $e"
            irs "PGV: NOT GENERATED (set_pg_library_mode failed: $e)"
        } else {
            if {[catch { generate_pg_library -library_prefix $PGV_PREFIX -output $PGV_DIR } e]} {
                inote "generate_pg_library FAILED: $e"
                irs "PGV: NOT GENERATED (generate_pg_library failed: $e)"
            } else {
                set _cls [lsort -dictionary [glob -nocomplain $PGV_DIR/*.cl]]
                if {[llength $_cls] > 0} {
                    set PGV_CL [lindex $_cls end]; set PGV_OK 1
                    inote "PGV generated: $PGV_CL"
                    irs "PGV: generated techonly -> $PGV_CL"
                } else {
                    inote "generate_pg_library ran but no .cl found under $PGV_DIR"
                    irs "PGV: generate_pg_library ran but produced no .cl (see log)"
                }
            }
        }
    }
}

# ---------------- 2. power-pad source points (.pp) from core-supply pads ----------------
# VDDC pads = PVDD1DGZ* ; VSSC pads = PVSS1DGZ*  (IO-supply PVDD2/PVSS2 are VDDP/VSSP, excluded).
# Discover by iterating instances + regexp on cell name (robust; dbGet globbing was unreliable).
proc _pp_from_pads {cellRe outFile srcTag layerNS layerEW} {
    global VSRC_SEARCH
    set DIE 0
    catch { set DIE [lindex [dbGet top.fPlan.box] 2] }
    if {$DIE <= 0} { set DIE 880 }
    set f [open $outFile w]; set i 1; set n 0
    # two flat lists in the same order -> zip; box lookups only for the few matches
    set names [dbGet top.insts.name -e]
    set cells [dbGet top.insts.cell.name -e]
    foreach nm $names cell $cells {
        if {![regexp $cellRe $cell]} { continue }
        if {[catch {
            set ip  [dbGet -p top.insts.name $nm]
            set llx [dbGet $ip.box_llx]; set lly [dbGet $ip.box_lly]
            set urx [dbGet $ip.box_urx]; set ury [dbGet $ip.box_ury]
            set cx [expr {($llx+$urx)/2.0}]; set cy [expr {($lly+$ury)/2.0}]
            # side = box edge sitting on the die boundary; inner edge (toward core) hosts the source
            set side "?"; set px $cx; set py $cy; set layer $layerNS
            if {$ury >= [expr {$DIE-1.0}]}      { set side N; set px $cx;  set py [expr {$lly+3}]; set layer $layerNS } \
            elseif {$lly <= 1.0}                { set side S; set px $cx;  set py [expr {$ury-3}]; set layer $layerNS } \
            elseif {$urx >= [expr {$DIE-1.0}]}  { set side E; set px [expr {$llx+3}]; set py $cy; set layer $layerEW } \
            elseif {$llx <= 1.0}                { set side W; set px [expr {$urx-3}]; set py $cy; set layer $layerEW }
            puts $f "${srcTag}${i} $px $py $layer"
            puts "IR:   $srcTag$i <- $nm ($cell $side [dbGet $ip.orient]) at $px $py $layer"
            incr i; incr n
        } e]} { puts "IR: pad point failed for $nm: $e" }
    }
    close $f
    return $n
}
set nVdd [_pp_from_pads {^PVDD1DGZ} $PSD/vddc.pp VDDsrc M9 M8]
set nVss [_pp_from_pads {^PVSS1DGZ} $PSD/vssc.pp VSSsrc M9 M8]
inote "power-pad sources: VDDC=$nVdd  VSSC=$nVss"
irs "power pads: VDDC core pads=$nVdd  VSSC core pads=$nVss  (vsrc_search=${VSRC_SEARCH}um)"

# ---------------- 3. rail analysis ----------------
set RAIL_OK 0
if {!$PGV_OK} {
    inote "SKIP rail analysis: no PGV available"
    irs "RAIL: SKIPPED (no PGV) -- power numbers + grid integrity above still valid"
} elseif {![file exists $I_VDD] || ![file exists $I_VSS]} {
    inote "SKIP rail analysis: static current files missing ($I_VDD / $I_VSS). Run power_analysis.tcl first."
    irs "RAIL: SKIPPED (static current files missing -- source power_analysis.tcl first)"
} elseif {$nVdd < 1 || $nVss < 1} {
    inote "SKIP rail analysis: no power-pad sources found"
    irs "RAIL: SKIPPED (no power-pad sources)"
} else {
    set _setup_ok 0
    if {[catch {
        set_rail_analysis_mode \
            -method static -accuracy hd \
            -analysis_view SlowView \
            -power_grid_library $PGV_CL \
            -temperature $TEMP \
            -enable_rlrp_analysis true \
            -vsrc_search_distance $VSRC_SEARCH \
            -verbosity true
        # set_pg_nets MUST follow set_rail_analysis_mode (mode reset the nets, VOLTUS-1179)
        set_pg_nets -net $VDDC_NET -voltage $SS_VOLT -threshold $VDD_THRESH
        set_pg_nets -net $VSSC_NET -voltage 0.0      -threshold $VSS_THRESH
        set_rail_analysis_domain -name PD_Core -pwrnets $VDDC_NET -gndnets $VSSC_NET -threshold $VSS_THRESH
        set_power_pads -reset
        set_power_pads -net $VDDC_NET -format xy -file $PSD/vddc.pp
        set_power_pads -net $VSSC_NET -format xy -file $PSD/vssc.pp
        set_power_data -reset
        set_power_data -format current [list $I_VDD $I_VSS]
    } e]} {
        inote "rail setup FAILED: $e" ; irs "RAIL: setup FAILED ($e)"
    } else { set _setup_ok 1 }

    if {$_setup_ok} {
        # analyze_rail domain-name positional order varies by Voltus build; try known forms
        set _forms [list \
            "analyze_rail -type domain -output $PSD PD_Core" \
            "analyze_rail PD_Core -type domain -output $PSD" \
            "analyze_rail -type domain PD_Core -output $PSD" ]
        foreach cmd $_forms {
            if {$RAIL_OK} { break }
            if {[catch { eval $cmd } e]} {
                inote "analyze_rail form failed [$cmd]: $e"
            } else {
                set RAIL_OK 1
                inote "analyze_rail OK via: $cmd"
                irs "RAIL: analyze_rail completed ($cmd)"
            }
        }
        if {!$RAIL_OK} { irs "RAIL: analyze_rail FAILED for all argument forms (see log)" }
    }
}

# ---------------- 4. read results, worst IR, IR plot ----------------
# convert "0.793V" / "14.472mV" / "1.4uV" to volts
proc _volts {tok} {
    if {[regexp {([-0-9.eE+]+)\s*([munpMUNP]?)V} $tok -> num u]} {
        switch -- [string tolower $u] {
            m  { return [expr {$num*1e-3}] }
            u  { return [expr {$num*1e-6}] }
            n  { return [expr {$num*1e-9}] }
            p  { return [expr {$num*1e-12}] }
            default { return [expr {$num*1.0}] }
        }
    }
    return ""
}
# pull "Minimum, Average, Maximum IR drop: A B C" and "Number of Violations: N" from a net report
proc _ir_from_rpt {f} {
    if {![file exists $f]} { return {} }
    set fp [open $f r]; set txt [read $fp]; close $fp
    set mn ""; set av ""; set mx ""; set nv "?"
    if {[regexp -nocase {IR drop:\s*([-0-9.eE+]+\s*[munpMUNP]?V)\s+([-0-9.eE+]+\s*[munpMUNP]?V)\s+([-0-9.eE+]+\s*[munpMUNP]?V)} $txt -> a b c]} {
        set mn [_volts $a]; set av [_volts $b]; set mx [_volts $c]
    }
    if {[regexp -nocase {Number of Violations:\s*([0-9]+)} $txt -> n]} { set nv $n }
    return [list $mn $av $mx $nv]
}
if {$RAIL_OK} {
    set _rd [lindex [lsort -dictionary [glob -nocomplain $PSD/PD_Core_*]] end]
    set _db [lindex [lsort -dictionary [concat [glob -nocomplain $PSD/slowRC/*.db] [glob -nocomplain $PSD/*.db]]] end]
    inote "results dir=$_rd  power_db=$_db"
    if {$_rd ne ""} {
        catch { read_power_rail_results -reset }
        if {$_db ne ""} {
            catch { read_power_rail_results -rail_directory $_rd -power_db $_db }
        } else {
            catch { read_power_rail_results -rail_directory $_rd }
        }
        catch { set_power_rail_display -plot ir }
        inote "IR display enabled (results $_rd)"
        irs ""
        irs "WORST-CASE IR (SlowView ss 0.81V, techonly PGV, activity=$ACT_NOTE):"
        # VDDC: report values are node voltages -> worst drop = nominal - min_voltage
        set vd [_ir_from_rpt $_rd/Reports/VDDC/VDDC.main.rpt]
        if {[llength $vd] == 4 && [lindex $vd 0] ne ""} {
            set vmin [lindex $vd 0]
            set drop [expr {$SS_VOLT - $vmin}]
            irs [format "  VDDC : min node V = %.4f V  ->  worst IR drop = %.2f mV   (violations: %s, thr %.4fV)" \
                    $vmin [expr {$drop*1000.0}] [lindex $vd 3] $VDD_THRESH]
        } else { irs "  VDDC : (could not parse VDDC.main.rpt)" }
        # VSSC: report values are the bounce directly -> worst = max
        set vs [_ir_from_rpt $_rd/Reports/VSSC/VSSC.main.rpt]
        if {[llength $vs] == 4 && [lindex $vs 2] ne ""} {
            irs [format "  VSSC : worst ground bounce = %.2f mV                       (violations: %s, thr %.4fV)" \
                    [expr {[lindex $vs 2]*1000.0}] [lindex $vs 3] $VSS_THRESH]
        } else { irs "  VSSC : (could not parse VSSC.main.rpt)" }
        # worst effective instance voltage from voltus_rail.log (VDD drop + VSS bounce combined)
        if {[file exists $_rd/voltus_rail.log]} {
            set fp [open $_rd/voltus_rail.log r]; set lt [read $fp]; close $fp
            if {[regexp -nocase {Effective Instance Voltage:\s*([-0-9.eE+]+\s*[munpMUNP]?V)} $lt -> ev]} {
                set evv [_volts $ev]
                irs [format "  Worst effective instance voltage = %.4f V  (= %.2f mV total drop; PASS if > %.4fV)" \
                        $evv [expr {($SS_VOLT-$evv)*1000.0}] $VDD_THRESH]
            }
        }
        irs ""
        irs "GIF plots: $_rd/Reports/{VDDC,VSSC}/ir_linear.gif ; HTML: $_rd/Reports/HTML/"
        irs "Full net reports: $_rd/Reports/{VDDC,VSSC}/VDDC.main.rpt / VSSC.main.rpt"
    } else {
        irs "RAIL: analyze_rail completed but no results directory PD_Core_* found"
    }
}

irs ""
irs "ir_rail complete. PGV_OK=$PGV_OK RAIL_OK=$RAIL_OK"
close $IRSUM
inote "---- ir_summary ----"
set fp [open $PSD/ir_summary.txt r]; puts [read $fp]; close $fp
inote "==== ir_rail done ===="
