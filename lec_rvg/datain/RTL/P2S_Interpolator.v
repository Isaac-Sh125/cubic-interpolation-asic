`timescale 1ns/1ps

module P2S_Interpolator (
	input  wire clk,
	input  wire rst_n,
	input  wire [3:0] sub_count, 
	input  wire [2:0] L_val,     
	input  wire interp_valid, // Enables scheduling only after the interpolation window is valid

	input  wire signed [15:0] y0, y1, y2, y3, y4,

	output reg  signed [15:0] stream_out,
	output reg                stream_valid
);

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			stream_out   <= 16'sd0;
			stream_valid <= 1'b0;
		end 
		else begin
			stream_valid <= 1'b0;
			stream_out   <= 16'sd0; 

			if (interp_valid) begin
				case (L_val)
					3'd2: begin 
						if (sub_count == 4'd7)  begin stream_out <= y0; stream_valid <= 1'b1; end
						if (sub_count == 4'd15) begin stream_out <= y1; stream_valid <= 1'b1; end
					end
					3'd4: begin 
						if (sub_count == 4'd3)  begin stream_out <= y0; stream_valid <= 1'b1; end
						if (sub_count == 4'd7)  begin stream_out <= y1; stream_valid <= 1'b1; end
						if (sub_count == 4'd11) begin stream_out <= y2; stream_valid <= 1'b1; end
						if (sub_count == 4'd15) begin stream_out <= y3; stream_valid <= 1'b1; end
					end
					3'd3: begin 
						if (sub_count == 4'd4)  begin stream_out <= y0; stream_valid <= 1'b1; end
						if (sub_count == 4'd9)  begin stream_out <= y1; stream_valid <= 1'b1; end
						if (sub_count == 4'd14) begin stream_out <= y2; stream_valid <= 1'b1; end
					end
					3'd5: begin 
						if (sub_count == 4'd2)  begin stream_out <= y0; stream_valid <= 1'b1; end
						if (sub_count == 4'd5)  begin stream_out <= y1; stream_valid <= 1'b1; end
						if (sub_count == 4'd8)  begin stream_out <= y2; stream_valid <= 1'b1; end
						if (sub_count == 4'd11) begin stream_out <= y3; stream_valid <= 1'b1; end
						if (sub_count == 4'd14) begin stream_out <= y4; stream_valid <= 1'b1; end
					end
					default: ;
				endcase
			end
		end
	end
endmodule