# ===== cts.tcl : clock tree synthesis =====
create_ccopt_clock_tree_spec -file ccopt.spec
source ccopt.spec
ccopt_design
refinePlace
saveDesign ../dataout/design_saves/cts
puts "== cts done : unplaced=[llength [get_db insts -if {.place_status==unplaced}]], saved cts =="
