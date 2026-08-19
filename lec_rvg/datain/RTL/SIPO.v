`timescale 1ns/1ps
module SIPO (
	input  wire        clk,
	input  wire        rst_n,
	input  wire        serial_in,
	input  wire        enable,     // Controlled by run_en
	input  wire        mode_15bit, // 1 = 15b (Sign Ext), 0 = 16b
	
	output reg signed [15:0] data_out
);

	// A single 16-bit shift register covers both modes
	reg [15:0] shift_reg;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			shift_reg <= 16'd0;
		end else if (enable) begin
			// Continuously shift data in (MSB first)
			shift_reg <= {shift_reg[14:0], serial_in};
		end
	end

	// Combinational logic to format the output continuously
	always @(*) begin
		if (mode_15bit) begin
			// 15-bit Mode: The valid word is in shift_reg[14:0]
			// Sign Extension: Replicate bit 14 into bit 15
			data_out = {shift_reg[14], shift_reg[14:0]};
		end else begin
			// 16-bit Mode: The valid word is shift_reg[15:0]
			data_out = shift_reg[15:0];
		end
	end

endmodule