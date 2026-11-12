`timescale 1ns/1ps
module probe;
 import VDP2_PKG::*;
 bit clk=0;always #10 clk=~clk;
 bit phase=0;always @(negedge clk)phase=~phase;
 wire ce_r=phase;
 bit rst_n=0;
 reg[15:0]di=0;reg cs_n=1,ad_n=1,dten_n=1,req_n=1;
 reg[7:0]screen=0;
 bit pal=0;integer lsmd=0;
 wire[7:0]red,green,blue;wire field_out,interlace_out;
 integer cycles=0,blank_edges=0,field_edges=0;bit old_blank=0,old_field=0;
 integer checks=0;
    VDP2 native(
        .CLK(clk),.RST_N(rst_n),.RES_N(rst_n),.CE_R(phase),.CE_F(!phase),
        .DI(di),.DO(),.CS_N(cs_n),.AD_N(ad_n),.DTEN_N(dten_n),.REQ_N(req_n),.RDY_N(),
        .VINT_N(),.HINT_N(),.DCE_R(),.DCE_F(),.HTIM_N(),.VTIM_N(),.FBDI(16'b0),.FBDO(),
        .PAL(pal),.EXLAT_N(1'b1),.RA0_A(),.RA1_A(),.RA_D(),.RA_WE(),.RA_RD(),
        .RA0_Q(32'b0),.RA1_Q(32'b0),.RB0_A(),.RB1_A(),.RB_D(),.RB_WE(),.RB_RD(),
        .RB0_Q(32'b0),.RB1_Q(32'b0),.R(red),.G(green),.B(blue),.DCLK(),.HS_N(),.VS_N(),.HBL_N(),.VBL_N(),
        .FIELD(field_out),.INTERLACE(interlace_out),.HRES(),.VRES(),.SCRN_EN(screen),.DBG_EXT(8'b0));
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

 always @(posedge clk)if(rst_n)begin
  cycles++;
  if(cycles>15000000)$fatal(1,"NATURAL_RASTER_TIMEOUT");
  if(native.VBLANK!=old_blank)begin blank_edges++;$display("BLANK cycle=%0d value=%0d field=%0d",cycles,native.VBLANK,field_out);end
  if(field_out!=old_field)begin field_edges++;$display("FIELD cycle=%0d value=%0d",cycles,field_out);end
  old_blank=native.VBLANK;old_field=field_out;
 end
 task settle;
  repeat(128)@(negedge clk);
 endtask
 task check_layers(input bit admitted);
  reg[23:0]wanted;reg[7:0]channel;
  for(integer layer=0;layer<6;layer++)begin
   @(negedge clk);screen=8'(1<<(layer==0?5:layer==1?4:layer-2));
   settle();
   wanted=admitted?24'(layer+1):24'h909090;
   if(native.DOT_FST.DC!==wanted)$fatal(1,"DISPLAY_ADMISSION layer=%0d admitted=%0d DISP=%0d INT=%0d got=%h expected=%h",layer,admitted,native.DISP,native.DISP_INT,native.DOT_FST.DC,wanted);
   channel=admitted?8'((layer+1)*8):8'h90;
   if(native.CFST!=={channel,channel,channel})$fatal(1,"PALETTE_PIPE layer=%0d got=%h",layer,native.CFST);
   // Sample final RGB only inside natural horizontal active interval.
   while(native.H_CNT<32 || native.H_CNT>200 || native.HB_INT3)@(negedge clk);
   if({red,green,blue}!=={channel,channel,channel})$fatal(1,"OUTPUT_RGB layer=%0d got=%h expected=%h",layer,{red,green,blue},{channel,channel,channel});
   checks++;
  end
  @(negedge clk);screen=8'h3f;settle();
  if(admitted)begin
   if(native.DOT_FST.DC!=1 || native.DOT_SEC.DC!=2 || native.DOT_THD.DC!=3)$fatal(1,"TIE_ORDER");
  end else if(native.DOT_FST.DC!=24'h909090 || native.DOT_SEC.DC!=24'h909090 || native.DOT_THD.DC!=24'h909090)$fatal(1,"REJECTED_TIE");
  checks++;
 endtask
 task wait_blank(input bit wanted);
  while(native.VBLANK!=wanted)@(negedge clk);
 endtask
 initial begin
  if(!$value$plusargs("PAL=%d",pal))pal=0;
  if(!$value$plusargs("LSMD=%d",lsmd))lsmd=0;
  // Only upstream pixel inputs/backscreen seeded. No raster/dot/clock forces.
  force native.SDOT=34'h200000001;
  force native.R0DOT=28'h2000002;force native.N0DOT=28'h2000003;
  force native.N1DOT=28'h2000004;force native.N2DOT=28'h2000005;force native.N3DOT=28'h2000006;
  force native.BACK_DC=24'h909090;
  repeat(4)@(negedge clk);rst_n=1;
  bus_write(21'h180000,16'(lsmd<<6),3);
  bus_write(21'h180020,16'h001f,3);
  bus_write(21'h1800f0,16'h0003,3);
  bus_write(21'h1800f8,16'h0303,3);
  bus_write(21'h1800fa,16'h0303,3);
  bus_write(21'h1800fc,16'h0003,3);
  for(integer i=1;i<=6;i++)bus_write(21'h100000+21'(i*2),16'(i*16'h421),3);
  if(native.REGS.BGON!=16'h001f || native.REGS.PRINA!=16'h0303 || native.REGS.TVMD.LSMD!=2'(lsmd))$fatal(1,"BUS_SETUP");
  for(integer i=1;i<=6;i++)if(native.pal1.mem[i]!=16'(i*16'h421) || native.pal2.mem[i]!=16'(i*16'h421))$fatal(1,"PALETTE_BUS_WRITE");
  wait_blank(0);
  bus_write(21'h180000,16'h8000|16'(lsmd<<6),3);settle();
  if(!native.DISP || native.DISP_INT || native.VBLANK)$fatal(1,"ACTIVE_ENABLE_PRECONDITION");
  check_layers(0);
  wait_blank(1);settle();if(!native.DISP_INT)$fatal(1,"NATURAL_BLANK_LATCH");
  wait_blank(0);check_layers(1);
  bus_write(21'h180000,16'(lsmd<<6),3);settle();
  if(native.DISP || native.DISP_INT || native.DOT_FST.DC!=24'h909090 || {red,green,blue}!=24'h909090)$fatal(1,"DISABLE_BACKSCREEN");
  wait_blank(1);
  bus_write(21'h180000,16'h8000|16'(lsmd<<6),3);settle();
  if(!native.DISP_INT || !native.VBLANK)$fatal(1,"BLANK_ENABLE_PRECONDITION");
  wait_blank(0);check_layers(1);
  // Zero sprite priority removes it; equal remaining priorities retain RBG,NBG order.
  bus_write(21'h1800f0,16'h0000,3);settle();
  if(native.DOT_FST.DC!=2 || native.DOT_SEC.DC!=3 || native.DOT_THD.DC!=4)$fatal(1,"ZERO_PRIORITY");checks++;
  if(lsmd==3)begin
   while(field_edges<2)@(negedge clk);
   if(!interlace_out)$fatal(1,"INTERLACE_NOT_LATCHED");
   if(!native.DISP_INT)$fatal(1,"FIELD_DISPLAY_RETENTION");
  end else if(interlace_out || field_out)$fatal(1,"NONINTERLACE_FIELD");
  if(blank_edges<4)$fatal(1,"INSUFFICIENT_NATURAL_BOUNDARIES");
  $display("PASS NATURAL_DISPLAY PAL=%0d LSMD=%0d checks=%0d cycles=%0d blank_edges=%0d field_edges=%0d",pal,lsmd,checks,cycles,blank_edges,field_edges);$finish;
 end
endmodule
