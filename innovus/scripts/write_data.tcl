# ===== write_data.tcl : fillers + final repair + timing + SPEF =====
addFiller -cell {FILL64BWP30P140 FILL32BWP30P140 FILL16BWP30P140 FILL8BWP30P140 FILL4BWP30P140 FILL3BWP30P140 FILL2BWP30P140} -prefix FILL
source ../scripts/fix_final_drc.tcl
timeDesign -postRoute -numPaths 20 -prefix final_setup -outDir timingReports
timeDesign -postRoute -hold -numPaths 20 -prefix final_hold -outDir timingReports
saveDesign ../dataout/design_saves/final
reset_parasitics; extractRC; rcOut -rc_corner SlowRC -spef top_slow.spef
reset_parasitics; extractRC; rcOut -rc_corner FastRC -spef top_fast.spef
puts "== write_data done : final repaired DB + top_slow/fast.spef written =="
