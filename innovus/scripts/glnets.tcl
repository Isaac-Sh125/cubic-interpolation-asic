# ===== glnets.tcl : connect core + pad PG pins (28nm) =====
clearGlobalNets
globalNetConnect VDDC -type pgpin -pin VDD    -instanceBasename * -override
globalNetConnect VSSC -type pgpin -pin VSS    -instanceBasename * -override
globalNetConnect VDDP -type pgpin -pin VDDPST -instanceBasename * -override
globalNetConnect VSSP -type pgpin -pin VSSPST -instanceBasename * -override
globalNetConnect POC  -type pgpin -pin POC    -instanceBasename * -override
puts "== glnets done : core->VDDC/VSSC ; pad ring->VDDP/VSSP/POC =="
