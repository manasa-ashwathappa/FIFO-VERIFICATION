// SPDX-License-Identifier: MIT
// (c) 2025 Manasa Ashwathappa

interface fifo_if;
  logic clk;           // Clock signal
  logic rst;           // Active-high synchronous reset
  logic wr;            // Write enable
  logic rd;            // Read enable
  logic [7:0] data_in; // Input data bus
  logic [7:0] data_out;// Output data bus
  logic full;          // FIFO full flag
  logic empty;         // FIFO empty flag
endinterface
