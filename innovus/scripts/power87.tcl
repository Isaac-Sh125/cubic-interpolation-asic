# ===== power87.tcl : 10um core power ring (M9/M8) + dual stripes on VDDC/VSSC =====
# 28nm stack: M7=H, M8=V, M9=H. Power on top thick layers, above M1-M7 signal.
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 \
    -skip_crossing_trunks none -stacked_via_top_layer M9 -stacked_via_bottom_layer M1 \
    -via_using_exact_crossover_size 1 -orthogonal_only true \
    -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}
# closed core ring: horizontal M9 (top/bottom), vertical M8 (left/right); 10um w/s/offset
addRing -nets {VSSC VDDC} -type core_rings -follow core \
    -layer {top M9 bottom M9 left M8 right M8} \
    -width {top 10 bottom 10 left 10 right 10} \
    -spacing {top 10 bottom 10 left 10 right 10} \
    -offset {top 10 bottom 10 left 10 right 10} \
    -center 1 -threshold 2.6 -jog_distance 2.6 -snap_wire_center_to_grid None
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false \
    -rows_without_stripes_only false -extend_to_closest_target none \
    -stacked_via_top_layer M9 -stacked_via_bottom_layer M1 -orthogonal_only true \
    -allow_jog {padcore_ring block_ring} -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}
# vertical stripes M8, horizontal stripes M9 ; 4um wide, 70um pair pitch
addStripe -nets {VDDC VSSC} -layer M8 -direction vertical -width 4 -spacing 4 \
    -set_to_set_distance 70 -start_from left -start_offset 31 \
    -padcore_ring_top_layer_limit M9 -padcore_ring_bottom_layer_limit M1 \
    -block_ring_top_layer_limit M9 -block_ring_bottom_layer_limit M1 -snap_wire_center_to_grid None
addStripe -nets {VDDC VSSC} -layer M9 -direction horizontal -width 4 -spacing 4 \
    -set_to_set_distance 70 -start_from bottom -start_offset 31 \
    -padcore_ring_top_layer_limit M9 -padcore_ring_bottom_layer_limit M1 \
    -block_ring_top_layer_limit M9 -block_ring_bottom_layer_limit M1 -snap_wire_center_to_grid None
# stitch cell rails <-> stripes/ring <-> pad core-supply pins
sroute -connect {corePin padPin floatingStripe} -nets {VDDC VSSC} \
    -layerChangeRange {M1 M9} -allowJogging 1 -allowLayerChange 1 \
    -crossoverViaLayerRange {M1 M9} -targetViaLayerRange {M1 M9}
saveDesign ../dataout/design_saves/fp_power
puts "== power87 done: 10um ring M9/M8 + dual stripes M8/M9 + sroute on VDDC/VSSC =="
