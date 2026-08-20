`timescale 1ns/1ps

module tb_asic;

	// =========================================================
	// 1. CONFIGURATION & PARAMETERS
	// =========================================================
	parameter string FILENAME = "input_hex_60M_L_5.txt"; 
	parameter string OUT_FILE = "rtl_output_POST_LPF_L_5.txt";
	
	// MANUAL CLOCK SELECTION
	parameter int L_VALUE = 5; 

	// =========================================================
	// 2. SIGNALS & VARIABLES
	// =========================================================
	logic clk_900;
	logic clk_960;
	logic dut_clk; 

	logic rst_n;
	logic serial_in_I;
	logic serial_in_Q;

	logic signed [15:0] I_out;
	logic signed [15:0] Q_out;
	logic output_valid;

	int file_in, file_out, scan_status;
	logic [15:0] hex_I, hex_Q;
	
	longint word_cnt; 
	bit recording_on; 

	// =========================================================
	// 3. CLOCK GENERATION & SELECTION
	// =========================================================
	initial clk_900 = 0; always #0.556 clk_900 = ~clk_900;
	initial clk_960 = 0; always #0.521 clk_960 = ~clk_960;

	assign dut_clk = ((L_VALUE == 2) || (L_VALUE == 4)) ? clk_960 : clk_900;
	int num_bits = ((L_VALUE == 3) || (L_VALUE == 5)) ? 15 : 16;

	// =========================================================
	// 4. DUT INSTANTIATION
	// =========================================================
	ASIC_Top dut (
		.clk            (dut_clk),       
		.rst_n          (rst_n),
		.serial_in_I    (serial_in_I),
		.serial_in_Q    (serial_in_Q),
		
		.pll_active_960 (),
		.I_out          (I_out),
		.Q_out          (Q_out),
		.output_valid   (output_valid)
	);

	// =========================================================
	// 5. MAIN STIMULUS PROCESS
	// =========================================================
	initial begin
		rst_n         = 0;
		serial_in_I   = 0;
		serial_in_Q   = 0;
		word_cnt      = 0;
		recording_on  = 1; 

		file_in = $fopen(FILENAME, "r");
		file_out = $fopen(OUT_FILE, "w");

		#20; 
		@(negedge dut_clk); rst_n = 1; #10;
		
		// =====================================================
		// D. CONFIGURATION INJECTION
		// =====================================================
		$display("Injecting Configuration Word...");
		begin
			logic [3:0] cfg_word = {1'b1, L_VALUE[2:0]};
			for (int i = 3; i >= 0; i--) begin
				@(negedge dut_clk);
				serial_in_I = cfg_word[i];
			end
			
			// Wait until configuration is accepted before streaming payload data.
			// Serial sample transmission begins from the following clock phase.
			wait(dut.u_control.run_en == 1'b1);
			serial_in_I = 1'b0; 
		end

		// =====================================================
		// E. DATA STREAMING LOOP
		// =====================================================
		$display("Starting Data Stream...");
		
		while (!$feof(file_in)) begin
			scan_status = $fscanf(file_in, "%h %h\n", hex_I, hex_Q);
			if (scan_status == 2) begin
				word_cnt++; 
				if (word_cnt % 1000 == 0) $display("Streamed %0d words...", word_cnt);

				for (int bit_idx = num_bits - 1; bit_idx >= 0; bit_idx--) begin
					@(negedge dut_clk); 
					serial_in_I = hex_I[bit_idx];
					serial_in_Q = hex_Q[bit_idx];
				end
			end
		end

		$display("End of Input File. stopping recording...");
		recording_on = 0; 
		#2000; 
		
		$fclose(file_in);
		$fclose(file_out);
		$display("Simulation Finished. Total Words Streamed: %0d", word_cnt);
		$finish;
	end

	// =========================================================
	// 6. OUTPUT MONITOR & CHECKERS
	// =========================================================
	bit data_started = 0;
	always @(posedge dut_clk) begin
		if (rst_n && output_valid && recording_on) begin
			if (!data_started) begin
				if (I_out != 16'd0 || Q_out != 16'd0) begin
					data_started = 1;
					$display("First valid data detected. Logging to file...");
				end
			end
			if (data_started) begin
				$fdisplay(file_out, "%h %h", I_out, Q_out);
			end
		end
	end

endmodule