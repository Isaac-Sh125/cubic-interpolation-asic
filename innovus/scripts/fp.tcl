# ===== fp.tcl : floorplan (die / IO-boundary / core) + IO fillers =====
# Pads ring the die edge (PAD_DEPTH deep); GAP um channel (die-seal -> core-seal); then core.
set PAD_DEPTH 110.0   ;# die edge -> inner pad edge (IO boundary)
set GAP        50.0   ;# IO-boundary -> core  (die-seal to core-seal)
set CORE_INSET [expr {$PAD_DEPTH + $GAP}]   ;# 160
set DIE       880.0   ;# produces a 560 um core with the configured 160 um inset
setFPlanMode -snapDieGrid manufacturing -snapCoreGrid manufacturing -snapPlaceBlockageGrid manufacturing
floorPlan -site core -b \
    0.0 0.0 $DIE $DIE \
    $PAD_DEPTH  $PAD_DEPTH  [expr {$DIE-$PAD_DEPTH}]  [expr {$DIE-$PAD_DEPTH}] \
    $CORE_INSET $CORE_INSET [expr {$DIE-$CORE_INSET}] [expr {$DIE-$CORE_INSET}]
checkFPlan -outFile fp_check.rpt
# close the pad ring with IO filler (pad_spacer) cells so pad power flows by abutment
set io_filler_cells [get_db [get_db base_cells -if {.class == pad_spacer}] .name]
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_N -side n
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_S -side s
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_W -side w
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_E -side e
checkFPlan
file mkdir ../dataout/design_saves
saveDesign ../dataout/design_saves/init_fp
puts "== FP done: die=[dbGet top.fPlan.box] core=[dbGet top.fPlan.coreBox] iofill=[llength [get_db insts IO_FILLER*]] =="
