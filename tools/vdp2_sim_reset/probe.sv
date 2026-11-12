`timescale 1ns/1ps
module probe;
 import VDP2_PKG::*;
 bit clk=0;always #10 clk=~clk;
 bit phase=0;always @(negedge clk)phase=~phase;
 wire ce_r=phase;
 bit rst_n=0;
 reg[15:0]di=0;reg cs_n=1,ad_n=1,dten_n=1,req_n=1;
 reg[7:0]screen=0;
 reg blank=0;
 integer checks=0;
    VDP2 native(
        .CLK(clk),.RST_N(rst_n),.RES_N(rst_n),.CE_R(phase),.CE_F(!phase),
        .DI(di),.DO(),.CS_N(cs_n),.AD_N(ad_n),.DTEN_N(dten_n),.REQ_N(req_n),.RDY_N(),
        .VINT_N(),.HINT_N(),.DCE_R(),.DCE_F(),.HTIM_N(),.VTIM_N(),.FBDI(16'b0),.FBDO(),
        .PAL(1'b1),.EXLAT_N(1'b1),.RA0_A(),.RA1_A(),.RA_D(),.RA_WE(),.RA_RD(),
        .RA0_Q(32'b0),.RA1_Q(32'b0),.RB0_A(),.RB1_A(),.RB_D(),.RB_WE(),.RB_RD(),
        .RB0_Q(32'b0),.RB1_Q(32'b0),.R(),.G(),.B(),.DCLK(),.HS_N(),.VS_N(),.HBL_N(),.VBL_N(),
        .FIELD(),.INTERLACE(),.HRES(),.VRES(),.SCRN_EN(screen),.DBG_EXT(8'b0));
 task automatic capture_header(input[20:0]byte_addr,input bit reading,input[1:0]disable_mask);
  @(negedge clk);#0.1;cs_n=0;ad_n=1;dten_n=1;req_n=1;di={1'b0,reading,1'b0,1'b0,byte_addr[20:9]};
  do begin @(posedge clk);#0.1;end while(!ce_r);
  @(negedge clk);#0.1;di=16'h8000|{2'b0,disable_mask,4'b0,byte_addr[8:1]};
  do begin @(posedge clk);#0.1;end while(!ce_r);
 endtask
 task automatic bus_write(input[20:0]byte_addr,input[15:0]data,input[1:0]be);
  capture_header(byte_addr,0,~be);
  @(negedge clk);#0.1;ad_n=0;req_n=0;dten_n=0;di=data;
  @(posedge clk);#0.1;
  @(negedge clk);#0.1;req_n=1;dten_n=1;
  repeat(12)@(negedge clk);cs_n=1;ad_n=1;
  repeat(4)@(negedge clk);
 endtask

 task check_layers(input string label);
  for(integer layer=0;layer<6;layer++)begin
   @(negedge clk);screen=8'(1<<(layer==0?5:layer==1?4:layer-2));
   repeat(3)@(negedge clk);
   if(native.DOT_FST.DC !== 24'(layer+1))$fatal(1,"LAYER label=%s layer=%0d got=%h",label,layer,native.DOT_FST.DC);
   checks++;
   $display("LAYER %s index=%0d DISP=%0d DISP_INT=%0d first=%h",label,layer,native.DISP,native.DISP_INT,native.DOT_FST.DC);
  end
  @(negedge clk);screen=8'h3f;repeat(3)@(negedge clk);
  if(native.DOT_FST.DC!=1 || native.DOT_SEC.DC!=2 || native.DOT_THD.DC!=3)$fatal(1,"TIE_ORDER");
  checks++;
 endtask
 initial begin
  // Explicit checkpoints: no full raster/memory integration claim.
  force native.DOT_CE_R=1;force native.DOT_CE_F=0;
  force native.VBLANK=blank;
  force native.SDOT=34'd1;
  force native.R0DOT=28'd2;force native.N0DOT=28'd3;
  force native.N1DOT=28'd4;force native.N2DOT=28'd5;force native.N3DOT=28'd6;
  force native.BACK_DC=24'h101010;
  repeat(4)@(negedge clk);rst_n=1;
  bus_write(21'h180020,16'h001f,3);
  bus_write(21'h1800f0,16'h0003,3);
  bus_write(21'h1800f8,16'h0303,3);
  bus_write(21'h1800fa,16'h0303,3);
  bus_write(21'h1800fc,16'h0003,3);
  if(native.REGS.BGON!=16'h001f || native.REGS.PRINA!=16'h0303)$fatal(1,"BUS_SETUP");
  bus_write(21'h180000,16'h8000,3);
  if(!native.REGS.TVMD.DISP || !native.DISP || native.DISP_INT)$fatal(1,"ACTIVE_ENABLE_LATCH");
  @(negedge clk);blank=1;repeat(3)@(negedge clk);
  if(!native.DISP_INT)$fatal(1,"BLANK_ENABLE_LATCH");
  check_layers("blank_latched");
  @(negedge clk);blank=0;
  check_layers("enabled_active_after_blank");
  bus_write(21'h180000,16'h0000,3);
  if(native.DISP || native.DISP_INT)$fatal(1,"DISABLE_LATCH");
  repeat(3)@(negedge clk);
  if(native.DOT_FST.DC!=24'h101010)$fatal(1,"DISABLED_BACKSCREEN");
  @(negedge clk);blank=1;bus_write(21'h180000,16'h8000,3);
  @(negedge clk);blank=0;repeat(3)@(negedge clk);
  if(!native.DISP_INT)$fatal(1,"BLANK_ENABLE_RETENTION");
  check_layers("enabled_inside_blank_then_active");
  $display("PASS checkpoint probe checks=%0d; actual TVMD bus/latch/sorter, forced raster/dots, no full-frame claim",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"TIMEOUT");end
endmodule
