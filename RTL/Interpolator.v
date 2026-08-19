`timescale 1ns/1ps

module Interpolator #(
	parameter PACKET_LEN = 10000
)(
	input wire clk,
	input wire rst_n,
	input wire tick_60M,   
	input wire [2:0] L_val,
	input wire signed [15:0] sipo_data, 
	
	output reg signed [15:0] y0, y1, y2, y3, y4,
	output reg interp_valid
);

	// --- 4-SAMPLE SLIDING WINDOW ---
	reg signed [15:0] p0, p1, p2, p3;

	// --- LOCAL PIPELINE TRACKER ---
	reg [15:0] sample_cnt;
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0;
			sample_cnt <= 16'd0;
		end else if (tick_60M) begin
			p0 <= p1; p1 <= p2; p2 <= p3;
			p3 <= sipo_data; 
			sample_cnt <= sample_cnt + 1'b1;
		end
	end

	// The window is mathematically primed (p1=x(1), p2=x(2), p3=x(3)) EXACTLY at sample 3.
	wire is_start = (sample_cnt == 16'd3);
	wire is_end   = (sample_cnt == (PACKET_LEN + 1));

	// Gate the output so we don't emit startup zeros
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) interp_valid <= 1'b0;
		else if (tick_60M) begin
			if (sample_cnt == 16'd3) interp_valid <= 1'b1;
			else if (sample_cnt == (PACKET_LEN + 2)) interp_valid <= 1'b0;
		end
	end

	// =========================================================
	// MATHEMATICALLY PERFECT ROUNDING (Matches MATLAB 'Nearest')
	// =========================================================
	function signed [15:0] slice_round;
		input signed [31:0] val;
		reg signed [31:0] rounded;
		begin
			// Add 2^12 (Half of 2^13) to force Round-to-Nearest
			rounded = val + 32'sd4096; 
			slice_round = rounded >>> 13; // Arithmetic shift drops the 13 fraction bits
		end
	endfunction

	// =========================================================
	// BIT-TRUE HORNER POLYNOMIAL EVALUATOR
	// =========================================================
	function signed [15:0] eval_poly;
		input signed [15:0] c3, c2, c1, c0; // Q3.13
		input signed [15:0] u;              // Q3.13
		
		reg signed [31:0] p1, p2, p3;
		reg signed [15:0] t1, t2, t3;
		begin
			p1 = c3 * u;
			t1 = slice_round(p1) + c2;
			
			p2 = t1 * u;
			t2 = slice_round(p2) + c1;
			
			p3 = t2 * u;
			t3 = slice_round(p3) + c0;
			
			eval_poly = t3;
		end
	endfunction

	// =========================================================
	// CUBIC LANE COMPUTATION (PARALLEL)
	// =========================================================
	function signed [15:0] compute_lane;
		input signed [15:0] u;
		input signed [15:0] win_p0, win_p1, win_p2, win_p3;
		input start_flag, end_flag;
		
		reg signed [15:0] w0, w1, w2, w3;
		reg signed [15:0] u_use;
		reg signed [31:0] m0, m1, m2, m3;
		begin
			if (start_flag) begin
				w0 = 16'd0; 
				w1 = eval_poly(16'h0000, 16'h1000, 16'hD000, 16'h2000, u); 
				w2 = eval_poly(16'h0000, 16'hE000, 16'h4000, 16'h0000, u); 
				w3 = eval_poly(16'h0000, 16'h1000, 16'hF000, 16'h0000, u); 
			end else if (end_flag) begin
				u_use = 16'h2000 - u; 
				w0 = eval_poly(16'h0000, 16'h1000, 16'hF000, 16'h0000, u_use); 
				w1 = eval_poly(16'h0000, 16'hE000, 16'h4000, 16'h0000, u_use); 
				w2 = eval_poly(16'h0000, 16'h1000, 16'hD000, 16'h2000, u_use); 
				w3 = 16'd0;
			end else begin
				w0 = eval_poly(16'hF000, 16'h2000, 16'hF000, 16'h0000, u); 
				w1 = eval_poly(16'h3000, 16'hB000, 16'h0000, 16'h2000, u); 
				w2 = eval_poly(16'hD000, 16'h4000, 16'h1000, 16'h0000, u); 
				w3 = eval_poly(16'h1000, 16'hF000, 16'h0000, 16'h0000, u); 
			end
			
			m0 = win_p0 * w0;
			m1 = win_p1 * w1;
			m2 = win_p2 * w2;
			m3 = win_p3 * w3;
			
			// Round each product exactly like MATLAB does before summing
			compute_lane = slice_round(m0) + slice_round(m1) + slice_round(m2) + slice_round(m3);
		end
	endfunction

	// =========================================================
	// PARALLEL EXECUTION & OUTPUT LATCHING
	// =========================================================
	wire signed [15:0] w_y1, w_y2, w_y3, w_y4;
	reg  signed [15:0] u1, u2, u3, u4;

	always @(*) begin
		u1 = 0; u2 = 0; u3 = 0; u4 = 0; 
		case (L_val)
			3'd2: begin u1 = 16'h1000; end
			3'd3: begin u1 = 16'h0AAB; u2 = 16'h1555; end // Corrected LSBs
			3'd4: begin u1 = 16'h0800; u2 = 16'h1000; u3 = 16'h1800; end
			3'd5: begin u1 = 16'h0666; u2 = 16'h0CCD; u3 = 16'h1333; u4 = 16'h199A; end // Corrected LSBs
			default: ;
		endcase
	end

	assign w_y1 = (L_val >= 2) ? compute_lane(u1, p0, p1, p2, p3, is_start, is_end) : 16'd0;
	assign w_y2 = (L_val >= 3) ? compute_lane(u2, p0, p1, p2, p3, is_start, is_end) : 16'd0;
	assign w_y3 = (L_val >= 4) ? compute_lane(u3, p0, p1, p2, p3, is_start, is_end) : 16'd0;
	assign w_y4 = (L_val >= 5) ? compute_lane(u4, p0, p1, p2, p3, is_start, is_end) : 16'd0;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			y0 <= 0; y1 <= 0; y2 <= 0; y3 <= 0; y4 <= 0;
		end else if (tick_60M) begin
			y0 <= p1; 
			y1 <= w_y1; y2 <= w_y2; y3 <= w_y3; y4 <= w_y4;
		end
	end
endmodule