# ===== route.tcl : detail route + postRoute opt (setup+hold) + DRC fix =====
setAnalysisMode -analysisType onChipVariation -cppr both
setNanoRouteMode -quiet -routeWithTimingDriven true -routeWithSiDriven true -drouteFixAntenna true
routeDesign
saveDesign ../dataout/design_saves/routed
optDesign -postRoute
optDesign -postRoute -hold
ecoRoute -fix_drc
saveDesign ../dataout/design_saves/signoff
timeDesign -postRoute -numPaths 20 -prefix setup -outDir timingReports
timeDesign -postRoute -hold -numPaths 20 -prefix hold -outDir timingReports
verify_drc -limit 100000 -report verify_drc_pre_final_fix.rpt
verifyConnectivity -type all -error 100000 -report verify_conn_pre_final_fix.rpt
puts "== route done : saved signoff; pre-final-fix verification completed. check timingReports =="
