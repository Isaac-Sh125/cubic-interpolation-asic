`timescale 1ns/1ps

module ASIC_Top (
	// --- Clock Source ---
	input wire clk, 
	input wire rst_n,

	input  wire serial_in_I,
	input  wire serial_in_Q,

	// System Status
	output wire pll_active_960, 

	// Final FILTERED Outputs
	output wire signed [15:0] I_out,
	output wire signed [15:0] Q_out,
	output wire output_valid,

	// Sanity Check IOs
	input  wire sanity_in_inv,
	output wire sanity_out_inv,
	input  wire sanity_in_ff,
	output reg  sanity_out_ff
);

	// -------- Internal Nets --------
	wire w_pll_req;       
	wire [2:0] w_L_val;
	wire w_mode_15bit;
	
	// Global Timing Signals
	wire w_run_en;
	wire w_tick_60M;
	wire [3:0] w_sub_count;
	wire w_is_start;
	wire w_is_end;

	// FIR outputs from datapaths
	wire signed [15:0] I_filt;
	wire signed [15:0] Q_filt;
	wire I_valid;
	wire Q_valid;

	// =========================================================
	// 1. STATUS OUTPUT
	// =========================================================
	assign pll_active_960 = w_pll_req;

	// =========================================================
	// 2. CONTROL UNIT
	// =========================================================
	Control_Unit #(
		.PACKET_LEN(10000)
	) u_control (
		.clk(clk),                 
		.rst_n(rst_n),
		.serial_in_I(serial_in_I), 
		
		.pll_req_960(w_pll_req),  
		.mode_15bit(w_mode_15bit),
		.L_val(w_L_val),
		
		.run_en(w_run_en),
		.tick_60M(w_tick_60M),
		.sub_count(w_sub_count),
		.is_start(w_is_start),
		.is_end(w_is_end)
	);

	// =========================================================
	// 3. DATAPATH I (In-Phase)
	// =========================================================
	MinAJ2_Datapath u_path_I (
		.clk(clk),                 
		.rst_n(rst_n),
		
		.sipo_enable(w_run_en),    
		.tick_60M(w_tick_60M),    
		.sub_count(w_sub_count),
		.is_start(w_is_start),
		.is_end(w_is_end),
		
		.L_val(w_L_val),
		.mode_15bit(w_mode_15bit),
		.serial_in(serial_in_I),
		
		.filt_out(I_filt),
		.filt_valid(I_valid)
	);

	// =========================================================
	// 4. DATAPATH Q (Quadrature)
	// =========================================================
	MinAJ2_Datapath u_path_Q (
		.clk(clk),                 
		.rst_n(rst_n),
		
		.sipo_enable(w_run_en),
		.tick_60M(w_tick_60M),
		.sub_count(w_sub_count),
		.is_start(w_is_start),
		.is_end(w_is_end),
		
		.L_val(w_L_val),
		.mode_15bit(w_mode_15bit),
		.serial_in(serial_in_Q),
		
		.filt_out(Q_filt),
		.filt_valid(Q_valid)
	);

	// =========================================================
	// 5. OUTPUT ASSIGNMENT
	// =========================================================
	assign I_out = I_filt;
	assign Q_out = Q_filt;
	assign output_valid = I_valid & Q_valid;

	// =========================================================
	// 6. SANITY CHECKS (INVERTER & FLIP-FLOP)
	// =========================================================
	assign sanity_out_inv = ~sanity_in_inv;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) sanity_out_ff <= 1'b0;
		else        sanity_out_ff <= sanity_in_ff;
	end

endmodule
