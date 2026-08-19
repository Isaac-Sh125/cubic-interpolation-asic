`timescale 1ns/1ps
module MinAJ2_Datapath (
	input  wire clk,          
	input  wire rst_n,
	input  wire sipo_enable,
	input  wire tick_60M,     
	input  wire [3:0] sub_count, 
	input  wire is_start,     // Ignored, handled locally now
	input  wire is_end,       // Ignored, handled locally now
	input  wire [2:0] L_val,
	input  wire mode_15bit,
	input  wire serial_in,
	
	output wire signed [15:0] filt_out,
	output wire               filt_valid
);

	wire signed [15:0] w_sipo_out;
	
	SIPO u_sipo (
		.clk(clk), .rst_n(rst_n),
		.enable(sipo_enable), .serial_in(serial_in),
		.mode_15bit(mode_15bit), .data_out(w_sipo_out)
	);

	wire signed [15:0] y0, y1, y2, y3, y4;
	wire w_interp_valid;

	Interpolator u_interp (
		.clk(clk), .rst_n(rst_n),
		.tick_60M(tick_60M),
		.L_val(L_val), .sipo_data(w_sipo_out),
		.y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4),
		.interp_valid(w_interp_valid)
	);
	
	wire signed [15:0] p2s_out;
	wire               p2s_valid;

	P2S_Interpolator u_p2s (
		.clk(clk), .rst_n(rst_n),
		.sub_count(sub_count), .L_val(L_val),
		.interp_valid(w_interp_valid),
		.y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4),
		.stream_out(p2s_out), .stream_valid(p2s_valid)
	);

	// =====================================================
	// 5) FIR FILTER (BYPASSED FOR NOW)
	// =====================================================
	 FIR_LPF_TRANSPOSED u_fir (
		.clk     (clk),
		.rst_n   (rst_n),
		.L_val   (L_val),
		.x_in    (p2s_out),
		.x_valid (p2s_valid),
		.y_out   (filt_out),
		.y_valid (filt_valid)
	); 
	
endmodule