// SPDX-License-Identifier: MIT
// (c) 2025 Manasa Ashwathappa
//
// -------------------------------------------------------------
// Testbench: tb_fifo.sv
// -------------------------------------------------------------

module tb_fifo;

  // -----------------------------------------------------------
  // 1. Instantiate the interface
  // -----------------------------------------------------------
  fifo_if fif();
  // -----------------------------------------------------------
  // 2. Instantiate the DUT (FIFO)
  // -----------------------------------------------------------
  fifo dut (
    .clk   (fif.clk),
    .rst   (fif.rst),
    .wr    (fif.wr),
    .rd    (fif.rd),
    .din   (fif.data_in),
    .dout  (fif.data_out),
    .empty (fif.empty),
    .full  (fif.full)
  );
  // -----------------------------------------------------------
  // 3. Clock generation
  // -----------------------------------------------------------
  initial fif.clk = 1'b0;
  always #10 fif.clk = ~fif.clk;
  // -----------------------------------------------------------
  // 4. Environment instantiation
  // -----------------------------------------------------------
  environment env;
  // -----------------------------------------------------------
  // 5. Main simulation control
  // -----------------------------------------------------------
  initial begin
    env = new(fif);
    env.gen.cnt = 30;
    env.run();
    $display("[TB]: Simulation finished successfully");
  end

  // -----------------------------------------------------------
  // 6. Waveform dumping
  // -----------------------------------------------------------
  initial begin
    $dumpfile("waves/dump.vcd");  // Output waveform file
    $dumpvars(0, tb_fifo);        // Dump all variables in hierarchy
  end

  // -----------------------------------------------------------
  // 7. Timeout safeguard
  // -----------------------------------------------------------
  initial begin
    #2000;   // Simulation time limit (in nanoseconds)
    $display("[TB]: Timeout reached, forcing finish");
    $finish;
  end

endmodule
