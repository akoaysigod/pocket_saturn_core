`timescale 1ns/1ps
module altddio_out #(
 parameter extend_oe_disable="OFF", intended_device_family="Cyclone V",
 invert_output="OFF", lpm_hint="UNUSED", lpm_type="altddio_out",
 oe_reg="UNREGISTERED", power_up_high="OFF", width=1
)(input [width-1:0] datain_h,datain_l, input outclock,aclr,aset,oe,outclocken,sclr,sset,
 output [width-1:0] dataout);
 assign dataout = oe ? (outclock ? datain_h : datain_l) : 'z;
endmodule

module tb;
 reg clk=0,init=0,sync=0;
 always #4.365 clk=~clk;
 reg [17:1] addr_a0=0,addr_b0=0;
 reg [16:1] addr_a1=0,addr_b1=0;
 reg [63:0] din_a=0,din_b=0;
 reg [7:0] wr_a=0,wr_b=0;
 reg rd_a=0,rd_b=0;
 reg [19:1] ch2addr=0;
 reg [15:0] ch2din=0;
 reg [1:0] ch2wr=0;
 reg ch2rd=0;
 wire [15:0] dq[2];
 wire [12:0] a[2];
 wire [1:0] ba[2],dbg_ctrl_bank[2],dbg_ctrl_cmd[2],dbg_out0_bank[2];
 wire [3:0] dbg_ctrl_we[2];
 wire dqml[2],dqmh[2],cs[2],we[2],ras[2],cas[2],sclk[2],cke[2];
 wire rdy[2],dbg_ctrl_rfs[2],dbg_data0_read[2],dbg_out0_read[2];
 wire [31:0] qa0[2],qa1[2],qb0[2],qb1[2];
 wire [15:0] q2[2],dbg_sdram_d[2];
 reg ext_drive=0;
 reg [15:0] ext_word=0;
 assign dq[0]=ext_drive ? ext_word : 16'hzzzz;
 assign dq[1]=ext_drive ? ext_word : 16'hzzzz;
`define PORTS(N) .clk(clk),.init(init),.sync(sync), \
 .addr_a0(addr_a0),.addr_a1(addr_a1),.din_a(din_a),.wr_a(wr_a),.rd_a(rd_a), \
 .addr_b0(addr_b0),.addr_b1(addr_b1),.din_b(din_b),.wr_b(wr_b),.rd_b(rd_b), \
 .ch2addr(ch2addr),.ch2din(ch2din),.ch2wr(ch2wr),.ch2rd(ch2rd),.ch2rdy(rdy[N]), \
 .dout_a0(qa0[N]),.dout_a1(qa1[N]),.dout_b0(qb0[N]),.dout_b1(qb1[N]),.ch2dout(q2[N]), \
 .SDRAM_DQ(dq[N]),.SDRAM_A(a[N]),.SDRAM_BA(ba[N]),.SDRAM_DQML(dqml[N]),.SDRAM_DQMH(dqmh[N]), \
 .SDRAM_nCS(cs[N]),.SDRAM_nWE(we[N]),.SDRAM_nRAS(ras[N]),.SDRAM_nCAS(cas[N]), \
 .SDRAM_CLK(sclk[N]),.SDRAM_CKE(cke[N]),.dbg_ctrl_bank(dbg_ctrl_bank[N]), \
 .dbg_ctrl_cmd(dbg_ctrl_cmd[N]),.dbg_ctrl_we(dbg_ctrl_we[N]),.dbg_ctrl_rfs(dbg_ctrl_rfs[N]), \
 .dbg_data0_read(dbg_data0_read[N]),.dbg_out0_read(dbg_out0_read[N]), \
 .dbg_out0_bank(dbg_out0_bank[N]),.dbg_sdram_d(dbg_sdram_d[N])
 sdram1_ref refdut(`PORTS(0));
 sdram1 canddut(`PORTS(1));
