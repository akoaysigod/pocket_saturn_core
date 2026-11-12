module native_tb;
logic  clk_sys='0;
logic  clk_ram='0;
logic  rst='0;
logic  FB_SEL='0;
logic [17:1] FBD_A='0;
logic [15:0] FBD_D='0;
logic [1:0] FBD_WE='0;
logic  FBD_RD='0;
wire [15:0] r_FBD_Q,d_FBD_Q;
wire  r_FB_RDY,d_FB_RDY;
logic [17:1] FBV_A='0;
wire [15:0] r_FBV_Q,d_FBV_Q;
logic  FBE_WE='0;
logic [15:0] FBE_D='0;
logic  FBV_VB='0;
wire [16:0] r_sram_a,d_sram_a;
wire [15:0] r_sram_dq_out,d_sram_dq_out;
wire  r_sram_dq_oe,d_sram_dq_oe;
logic [15:0] sram_dq_in='0;
wire  r_sram_oe_n,d_sram_oe_n;
wire  r_sram_we_n,d_sram_we_n;
wire  r_sram_ub_n,d_sram_ub_n;
wire  r_sram_lb_n,d_sram_lb_n;
wire [21:16] r_cram1_a,d_cram1_a;
wire [15:0] r_cram1_dq_out,d_cram1_dq_out;
wire  r_cram1_dq_oe,d_cram1_dq_oe;
logic [15:0] cram1_dq_in='0;
wire  r_cram1_clk,d_cram1_clk;
wire  r_cram1_adv_n,d_cram1_adv_n;
wire  r_cram1_cre,d_cram1_cre;
wire  r_cram1_ce0_n,d_cram1_ce0_n;
wire  r_cram1_ce1_n,d_cram1_ce1_n;
wire  r_cram1_oe_n,d_cram1_oe_n;
wire  r_cram1_we_n,d_cram1_we_n;
wire  r_cram1_ub_n,d_cram1_ub_n;
wire  r_cram1_lb_n,d_cram1_lb_n;
logic  cram1_wait='0;
wire  r_ready,d_ready;
wire  r_cfg,d_cfg;
wire  r_overflow,d_overflow;
logic [1:0] dbg_layout='0;
logic  dbg_wcoff='0;
logic  dbg_gap2='0;
logic  dbg_clr='0;
logic  dbg_crst='0;
logic  dbg_ext='0;
wire [7:0] r_dbg_flags,d_dbg_flags;
wire  r_dbg_disp,d_dbg_disp;
wire  r_idle,d_idle;
producer_ref
#(.PS_INIT(4),.PS_BWC(1)) reference(.clk_sys(clk_sys),.clk_ram(clk_ram),.rst(rst),.FB_SEL(FB_SEL),.FBD_A(FBD_A),.FBD_D(FBD_D),.FBD_WE(FBD_WE),.FBD_RD(FBD_RD),.FBD_Q(r_FBD_Q),.FB_RDY(r_FB_RDY),.FBV_A(FBV_A),.FBV_Q(r_FBV_Q),.FBE_WE(FBE_WE),.FBE_D(FBE_D),.FBV_VB(FBV_VB),.sram_a(r_sram_a),.sram_dq_out(r_sram_dq_out),.sram_dq_oe(r_sram_dq_oe),.sram_dq_in(sram_dq_in),.sram_oe_n(r_sram_oe_n),.sram_we_n(r_sram_we_n),.sram_ub_n(r_sram_ub_n),.sram_lb_n(r_sram_lb_n),.cram1_a(r_cram1_a),.cram1_dq_out(r_cram1_dq_out),.cram1_dq_oe(r_cram1_dq_oe),.cram1_dq_in(cram1_dq_in),.cram1_clk(r_cram1_clk),.cram1_adv_n(r_cram1_adv_n),.cram1_cre(r_cram1_cre),.cram1_ce0_n(r_cram1_ce0_n),.cram1_ce1_n(r_cram1_ce1_n),.cram1_oe_n(r_cram1_oe_n),.cram1_we_n(r_cram1_we_n),.cram1_ub_n(r_cram1_ub_n),.cram1_lb_n(r_cram1_lb_n),.cram1_wait(cram1_wait),.ready(r_ready),.cfg(r_cfg),.overflow(r_overflow),.dbg_layout(dbg_layout),.dbg_wcoff(dbg_wcoff),.dbg_gap2(dbg_gap2),.dbg_clr(dbg_clr),.dbg_crst(dbg_crst),.dbg_ext(dbg_ext),.dbg_flags(r_dbg_flags),.dbg_disp(r_dbg_disp),.idle(r_idle));
`ifdef WRONG_BLOCK
producer_bad
`elsif WRONG_TERNARY
producer_tern
`else
producer_dut
`endif
#(.PS_INIT(4),.PS_BWC(1)) dut(.clk_sys(clk_sys),.clk_ram(clk_ram),.rst(rst),.FB_SEL(FB_SEL),.FBD_A(FBD_A),.FBD_D(FBD_D),.FBD_WE(FBD_WE),.FBD_RD(FBD_RD),.FBD_Q(d_FBD_Q),.FB_RDY(d_FB_RDY),.FBV_A(FBV_A),.FBV_Q(d_FBV_Q),.FBE_WE(FBE_WE),.FBE_D(FBE_D),.FBV_VB(FBV_VB),.sram_a(d_sram_a),.sram_dq_out(d_sram_dq_out),.sram_dq_oe(d_sram_dq_oe),.sram_dq_in(sram_dq_in),.sram_oe_n(d_sram_oe_n),.sram_we_n(d_sram_we_n),.sram_ub_n(d_sram_ub_n),.sram_lb_n(d_sram_lb_n),.cram1_a(d_cram1_a),.cram1_dq_out(d_cram1_dq_out),.cram1_dq_oe(d_cram1_dq_oe),.cram1_dq_in(cram1_dq_in),.cram1_clk(d_cram1_clk),.cram1_adv_n(d_cram1_adv_n),.cram1_cre(d_cram1_cre),.cram1_ce0_n(d_cram1_ce0_n),.cram1_ce1_n(d_cram1_ce1_n),.cram1_oe_n(d_cram1_oe_n),.cram1_we_n(d_cram1_we_n),.cram1_ub_n(d_cram1_ub_n),.cram1_lb_n(d_cram1_lb_n),.cram1_wait(cram1_wait),.ready(d_ready),.cfg(d_cfg),.overflow(d_overflow),.dbg_layout(dbg_layout),.dbg_wcoff(dbg_wcoff),.dbg_gap2(dbg_gap2),.dbg_clr(dbg_clr),.dbg_crst(dbg_crst),.dbg_ext(dbg_ext),.dbg_flags(d_dbg_flags),.dbg_disp(d_dbg_disp),.idle(d_idle));

