set sdc_version 1.2
current_design ASIC_Top

# 1. CLOCK DEFINITION AND MARGINS
set clk_period 1.04
create_clock -name clk -period $clk_period -waveform {0 0.52} [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_clock_transition 0.05 [get_clocks clk]

# 2. IO DELAYS
set_input_delay -max 0.2 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -max 0.2 -clock clk [all_outputs]

# 3. MULTICYCLE PATHS
# The Interpolator math only updates when tick_60M pulses (every 15-16 cycles)
set_multicycle_path -setup 14 -to [get_cells u_path_*/u_interp/y*_reg*]
set_multicycle_path -hold 13 -to [get_cells u_path_*/u_interp/y*_reg*]

# The FIR Filter operates at ~300MHz (3 cycles of the ~960MHz / 1.04ns main clock)
set_multicycle_path -setup 3 -to [get_cells u_path_*/u_fir/*reg*]
set_multicycle_path -hold 2 -to [get_cells u_path_*/u_fir/*reg*]

