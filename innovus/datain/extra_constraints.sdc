# ============================================================================
# extra_constraints.sdc  -  PAD-WRAPPED (P&R) level only, for the 28nm port.
# Additional configuration-state timing constraints for the TSMC 28 nm implementation
#
# The frame CONFIGURATION registers L_val and mode_15bit are set ONCE from the
# serial header (Control_Unit.v, cfg_valid) and then held constant for the whole
# operation (thousands of samples). A single-cycle 960 MHz check on paths FROM
# them is not a real requirement and produces false setup violations
# (worst: I0/u_control_L_val_reg -> u_path_I/u_interp/y*_reg, ~-4 ns).
# Multicycle (16/15, matching the word-rate MC_PATH_FIR), not false path, so the
# path stays checked. NOT applied to sub_count/tick_60M (they change every beat).
# ============================================================================
set_multicycle_path 16 -setup -from [get_cells I0/u_control_L_val_reg*]
set_multicycle_path 15 -hold  -from [get_cells I0/u_control_L_val_reg*]
set_multicycle_path 16 -setup -from [get_cells I0/u_control_mode_15bit_reg*]
set_multicycle_path 15 -hold  -from [get_cells I0/u_control_mode_15bit_reg*]