always #5 clk_ram=~clk_ram;
always #10 clk_sys=~clk_sys;
int cycles=0,checks=0,accepted=0,pops=0,reads=0,merges=0,stales=0;
int seed=1;
task tick;
 @(negedge clk_ram);#1;checks++;
 `ifndef WRONG_BLOCK
if ({r_FBD_Q,r_FB_RDY,r_FBV_Q,r_sram_a,r_sram_dq_out,r_sram_dq_oe,r_sram_oe_n,r_sram_we_n,r_sram_ub_n,r_sram_lb_n,r_cram1_a,r_cram1_dq_out,r_cram1_dq_oe,r_cram1_clk,r_cram1_adv_n,r_cram1_cre,r_cram1_ce0_n,r_cram1_ce1_n,r_cram1_oe_n,r_cram1_we_n,r_cram1_ub_n,r_cram1_lb_n,r_ready,r_cfg,r_overflow,r_dbg_flags,r_dbg_disp,r_idle} !== {d_FBD_Q,d_FB_RDY,d_FBV_Q,d_sram_a,d_sram_dq_out,d_sram_dq_oe,d_sram_oe_n,d_sram_we_n,d_sram_ub_n,d_sram_lb_n,d_cram1_a,d_cram1_dq_out,d_cram1_dq_oe,d_cram1_clk,d_cram1_adv_n,d_cram1_cre,d_cram1_ce0_n,d_cram1_ce1_n,d_cram1_oe_n,d_cram1_we_n,d_cram1_ub_n,d_cram1_lb_n,d_ready,d_cfg,d_overflow,d_dbg_flags,d_dbg_disp,d_idle}) $fatal(1,"FB_CONTEXT_OUTPUT");
`endif
if(reference.m_valid[0] === 1'b1 && dut.m_valid[0] === 1'b1 && reference.m_addr[0] !== dut.m_addr[0]) $fatal(1,"FB_CONTEXT_ADDRESS queue=0");
`ifndef WRONG_BLOCK
if ({reference.q[0].queue.g_bwc.beq,reference.q[0].queue.g_bwc.beq_stale,reference.q[0].queue.g_bwc.hit,reference.q[0].queue.g_bwc.ccnt,reference.q[0].queue.rbe,reference.q[0].queue.rv,reference.m_ready[0]} !== {dut.q[0].queue.g_bwc.beq,dut.q[0].queue.g_bwc.beq_stale,dut.q[0].queue.g_bwc.hit,dut.q[0].queue.g_bwc.ccnt,dut.q[0].queue.rbe,dut.q[0].queue.rv,dut.m_ready[0]}) $fatal(1,"FB_CONTEXT_STATE queue=0");
`endif
if(reference.m_valid[1] === 1'b1 && dut.m_valid[1] === 1'b1 && reference.m_addr[1] !== dut.m_addr[1]) $fatal(1,"FB_CONTEXT_ADDRESS queue=1");
`ifndef WRONG_BLOCK
if ({reference.q[1].queue.g_bwc.beq,reference.q[1].queue.g_bwc.beq_stale,reference.q[1].queue.g_bwc.hit,reference.q[1].queue.g_bwc.ccnt,reference.q[1].queue.rbe,reference.q[1].queue.rv,reference.m_ready[1]} !== {dut.q[1].queue.g_bwc.beq,dut.q[1].queue.g_bwc.beq_stale,dut.q[1].queue.g_bwc.hit,dut.q[1].queue.g_bwc.ccnt,dut.q[1].queue.rbe,dut.q[1].queue.rv,dut.m_ready[1]}) $fatal(1,"FB_CONTEXT_STATE queue=1");
`endif

 cycles++;
 if(reference.q[0].queue.g_bwc.merge === 1'b1 || reference.q[1].queue.g_bwc.merge === 1'b1)merges++;
 if(reference.q[0].queue.g_bwc.beq_stale === 1'b1 || reference.q[1].queue.g_bwc.beq_stale === 1'b1)stales++;
 if(reference.p_valid && reference.p_ready && !reference.clr_on)accepted++;
 if(reference.p_pop && !reference.clr_on)pops++;
 if(reference.p_rv)reads++;
