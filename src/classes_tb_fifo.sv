// SPDX-License-Identifier: MIT
// (c) 2025 Manasa Ashwathappa
// ============================================================
// TRANSACTION CLASS
// ============================================================
class transaction;
  rand bit oper;            // 1 = write, 0 = read operation
  bit wr, rd;               // Control signals
  bit [7:0] data_in;        // Data to be written to FIFO
  bit [7:0] data_out;       // Data observed when reading
  bit full, empty;          // FIFO status flags

  // Random distribution: 50% read, 50% write
  constraint oper_ctrl {
    oper dist {1 := 50, 0 := 50};
  }
endclass


// ============================================================
// GENERATOR CLASS
// ============================================================
class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  event next, done;
  int cnt = 0;  // Total number of transactions to send
  int i = 0;    // Iteration counter

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction

  // Generate and send transactions
  task run();
    repeat (cnt) begin
      assert(tr.randomize()) else $error("[GEN]: Randomization failed!");
      i++;
      mbx.put(tr);
      $display("[GEN]: Operation=%0d | Iteration=%0d", tr.oper, i);
      @(next); // Wait for scoreboard before continuing
    end
    ->done; // Signal completion to environment
  endtask
endclass


// ============================================================
// DRIVER CLASS
// ============================================================
class driver;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction tr;

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  // Apply reset sequence to DUT
  task reset();
    fif.rst <= 1'b1;
    fif.wr  <= 1'b0;
    fif.rd  <= 1'b0;
    fif.data_in <= 8'd0;
    repeat (3) @(posedge fif.clk);
    fif.rst <= 1'b0;
    $display("[DRV]: Reset completed");
  endtask

  // Perform write transaction
  task write();
    @(posedge fif.clk);
    fif.wr <= 1'b1;
    fif.rd <= 1'b0;
    fif.data_in <= $urandom_range(1, 20);
    @(posedge fif.clk);
    fif.wr <= 1'b0;
    $display("[DRV]: WRITE -> Data=%0d", fif.data_in);
  endtask

  // Perform read transaction
  task read();
    @(posedge fif.clk);
    fif.rd <= 1'b1;
    fif.wr <= 1'b0;
    @(posedge fif.clk);
    fif.rd <= 1'b0;
    $display("[DRV]: READ -> Request sent");
  endtask

  // Main driver execution
  task run();
    forever begin
      mbx.get(tr);
      if (tr.oper)
        write();
      else
        read();
    end
  endtask
endclass


// ============================================================
// MONITOR CLASS
// ============================================================
class monitor;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction tr;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    forever begin
      @(posedge fif.clk);
      tr = new();

      // Capture control & input signals
      tr.wr = fif.wr;
      tr.rd = fif.rd;
      tr.data_in = fif.data_in;
      tr.full = fif.full;
      tr.empty = fif.empty;

      // Capture data output on next clock
      @(posedge fif.clk);
      tr.data_out = fif.data_out;

      mbx.put(tr);
      $display("[MON]: wr=%0d rd=%0d din=%0d dout=%0d full=%0d empty=%0d",
               tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
    end
  endtask
endclass


// ============================================================
// SCOREBOARD CLASS
// ============================================================
class scoreboard;
  mailbox #(transaction) mbx;
  transaction tr;
  bit [7:0] ref_q[$]; // FIFO reference queue
  int err = 0;        // Error counter
  event next;         // Sync with generator

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    forever begin
      mbx.get(tr);

      // Handle write operations
      if (tr.wr && !tr.full) begin
        ref_q.push_back(tr.data_in);
        $display("[SCO]: ENQ %0d (Depth=%0d)", tr.data_in, ref_q.size());
      end

      // Handle read operations
      if (tr.rd && !tr.empty) begin
        if (ref_q.size() == 0) begin
          $error("[SCO]: Underflow detected!");
          err++;
        end else begin
          bit [7:0] exp = ref_q.pop_front();
          if (tr.data_out !== exp) begin
            $error("[SCO]: DATA MISMATCH -> Exp=%0d Got=%0d", exp, tr.data_out);
            err++;
          end else begin
            $display("[SCO]: DATA MATCH -> %0d", tr.data_out);
          end
        end
      end

      ->next; // Signal generator to proceed
    end
  endtask
endclass


// ============================================================
// ENVIRONMENT CLASS
// ============================================================
class environment;
  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard sco;

  mailbox #(transaction) g2d; // Generator → Driver
  mailbox #(transaction) m2s; // Monitor → Scoreboard
  virtual fifo_if fif;        // Interface connection
  event next;                 // Synchronization event

  // Constructor
  function new(virtual fifo_if fif);
    this.fif = fif;

    // Create mailboxes
    g2d = new();
    m2s = new();

    // Instantiate components
    gen = new(g2d);
    drv = new(g2d);
    mon = new(m2s);
    sco = new(m2s);

    // Connect interface and sync events
    drv.fif = fif;
    mon.fif = fif;
    gen.next = next;
    sco.next = next;
  endfunction

  // Reset DUT before test
  task pre_test();
    repeat (2) @(posedge fif.clk); // Allow clock stabilization
    drv.reset();
  endtask

  // Main test phase
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join // Wait for all processes to finish
  endtask

  // Post-test summary
  task post_test();
    wait(gen.done.triggered);
    $display("[ENV]: Simulation completed | Errors = %0d", sco.err);
  endtask

  // Full environment execution
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass


// ============================================================
// TOP-LEVEL TESTBENCH MODULE
// ============================================================
module tb_fifo;

  // Instantiate interface
  fifo_if fif();

  // Instantiate DUT (Design Under Test)
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

  // Generate 50MHz clock (period = 20ns)
  initial fif.clk = 1'b0;
  always #10 fif.clk = ~fif.clk;

  // Create environment instance
  environment env;

  // Main simulation sequence
  initial begin
    env = new(fif);
    env.gen.cnt = 30;  // Number of transactions
    #20;               // Delay for clock stabilization
    env.run();
    $display("[TB]: Simulation finished successfully");
  end

  // Dump waveforms for GTKWave
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end

  // Safety timeout to end simulation
  initial begin
    #2000;
    $display("[TB]: Timeout reached, forcing finish");
    $finish;
  end

endmodule