`undef PORTS
 integer seed=1,cycles=0,accepts=0,writes=0,reads=0,unknown_captures=0,restarts=0;
 reg [31:0] rng=1;
 reg accepted;
 reg [15:0] before_data;
 bit observable_only;
 bit [3:0] seen_data [16];
 task check;
 begin
  if ({dq[0],a[0],ba[0],dqml[0],dqmh[0],cs[0],we[0],ras[0],cas[0],sclk[0],cke[0],
       rdy[0],qa0[0],qa1[0],qb0[0],qb1[0],q2[0],dbg_ctrl_bank[0],dbg_ctrl_cmd[0],
       dbg_ctrl_we[0],dbg_ctrl_rfs[0],dbg_data0_read[0],dbg_out0_read[0],dbg_out0_bank[0],dbg_sdram_d[0]} !==
      {dq[1],a[1],ba[1],dqml[1],dqmh[1],cs[1],we[1],ras[1],cas[1],sclk[1],cke[1],
       rdy[1],qa0[1],qa1[1],qb0[1],qb1[1],q2[1],dbg_ctrl_bank[1],dbg_ctrl_cmd[1],
       dbg_ctrl_we[1],dbg_ctrl_rfs[1],dbg_data0_read[1],dbg_out0_read[1],dbg_out0_bank[1],dbg_sdram_d[1]})
    $fatal(1,"OBSERVABLE_MISMATCH cycle=%0d",cycles);
  if (!observable_only && refdut.din2 !== canddut.din2) $fatal(1,"CAPTURE_MISMATCH cycle=%0d",cycles);
  for(integer j=0;j<6;j=j+1)
   if(!observable_only && refdut.state[j] !== canddut.state[j]) $fatal(1,"PIPELINE_MISMATCH cycle=%0d stage=%0d",cycles,j);
 end endtask
 initial begin
  if($value$plusargs("seed=%d",seed)) begin end
  observable_only=$test$plusargs("observable_only");
  rng=seed;
  for(cycles=0;cycles<200000;cycles=cycles+1) begin
   @(negedge clk);
   rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
   init=(cycles<4)||(cycles%50000<4);
   if(cycles%50000==0) restarts=restarts+1;
   sync=(cycles%16==0);
   addr_a0=rng[16:0];addr_a1=rng[31:16];addr_b0=~rng[16:0];addr_b1=~rng[31:16];
   din_a={rng,~rng};din_b={~rng,rng};
   wr_a=cycles[8:6]==0 ? rng[7:0] : 0;
   wr_b=cycles[8:6]==1 ? rng[15:8] : 0;
   rd_a=cycles[8:6]==2;rd_b=cycles[8:6]==3;
   ch2addr=rng[18:0];ch2din=rng[31:16];
   if(cycles%257<16) ch2din=16'hx5az;
   if(cycles%509<16) ch2din=16'hz3cx;
   if(cycles%257<16)for(integer bitno=0;bitno<16;bitno=bitno+1)begin
    case((cycles/16+bitno)%4)0:ch2din[bitno]=0;1:ch2din[bitno]=1;2:ch2din[bitno]=1'bx;3:ch2din[bitno]=1'bz;endcase
   end
   ch2wr=(cycles%32==1) ? (1+(rng%3)) : 0;
   ch2rd=(cycles%32==17);
   if(cycles%1021==50) ch2wr=2'bxz;
   if(cycles%1031==50) ch2rd=1'bx;
   ext_drive=cycles[7:6]==2;ext_word=rng[15:0];
   #0.001;
   check();
   accepted=refdut.init_done && refdut.st_num[2:0]==7 && !refdut.rd2 && !refdut.wr2 &&
      (refdut.rd2_pend || refdut.wr2_pend) && !refdut.ch2_seq.ch2_lock;
   before_data=ch2din;
   @(posedge clk);#0.001;
   check();
   if(accepted) begin
    accepts=accepts+1;
    for(integer bitno=0;bitno<16;bitno=bitno+1)case(before_data[bitno])
     1'b0:seen_data[bitno][0]=1;1'b1:seen_data[bitno][1]=1;1'bx:seen_data[bitno][2]=1;1'bz:seen_data[bitno][3]=1;endcase
    if($isunknown(before_data)) unknown_captures=unknown_captures+1;
    if(!observable_only && refdut.din2 !== before_data) $fatal(1,"CAPTURE_ORACLE");
   end
   if({ras[0],cas[0],we[0]}===3'b100) writes=writes+1;
   if({ras[0],cas[0],we[0]}===3'b101) reads=reads+1;
  end
  if(accepts<1000 || writes<1000 || reads<1000 || unknown_captures<50 || restarts!=4)
   $fatal(1,"COVERAGE accepts=%0d writes=%0d reads=%0d unknown=%0d restarts=%0d",accepts,writes,reads,unknown_captures,restarts);
  for(integer bitno=0;bitno<16;bitno=bitno+1)if(seen_data[bitno]!==4'b1111)$fatal(1,"MISSING_DATA_FOURSTATE bit=%0d seen=%b",bitno,seen_data[bitno]);
  $display("COVER_ALL16_DATA_01XZ");
  $display("PASS cycles=%0d accepts=%0d writes=%0d reads=%0d unknown=%0d restarts=%0d",cycles,accepts,writes,reads,unknown_captures,restarts);
  $finish;
 end
 initial begin #2000000; $fatal(1,"SIM_TIMEOUT"); end
endmodule
