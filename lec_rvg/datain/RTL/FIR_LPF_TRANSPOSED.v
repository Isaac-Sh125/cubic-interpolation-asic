`timescale 1ns/1ps

module FIR_LPF_TRANSPOSED (
	input  wire              clk,
	input  wire              rst_n,
	
	// Selects coefficient bank (2, 3, 4, or 5)
	input  wire [2:0]        L_val, 

	input  wire signed [15:0] x_in,   // Q1.14
	input  wire              x_valid,

	output reg  signed [15:0] y_out,  // Q1.14
	output reg               y_valid
);

	localparam integer NTAPS = 10;
	localparam integer FL    = 14; 
	
	// Updated to 36-bit limits to match the optimized accumulator size
	localparam signed [35:0] MAX_POS = 36'sd32767;
	localparam signed [35:0] MIN_NEG = -36'sd32768;

	// ------------------------------------------------------------
	// 1. Adaptive Coefficient ROM (10 Taps)
	// ------------------------------------------------------------
	function signed [15:0] coeff;
		input integer k;
		input [2:0]   current_L;
		begin
			case (current_L)
				// =========================================================
				// L=2
				// =========================================================
				2: begin
					case (k)
						0, 9: coeff = 16'sd146;
						1, 8: coeff = -16'sd63;
						2, 7: coeff = -16'sd1190;
						3, 6: coeff = 16'sd1525;
						4, 5: coeff = 16'sd7773;
						default: coeff = 16'sd0;
					endcase
				end

				// =========================================================
				// L=3 
				// =========================================================
				3: begin
					case (k)
						0, 9: coeff = 16'sd219;
						1, 8: coeff = -16'sd1104;
						2, 7: coeff = -16'sd5;
						3, 6: coeff = 16'sd3030;
						4, 5: coeff = 16'sd6052;
						default: coeff = 16'sd0;
					endcase
				end

				// =========================================================
				// L=4
				// =========================================================
				4: begin
					case (k)
						0, 9: coeff = -16'sd592;
						1, 8: coeff = -16'sd697;
						2, 7: coeff = 16'sd1682;
						3, 6: coeff = 16'sd3097;
						4, 5: coeff = 16'sd4703;
						default: coeff = 16'sd0;
					endcase
				end

				// =========================================================
				// L=5 (Default)
				// =========================================================
				default: begin
					case (k)
						0, 9: coeff = -16'sd1740;
						1, 8: coeff = 16'sd1152;
						2, 7: coeff = 16'sd2038;
						3, 6: coeff = 16'sd3046;
						4, 5: coeff = 16'sd3696;
						default: coeff = 16'sd0;
					endcase
				end
			endcase
		end
	endfunction

	// ------------------------------------------------------------
	// 2. Multipliers (Symmetric: 5 unique products needed)
	// ------------------------------------------------------------
	wire signed [31:0] prod [0:4];
	genvar g;
	generate
		for (g = 0; g <= 4; g = g + 1) begin : GEN_PROD
			assign prod[g] = $signed(x_in) * $signed(coeff(g, L_val));
		end
	endgenerate

	// ------------------------------------------------------------
	// 3. Transposed Accumulator Chain (Optimized to 36-bit)
	// ------------------------------------------------------------
	reg signed [35:0] acc_stage [0:NTAPS-1];
	reg signed [35:0] final_acc;
	integer i;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			for (i = 0; i < NTAPS; i = i + 1)
				acc_stage[i] <= 36'sd0;  // Initialize as 36-bit
			y_out   <= 16'sd0;
			y_valid <= 1'b0;
		end else begin
			y_valid <= 1'b0;
			if (x_valid) begin
				
				// Stage 0
				acc_stage[0] <= prod[0];

				// Stages 1 to 4 (First half)
				for (i = 1; i <= 4; i = i + 1)
					acc_stage[i] <= acc_stage[i-1] + prod[i];

				// Stages 5 to 9 (Second half utilizing symmetric products)
				for (i = 5; i < NTAPS; i = i + 1)
					acc_stage[i] <= acc_stage[i-1] + prod[9-i];

				// Final output shift
				final_acc = acc_stage[NTAPS-1] >>> FL;

				// Saturation Logic
				if (final_acc > MAX_POS) y_out <= {1'b0, 15'h7FFF}; 
				else if (final_acc < MIN_NEG) y_out <= {1'b1, 15'h0000}; 
				else y_out <= final_acc[15:0];   

				y_valid <= 1'b1;
			end
		end
	end

endmodule