module VDP2_PAL_RAM (
  input CLK,
  input [9:0] ADDR_A, input [15:0] DATA_A, input [1:0] WREN_A,
  output [15:0] Q_A,
  input [9:0] ADDR_B, input [15:0] DATA_B, input [1:0] WREN_B,
  output [15:0] Q_B
);
  assign Q_A = 16'h0;
  assign Q_B = 16'h0;
endmodule
module VDP2_WRITE_FIFO (
  input CLK, input RST_N, input [35:0] DATA,
  input WRREQ, input RDREQ, output [35:0] Q,
  output EMPTY, output FULL, output LAST
);
  assign Q = 36'h0;
  assign EMPTY = 1'b1;
  assign FULL = 1'b0;
  assign LAST = 1'b0;
endmodule
