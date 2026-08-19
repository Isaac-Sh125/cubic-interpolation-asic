`timescale 1ns/1ps

module Control_Unit #(
	parameter PACKET_LEN = 10000 // N: Default packet length for edge logic
)(
	input  wire clk,            // Single System Clock
	input  wire rst_n,
	input  wire serial_in_I,    // Receives configuration (L_value) before streaming

	// --- Status Outputs ---
	output reg  pll_req_960,    // 1 = Expecting 960MHz, 0 = Expecting 900MHz
	output reg  mode_15bit,     // 1 = 15-bit (L=3,5), 0 = 16-bit (L=2,4)
	output reg  [2:0] L_val,    // The extracted L factor

	// --- Global Timing & Control ---
	output reg  run_en,         // Gates the entire chip
	output wire tick_60M,       // 1-cycle pulse at end of word
	output reg  [3:0] sub_count,// Global mod counter (0-14 or 0-15)
	output wire is_start,       // 1 if Sample Count == 0
	output wire is_end          // 1 if Sample Count >= N-2
);

	// =========================================================
	// 1. CONFIGURATION SIPO (4-bits)
	// =========================================================
	reg [3:0] cfg_reg;
	reg       cfg_valid;
	
	wire cfg_illegal = (cfg_reg[2:0] < 3'd2) || (cfg_reg[2:0] > 3'd5);

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cfg_reg     <= 4'd0;
			cfg_valid   <= 1'b0;
			L_val       <= 3'd0;
			mode_15bit  <= 1'b0;
			pll_req_960 <= 1'b0;
			run_en      <= 1'b0;
		end else begin
			if (!cfg_valid) begin
				cfg_reg <= {cfg_reg[2:0], serial_in_I}; 
				if (cfg_reg[2] == 1'b1) begin
					cfg_valid <= 1'b1;
				end
			end 
			else if (cfg_valid && !run_en) begin
				L_val <= cfg_reg[2:0];
				
				if (cfg_reg[2:0] == 3'd3 || cfg_reg[2:0] == 3'd5) begin
					mode_15bit  <= 1'b1; 
					pll_req_960 <= 1'b0;
				end else begin
					mode_15bit  <= 1'b0; 
					pll_req_960 <= 1'b1;
				end

				if (cfg_reg[3] == 1'b1 && !cfg_illegal) begin
					run_en <= 1'b1;
				end
			end
		end
	end

	// =========================================================
	// 2. GLOBAL MOD COUNTER & TICK GENERATOR
	// =========================================================
	wire [3:0] max_count = mode_15bit ? 4'd14 : 4'd15;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			sub_count <= 4'd0;
		end else if (run_en) begin
			if (sub_count == max_count)
				sub_count <= 4'd0;
			else
				sub_count <= sub_count + 1'b1;
		end else begin
			sub_count <= 4'd0; 
		end
	end

	// --- THE FIX ---
	// Delay the pulse by 1 clock cycle!
	// This ensures the SIPO has completely finished shifting the LSB
	// before the Interpolator is allowed to latch the 16-bit word.
	reg tick_60M_reg;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) 
			tick_60M_reg <= 1'b0;
		else 
			tick_60M_reg <= (run_en && (sub_count == max_count));
	end
	
	assign tick_60M = tick_60M_reg;

	// =========================================================
	// 3. PACKET COUNTER (EDGE LOGIC)
	// =========================================================
	reg [15:0] packet_cnt;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			packet_cnt <= 16'd0;
		end else if (run_en && tick_60M) begin
			packet_cnt <= packet_cnt + 1'b1;
		end
	end

	assign is_start = (packet_cnt == 16'd0);
	assign is_end   = (packet_cnt >= (PACKET_LEN - 2));

endmodule