endtask
initial begin
 if($value$plusargs("seed=%d",seed))begin end seed=$urandom(seed);
 rst=1;FBV_VB=1;cram1_wait=0;
 repeat(5)tick();rst=0;
 while(r_ready !== 1'b1 && cycles<1500000)tick();
 if(r_ready !== 1'b1)$fatal(1,"BOOT_TIMEOUT");
 repeat(300)tick();
 // Actual draw-source traffic, respecting producer edge detection and input hold.
 for(int n=0;n<1000;n++)begin
  FBD_WE=0;FBE_WE=0;FBD_RD=0;tick();
  if(r_FB_RDY === 1'b1)begin
   FBD_A=17'(((n/4)%16)*32+(n%4)+1);FBD_D=16'(n*73);FBD_WE=2'((n%3)+1);
   tick();FBD_WE=0;repeat(3)tick();
  end else repeat(4)tick();
 end
 // Read/prefetch/erase and display selection transitions through real source logic.
 for(int n=0;n<12000;n++)begin
  FBD_WE=0;FBE_WE=0;FBD_RD=0;
  if(n%800==0)FB_SEL=~FB_SEL;
  FBV_VB=(n%1000)<50;FBV_A=17'(((n/400)%8)*512);
  if(n%64==0 && r_FB_RDY === 1'b1)begin FBD_A=17'($urandom%256);FBD_D=$urandom;FBD_WE=2'(($urandom%3)+1);end
  if(n%96==48 && r_FB_RDY === 1'b1)begin FBD_A=17'($urandom%256);FBD_RD=1;end
  if(n%64==32)begin FBE_WE=1;FBE_D=16'h1234;end
  cram1_wait=(n%257<7);cram1_dq_in=16'(n*17);tick();
 end
 FBD_WE=0;FBE_WE=0;FBD_RD=0;FBV_VB=1;repeat(4000)tick();
`ifndef WRONG_BLOCK
 if(r_overflow !== 1'b0)$fatal(1,"OVERFLOW");
 $display("COVER_CONTEXT commands=%0d pops=%0d reads=%0d merges=%0d stales=%0d",accepted,pops,reads,merges,stales);
 if(accepted<20 || pops<20 || reads<20 || merges<10 || stales<20)$fatal(1,"INSUFFICIENT_CONTEXT_COVERAGE");
`endif
 $display("PASS_CONTEXT checks=%0d commands=%0d pops=%0d reads=%0d merges=%0d stales=%0d",checks,accepted,pops,reads,merges,stales);$finish;
end
endmodule
