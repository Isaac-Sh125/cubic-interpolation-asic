###################################################################
# Clean top.sdc for first 28nm Innovus import
###################################################################

# Clock enters the core through input pad I5, pin C.
create_clock -name clk -period 1.04 -waveform {0 0.52} [get_pins I5/I1/C]

set_clock_uncertainty 0.05 [get_clocks clk]
set_clock_transition -min -rise 0.05 [get_clocks clk]
set_clock_transition -min -fall 0.05 [get_clocks clk]
set_clock_transition -max -rise 0.05 [get_clocks clk]
set_clock_transition -max -fall 0.05 [get_clocks clk]

# Input pads except clock:
# I6  rst_n
# I7  sanity_in_ff
# I8  sanity_in_inv
# I9  scan_en
# I10 scan_in1
# I11 scan_in2
# I12 scan_in3
# I13 serial_in_I
# I14 serial_in_Q
set_input_delay -clock clk -max 0.20 [get_pins I6/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I7/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I8/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I9/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I10/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I11/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I12/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I13/I1/C]
set_input_delay -clock clk -max 0.20 [get_pins I14/I1/C]

set_input_delay -clock clk -min 0.05 [get_pins I6/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I7/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I8/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I9/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I10/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I11/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I12/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I13/I1/C]
set_input_delay -clock clk -min 0.05 [get_pins I14/I1/C]

# Output pads I15-I53. Their core-side input pin is I.
set_output_delay -clock clk -max 0.20 [get_pins {I15/I1/I I16/I1/I I17/I1/I I18/I1/I I19/I1/I I20/I1/I I21/I1/I I22/I1/I I23/I1/I I24/I1/I I25/I1/I I26/I1/I I27/I1/I I28/I1/I I29/I1/I I30/I1/I I31/I1/I I32/I1/I I33/I1/I I34/I1/I I35/I1/I I36/I1/I I37/I1/I I38/I1/I I39/I1/I I40/I1/I I41/I1/I I42/I1/I I43/I1/I I44/I1/I I45/I1/I I46/I1/I I47/I1/I I48/I1/I I49/I1/I I50/I1/I I51/I1/I I52/I1/I I53/I1/I}]
set_output_delay -clock clk -min 0.05 [get_pins {I15/I1/I I16/I1/I I17/I1/I I18/I1/I I19/I1/I I20/I1/I I21/I1/I I22/I1/I I23/I1/I I24/I1/I I25/I1/I I26/I1/I I27/I1/I I28/I1/I I29/I1/I I30/I1/I I31/I1/I I32/I1/I I33/I1/I I34/I1/I I35/I1/I I36/I1/I I37/I1/I I38/I1/I I39/I1/I I40/I1/I I41/I1/I I42/I1/I I43/I1/I I44/I1/I I45/I1/I I46/I1/I I47/I1/I I48/I1/I I49/I1/I I50/I1/I I51/I1/I I52/I1/I I53/I1/I}]

# Scan mode is disabled in functional timing.
set_case_analysis 0 [get_pins I9/I1/C]
###################################################################
# Restored synthesis multicycle / clock-gating constraints
# Translated to actual padded Innovus instance names.
###################################################################

proc collect_existing_cells {patterns} {
    set out [get_cells -quiet __NO_SUCH_CELL__]
    foreach p $patterns {
        set c [get_cells -quiet $p]
        if {[sizeof_collection $c] > 0} {
            set out [add_to_collection $out $c]
        } else {
            puts "WARN: no match for $p"
        }
    }
    return $out
}

proc apply_clock_gating_zero_checks {patterns} {
    set cg_cells [collect_existing_cells $patterns]
    puts "INFO: clock-gating cells found = [sizeof_collection $cg_cells]"

    if {[sizeof_collection $cg_cells] > 0} {
        set_clock_gating_check -rise -setup 0 $cg_cells
        set_clock_gating_check -fall -setup 0 $cg_cells
        set_clock_gating_check -rise -hold  0 $cg_cells
        set_clock_gating_check -fall -hold  0 $cg_cells
    }
}

proc apply_multicycle_to_cells {name setup_cycles hold_cycles patterns} {
    set targets [collect_existing_cells $patterns]
    puts "INFO: $name target cells found = [sizeof_collection $targets]"

    if {[sizeof_collection $targets] == 0} {
        puts "ERROR: $name has zero targets. Multicycle NOT applied."
        return
    }

    set_multicycle_path $hold_cycles  -hold  -to $targets
    set_multicycle_path $setup_cycles -setup -to $targets
}

# Clock-gating checks from synthesis SDC, translated from slash hierarchy
# to the real Innovus names.
apply_clock_gating_zero_checks {
    I0/u_path_Q_u_fir/clk_gate_y_out_reg/main_gate
    I0/u_path_Q_u_interp/clk_gate_sample_cnt_reg/main_gate
    I0/u_path_Q_u_sipo_clk_gate_shift_reg_reg/main_gate
    I0/u_path_I_u_fir/clk_gate_y_out_reg/main_gate
    I0/u_path_I_u_interp/clk_gate_sample_cnt_reg/main_gate
    I0/u_control_clk_gate_L_val_reg/main_gate
    I0/u_control_clk_gate_cfg_reg_reg/main_gate
}

# Original synthesis SDC had:
# set_multicycle_path 13 -hold  -to interp y0-y4 regs
# set_multicycle_path 14 -setup -to interp y0-y4 regs
apply_multicycle_to_cells interp_y_regs 14 13 {
    I0/u_path_I_u_interp/y0_reg_*
    I0/u_path_I_u_interp/y1_reg_*
    I0/u_path_I_u_interp/y2_reg_*
    I0/u_path_I_u_interp/y3_reg_*
    I0/u_path_I_u_interp/y4_reg_*
    I0/u_path_Q_u_interp/y0_reg_*
    I0/u_path_Q_u_interp/y1_reg_*
    I0/u_path_Q_u_interp/y2_reg_*
    I0/u_path_Q_u_interp/y3_reg_*
    I0/u_path_Q_u_interp/y4_reg_*
}

# Original synthesis SDC had:
# set_multicycle_path 2 -hold  -to FIR output/accumulator regs
# set_multicycle_path 3 -setup -to FIR output/accumulator regs
apply_multicycle_to_cells fir_regs 3 2 {
    I0/u_path_I_u_fir/y_out_reg_*
    I0/u_path_I_u_fir/y_valid_reg
    I0/u_path_I_u_fir/acc_stage_reg_*
    I0/u_path_Q_u_fir/y_out_reg_*
    I0/u_path_Q_u_fir/y_valid_reg
    I0/u_path_Q_u_fir/acc_stage_reg_*
}

