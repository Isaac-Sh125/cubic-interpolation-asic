# ===== place.tcl : placement + tie cells + followpin =====
setPlaceMode -reset
setPlaceMode -congEffort auto -timingDriven 1 -clkGateAware 1 -powerDriven 1 -ignoreScan 1
place_design
setTieHiLoMode -reset
setTieHiLoMode -cell {TIELBWP30P140 TIEHBWP30P140} -maxDistance 20 -maxFanout 4 -honorDontTouch false
addTieHiLo -cell {TIELBWP30P140 TIEHBWP30P140}
sroute -connect {corePin padPin floatingStripe} -nets {VDDC VSSC} -layerChangeRange {M1 M9} -allowJogging 1 -allowLayerChange 1
checkPlace place_check.rpt
saveDesign ../dataout/design_saves/placed
puts "== place done : unplaced=[llength [get_db insts -if {.place_status==unplaced}]], saved placed =="
