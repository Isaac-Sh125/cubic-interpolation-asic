proc stg {s} { puts "STAGE_$s [clock format 0]" ; puts "STAGE_$s" }

# ==========================================================================
#  P&R  (netlist + pads  ->  routed, filled, verified, SPEF-extracted)
# ==========================================================================
puts "STAGE_INIT";   source ../scripts/init.tcl
puts "STAGE_FP";     source ../scripts/fp.tcl
puts "STAGE_GLNETS"; source ../scripts/glnets.tcl
puts "STAGE_POWER";  source ../scripts/power87.tcl      ;# power GRID (rings + stripes)
puts "STAGE_PLACE";  source ../scripts/place.tcl
puts "STAGE_CTS";    source ../scripts/cts.tcl
puts "STAGE_ROUTE";  source ../scripts/route.tcl
puts "STAGE_WRITE";  source ../scripts/write_data.tcl   ;# final repair + saveDesign + SPEF

# routed-design integrity check: no top port left stranded at (0,0)
set terms [dbGet top.terms]; set nz 0
foreach t $terms { set p [lindex [dbGet $t.pt] 0]; if {[lindex $p 0]==0 && [lindex $p 1]==0} {incr nz} }
puts "PORTS_AT_ZERO_FINAL=$nz of [llength $terms]"


puts "FLOW_DONE_PNR"
exit
