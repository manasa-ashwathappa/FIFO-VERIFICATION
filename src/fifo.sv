// SPDX-License-Identifier: MIT
// (c) 2025 Manasa Ashwathappa

module fifo(
  input  logic        clk,
  input  logic        rst,
  input  logic        wr,
  input  logic        rd,
  input  logic [7:0]  din,
  output logic [7:0]  dout,
  output logic        empty,
  output logic        full
);

  // Internal pointers and count
  logic [3:0] w_ptr = 0, r_ptr = 0;
  logic [4:0] count = 0;
  logic [7:0] mem [15:0];   // 16 x 8-bit FIFO storage

  // Sequential logic
  always_ff @(posedge clk) begin
    if (rst) begin
      w_ptr <= 0;
      r_ptr <= 0;
      count <= 0;
      dout  <= 0;
    end
    else begin
      // Write operation
      if (wr && !full) begin
        mem[w_ptr] <= din;
        w_ptr <= w_ptr + 1;
        count <= count + 1;
      end
      // Read operation
      else if (rd && !empty) begin
        dout <= mem[r_ptr];
        r_ptr <= r_ptr + 1;
        count <= count - 1;
      end
    end
  end

  // Status flags
  assign empty = (count == 0);
  assign full  = (count == 16);

endmodule
