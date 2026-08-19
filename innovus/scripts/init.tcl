# ===== init.tcl : 28nm import + flatten clock gates =====
# Chip ports auto-place on their pads because top.v puts each port on the pad's
# .PAD side and top.io (init_io_file) is read by init_design. No editPin needed.
setDesignMode -process 28
setMultiCpuUsage -local 8
source ../datain/env.globals
set init_assign_buffer 1
set init_design_uniquify 1
init_design
# flatten Synopsys clock-gate modules so CTS can place/clone them as leaf cells
set cgh [get_cells -hierarchical * -filter "ref_name =~ SNPS_CLOCK_GATE*"]
if {[sizeof_collection $cgh] > 0} { ungroup -flatten $cgh; puts "flattened [sizeof_collection $cgh] clock-gate modules" }
puts "== INIT done: die=[dbGet top.fPlan.box] core=[dbGet top.fPlan.coreBox] rows=[llength [get_db rows]] pads=[llength [get_db insts -if {.base_cell.base_class==pad}]] ports=[llength [dbGet top.terms]] =="
