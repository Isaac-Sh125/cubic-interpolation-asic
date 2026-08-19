# backend_prep.tcl
# From the canonical repaired final.dat, generate PrimeTime handoff only:
#   1. flat post-layout timing netlist
#   2. SlowRC SPEF
#   3. FastRC SPEF
#
# No GDS/LVS generation here. The saved canonical design is never overwritten.

setDesignMode -process 28
setMultiCpuUsage -local 8

restoreDesign ../dataout/design_saves/final.dat top

# Block accidental checkpoint overwrite.
if {[info commands _bp_real_saveDesign] eq ""} {
    catch { rename saveDesign _bp_real_saveDesign }
}
proc saveDesign {args} {
    puts "BACKEND: saveDesign BLOCKED: $args"
}

file mkdir ../dataout/pt

set PT_NETLIST ../dataout/pt/top_post_layout.v
set PT_SLOW    ../dataout/pt/top_slow.SPEF
set PT_FAST    ../dataout/pt/top_fast.SPEF

# Remove stale handoff files first.
foreach f [list $PT_NETLIST $PT_SLOW $PT_FAST] {
    if {[file exists $f]} {
        file delete -force $f
    }
}

# ----------------------------------------------------------------------
# 1. Flat post-layout timing netlist
# ----------------------------------------------------------------------
catch { update_names -nocase }

if {[catch {
    saveNetlist $PT_NETLIST \
        -topModuleFirst \
        -flat \
        -removePowerGround
} e]} {
    error "PT_HANDOFF_NETLIST_FAILED: $e"
}

# ----------------------------------------------------------------------
# 2. Extract and write SlowRC SPEF
# ----------------------------------------------------------------------
reset_parasitics

if {[catch { extractRC } e]} {
    error "PT_HANDOFF_SLOW_EXTRACT_FAILED: $e"
}

if {[catch {
    rcOut -rc_corner SlowRC -spef $PT_SLOW
} e]} {
    error "PT_HANDOFF_SLOW_SPEF_FAILED: $e"
}

# ----------------------------------------------------------------------
# 3. Extract and write FastRC SPEF
# ----------------------------------------------------------------------
reset_parasitics

if {[catch { extractRC } e]} {
    error "PT_HANDOFF_FAST_EXTRACT_FAILED: $e"
}

if {[catch {
    rcOut -rc_corner FastRC -spef $PT_FAST
} e]} {
    error "PT_HANDOFF_FAST_SPEF_FAILED: $e"
}

# ----------------------------------------------------------------------
# 4. Hard output checks
# ----------------------------------------------------------------------
foreach f [list $PT_NETLIST $PT_SLOW $PT_FAST] {
    if {![file exists $f]} {
        error "PT_HANDOFF_MISSING_OUTPUT: $f"
    }

    if {[file size $f] <= 0} {
        error "PT_HANDOFF_EMPTY_OUTPUT: $f"
    }

    puts "PT_HANDOFF_OUTPUT [file size $f] $f"
}

puts "##### PT_HANDOFF_PASS #####"
exit
