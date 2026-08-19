`timescale 1ns/1ps
// =============================================================================
// tb_asic_saif.sv  -  SAIF-per-L power stimulus for final_cubic (28nm)
// Adapted from Pchip/GL_sim/tb_asic.sv (yitzhak2 golden GLS testbench).
// Same DUT, same stimulus files, same clocking; the ONLY additions are:
//   * L selected at RUNTIME via +L=<2|3|4|5>  (one build, four runs -
//     mirrors khamaysi final_pilot run_saifpnr.sh which selects L at runtime)
//   * SAIF toggle capture over the DUT during the active data window, gated by
//     +SAIF +SAIFFILE=<path>   ->  read by report_power (clock-gating aware)
//   * VCD dump only if +VCD is given (avoids the 6.8 GB dump during SAIF runs)
// Self-checks printed so the log proves the DUT actually ran (out>0, words>0).
// =============================================================================
module design_tb;

  // ---- runtime config ----
  int    L_VALUE   = 5;                 // overridden by +L=<l>
  string FILENAME;
  int    num_bits;
  string saif_file;
  bit    do_saif;
  bit    do_vcd;

  // ---- signals ----
  logic clk_900, clk_960, dut_clk;
  logic rst_n, serial_in_I, serial_in_Q;
  logic signed [15:0] I_out, Q_out;
  logic output_valid;

  int file_in, scan_status;
  logic [15:0] hex_I, hex_Q;
  longint word_cnt;
  longint out_nonzero;                 // self-check: DUT produced output
  bit recording_on;

  // ---- clocks (both free-running; DUT clock selected by L) ----
  initial clk_900 = 0; always #0.556 clk_900 = ~clk_900;   // ~900 MHz
  initial clk_960 = 0; always #0.521 clk_960 = ~clk_960;   // ~960 MHz
  // L2/L4 = WL16 @ 960 ; L3/L5 = WL15 @ 900   (matches tb_asic.sv)
  assign dut_clk = ((L_VALUE == 2) || (L_VALUE == 4)) ? clk_960 : clk_900;

  // ---- DUT: the core (maps to Innovus instance I0) ----
  ASIC_Top dut (
    .clk(dut_clk), .rst_n(rst_n),
    .serial_in_I(serial_in_I), .serial_in_Q(serial_in_Q),
    .pll_active_960(), .I_out(I_out), .Q_out(Q_out), .output_valid(output_valid),
    .sanity_in_inv(1'b0), .sanity_out_inv(),
    .sanity_in_ff(1'b0),  .sanity_out_ff(),
    .scan_en(1'b0), .scan_in1(1'b0), .scan_in2(1'b0), .scan_in3(1'b0),
    .scan_out1(), .scan_out2(), .scan_out3()
  );

  // ---- stimulus ----
  initial begin
    // runtime args
    if (!$value$plusargs("L=%d", L_VALUE)) L_VALUE = 5;
    num_bits = ((L_VALUE == 3) || (L_VALUE == 5)) ? 15 : 16;
    FILENAME = $sformatf("input_hex_60M_L_%0d.txt", L_VALUE);
    do_saif  = $test$plusargs("SAIF");
    do_vcd   = $test$plusargs("VCD");
    if (!$value$plusargs("SAIFFILE=%s", saif_file)) saif_file = $sformatf("core_L%0d.saif", L_VALUE);
    $display("CONFIG: L=%0d WL=%0d file=%s saif=%b(%s) vcd=%b", L_VALUE, num_bits, FILENAME, do_saif, saif_file, do_vcd);

    if (do_vcd) begin $dumpfile("gl_sim.vcd"); $dumpvars(0, design_tb); end

    // SAIF: arm toggle monitoring over the DUT (region set now, counting later)
    if (do_saif) begin
      $set_gate_level_monitoring("on");
      $set_toggle_region(design_tb.dut);
    end

    rst_n = 0; serial_in_I = 0; serial_in_Q = 0;
    word_cnt = 0; out_nonzero = 0; recording_on = 1;

    file_in = $fopen(FILENAME, "r");
    if (file_in == 0) begin $display("FATAL: cannot open %s", FILENAME); $finish; end

    #20; @(negedge dut_clk); rst_n = 1; #10;

    // ---- config word: {1'b1, L[2:0]} MSB-first on serial_in_I ----
    $display("Injecting config word for L=%0d ...", L_VALUE);
    begin
      logic [3:0] cfg_word; cfg_word = {1'b1, L_VALUE[2:0]};
      for (int i = 3; i >= 0; i--) begin @(negedge dut_clk); serial_in_I = cfg_word[i]; end
      wait (dut.w_run_en == 1'b1);
      serial_in_I = 1'b0;
    end

    // ---- start SAIF counting at the active data window ----
    if (do_saif) $toggle_start;
    $display("Streaming data ...");
    while (!$feof(file_in)) begin
      scan_status = $fscanf(file_in, "%h %h\n", hex_I, hex_Q);
      if (scan_status == 2) begin
        word_cnt++;
        if (word_cnt % 1000 == 0) $display("  streamed %0d words", word_cnt);
        for (int b = num_bits - 1; b >= 0; b--) begin
          @(negedge dut_clk); serial_in_I = hex_I[b]; serial_in_Q = hex_Q[b];
        end
      end
    end

    recording_on = 0;
    #2000;
    // ---- stop + write SAIF ----
    if (do_saif) begin
      $toggle_stop;
      $toggle_report(saif_file, 1.0e-9, "design_tb.dut");
      $display("SAIF written: %s", saif_file);
    end
    $fclose(file_in);
    $display("DONE L=%0d words=%0d out_nonzero=%0d time=%0t", L_VALUE, word_cnt, out_nonzero, $time);
    $finish;
  end

  // ---- self-check monitor: count non-zero outputs (proves DUT is alive) ----
  always @(posedge dut_clk)
    if (rst_n && output_valid && recording_on && (I_out !== 16'd0 || Q_out !== 16'd0))
      out_nonzero++;

endmodule
