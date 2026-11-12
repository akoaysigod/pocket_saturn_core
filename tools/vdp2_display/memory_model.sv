// Public behavioral model of VDP2_mem.sv palette contract: registered addresses,
// unregistered outputs, byte writes and same-port new data. Mixed-port collisions
// are unspecified in hardware; test writes occur before palette sampling.
module VDP2_PAL_RAM(input CLK,input[9:0]ADDR_A,input[15:0]DATA_A,input[1:0]WREN_A,
 output[15:0]Q_A,input[9:0]ADDR_B,input[15:0]DATA_B,input[1:0]WREN_B,output[15:0]Q_B);
 reg[15:0]mem[0:1023];reg[9:0]aa,ab;
 initial for(integer i=0;i<1024;i++)mem[i]=0;
 always @(posedge CLK)begin
  aa<=ADDR_A;ab<=ADDR_B;
  if(WREN_A[0])mem[ADDR_A][7:0]<=DATA_A[7:0];if(WREN_A[1])mem[ADDR_A][15:8]<=DATA_A[15:8];
  if(WREN_B[0])mem[ADDR_B][7:0]<=DATA_B[7:0];if(WREN_B[1])mem[ADDR_B][15:8]<=DATA_B[15:8];
 end
 assign Q_A=mem[aa];assign Q_B=mem[ab];
endmodule
// No VRAM writes in this fixture. Fail rather than pretend to accept one.
module VDP2_WRITE_FIFO(input CLK,RST_N,input[35:0]DATA,input WRREQ,RDREQ,
 output[35:0]Q,output EMPTY,FULL,LAST);
 assign Q=0;assign EMPTY=1;assign FULL=0;assign LAST=0;
 always @(posedge CLK)if(RST_N && WRREQ)$fatal(1,"UNMODELED_VRAM_WRITE");
endmodule
