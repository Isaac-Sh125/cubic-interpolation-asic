# ==========================================================================
#  power_flow.tcl   TSMC 28nm  --  POWER-ANALYSIS signoff (one entry point)
# --------------------------------------------------------------------------
#  Runs the three power steps IN ORDER on a post-route design that is already
#  loaded in memory (sourced by full.tcl right after STAGE_WRITE, or by hand
#  after restoreDesign of the routed .dat):
#      source ../scripts/power_flow.tcl
#
#  Order matters:
#    1. power_analysis.tcl  - static vectorless power   (ss / 0.81V / 125C)
#    2. power_saif.tcl      - measured per-L SAIF power  (real gate activity)
#    3. ir_rail.tcl         - static IR / rail  (FINAL: builds techonly PGV,
#                             consumes the power result)
#  All three block saveDesign, so this must run AFTER write_data has saved
#  the .dat + GDS.
# ==========================================================================

puts "STAGE_PA_VECTORLESS"; source ../scripts/power_analysis.tcl
puts "STAGE_PA_SAIF";       source ../scripts/power_saif.tcl
puts "STAGE_PA_IRRAIL";     source ../scripts/ir_rail.tcl
puts "STAGE_POWER_ANALYSIS_DONE"
