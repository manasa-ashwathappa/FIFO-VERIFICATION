// SPDX-License-Identifier: MIT
// (c) 2025 Manasa Ashwathappa
//
// Description:
// -------------
// This file contains all the SystemVerilog classes used in the FIFO
// verification environment: transaction, generator, driver, monitor,
// scoreboard, and environment. Together they form a minimal,
// UVM-like testbench structure (without UVM dependencies).
//

// ============================================================
// TRANSACTION CLASS
// ============================================================
// Represents one read or write operation.
// Contains all stimulus and observed data fields.
// ============================================================
class transaction;
  rand bit oper;            // 1 = write, 0 = read operation
  bit wr, rd;               // Control signals
  bit [7:0] data_in;        // Data to be written
  bit [7:0] data_out;       // Data observed on read
  bit full, empty;          // FIFO status flags

  // Randomization distribution: 50% writes, 50% reads
  constraint oper_ctrl {
    oper dist {1 := 50, 0 := 50};
  }
endclass


// ============================================================
// GENERATOR CLASS
// ============================================================
// Creates randomized transactions and sends them to the driver
// through a mailbox. The generator stops after a fixed count.
// ============================================================
class generator;
  transaction tr;                   // Transaction object
  mailbox #(transaction) mbx;       // Mailbox to driver
  event next, done;                 // Sync events
  int cnt = 0;                      // Number of transactions
  int i = 0;                        // Iteration counter

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction

  // Main stimulus loop
  task run();
    repeat (cnt) begin
      assert(tr.randomize()) else $error("[GEN]: Randomization failed!");
      i++;
      mbx.put(tr);
      $display("[GEN]: Operation=%0d | Iteration=%0d", tr.oper, i);
      @(next);  // Wait until scoreboard signals next transaction
    end
    ->done; // Notify environment that generation is finished
  endtask
endclass


// ============================================================
// DRIVER CLASS
// ============================================================
// Drives the FIFO DUT through the interface using randomized
// transaction data received from the generator.
// ============================================================
class driver;
  virtual fifo_if fif;              // Virtual interface handle
  mailbox #(transaction) mbx;       // Receives transactions
  transaction tr;                   // Current transaction

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  // Reset sequence
  task reset();
    fif.rst <= 1'b1;
    fif.wr  <= 1'b0;
    fif.rd  <= 1'b0;
    fif.data_in <= 8'd0;
    repeat (3) @(posedge fif.clk);
    fif.rst <= 1'b0;
    $display("[DRV]: Reset completed");
  endtask

  // Write operation task
  task write();
    @(posedge fif.clk);
    fif.wr <= 1'b1;
    fif.rd <= 1'b0;
    fif.data_in <= $urandom_range(1, 20);
    @(posedge fif.clk);
    fif.wr <= 1'b0;
    $display("[DRV]: WRITE -> Data=%0d", fif.data_in);
  endtask

  // Read operation task
  task read();
    @(posedge fif.clk);
    fif.rd <= 1'b1;
    fif.wr <= 1'b0;
    @(posedge fif.clk);
    fif.rd <= 1'b0;
    $display("[DRV]: READ -> Request sent");
  endtask

  // Main driver loop: get transaction and perform operation
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
// Observes signals from the FIFO interface and records
// the transactions seen for checking in the scoreboard.
// ============================================================
class monitor;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction tr;

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  // Continuous monitoring of DUT signals
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

      // Capture output on next clock (registered output)
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
// Implements a reference model to verify FIFO correctness.
// It stores written data and compares expected vs actual
// output on reads.
// ============================================================
class scoreboard;
  mailbox #(transaction) mbx;
  transaction tr;
  bit [7:0] ref_q[$];     // Queue acting as golden FIFO
  int err = 0;            // Error counter
  event next;             // Synchronization event

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  // Compare expected vs actual data
  task run();
    forever begin
      mbx.get(tr);

      // Enqueue data when write is valid
      if (tr.wr && !tr.full) begin
        ref_q.push_back(tr.data_in);
        $display("[SCO]: ENQ %0d (Depth=%0d)", tr.data_in, ref_q.size());
      end

      // Dequeue and compare on read
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

      ->next; // Notify generator to proceed
    end
  endtask
endclass


// ============================================================
// ENVIRONMENT CLASS
// ============================================================
// Top-level component that instantiates and coordinates all
// other components: generator, driver, monitor, and scoreboard.
// ============================================================
class environment;
  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard sco;

  mailbox #(transaction) g2d; // Generator → Driver
  mailbox #(transaction) m2s; // Monitor → Scoreboard
  virtual fifo_if fif;        // DUT interface handle
  event next;                 // Sync event

  // Constructor
  function new(virtual fifo_if fif);
    this.fif = fif;
    g2d = new();
    m2s = new();
    gen = new(g2d);
    drv = new(g2d);
    mon = new(m2s);
    sco = new(m2s);
  endfunction

  // Pre-test phase: apply reset
  task pre_test();
    drv.fif = fif;
    mon.fif = fif;
    drv.reset();
  endtask

  // Parallel test execution
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask

  // Post-test summary
  task post_test();
    wait(gen.done.triggered);
    $display("[ENV]: Simulation completed | Errors = %0d", sco.err);
  endtask

  // Unified run task
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass
