module miter_tb;
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
logic sel,drawwe,drawrd,erasewe,pref;logic[11:0] drawblock,eraseblock,p0,p1,b0,b1;
int checks=0,unknown_identical=0;
function automatic logic four(input int n);case(n%4)0:four=0;1:four=1;2:four=1'bx;3:four=1'bz;endcase endfunction
initial begin
force reference.c_sel = sel;
force reference.c_fbd_we = {1'b0,drawwe};
force reference.c_fbd_rd = drawrd;
force reference.c_fbe_we = erasewe;
force reference.we_old = 1'b0;
force reference.rd_old = 1'b0;
force reference.ewe_old = 1'b0;
force reference.c_fbd_a = {drawblock,5'd1};
force reference.c_fbv_a = {eraseblock,5'd2};
force reference.fl_on[0] = 1'b1;
force reference.fl_on[1] = 1'b1;
force reference.rr = pref;
force reference.hl_line[0] = p0[11:4];
force reference.hl_line[1] = p1[11:4];
force reference.fl_blk[0] = p0[3:0];
force reference.fl_blk[1] = p1[3:0];
force reference.q[0].queue.g_bwc.oblk[0] = b0;
force reference.q[0].queue.g_bwc.oblk[1] = b1;
force reference.q[1].queue.g_bwc.oblk[0] = b0;
force reference.q[1].queue.g_bwc.oblk[1] = b1;
force dut.c_sel = sel;
force dut.c_fbd_we = {1'b0,drawwe};
force dut.c_fbd_rd = drawrd;
force dut.c_fbe_we = erasewe;
force dut.we_old = 1'b0;
force dut.rd_old = 1'b0;
force dut.ewe_old = 1'b0;
force dut.c_fbd_a = {drawblock,5'd1};
force dut.c_fbv_a = {eraseblock,5'd2};
force dut.fl_on[0] = 1'b1;
force dut.fl_on[1] = 1'b1;
force dut.rr = pref;
force dut.hl_line[0] = p0[11:4];
force dut.hl_line[1] = p1[11:4];
force dut.fl_blk[0] = p0[3:0];
force dut.fl_blk[1] = p1[3:0];
force dut.q[0].queue.g_bwc.oblk[0] = b0;
force dut.q[0].queue.g_bwc.oblk[1] = b1;
force dut.q[1].queue.g_bwc.oblk[0] = b0;
force dut.q[1].queue.g_bwc.oblk[1] = b1;
for(int pattern=0;pattern<8;pattern++)for(int code=0;code<1024;code++)begin
int n;n=code;sel=four(n);n/=4;drawwe=four(n);n/=4;drawrd=four(n);n/=4;erasewe=four(n);n/=4;pref=four(n);
drawblock=12'h123;eraseblock=12'habc;p0=12'h123;p1=12'habc;b0=12'h123;b1=12'habc;
case(pattern)
1:begin p0=12'h123;p1=12'h123;end
2:begin p0=12'h999;p1=12'h999;end
3:begin drawblock=12'hx;p0=12'hz;end
4:begin eraseblock=12'hz;b0=12'hx;end
5:begin p0=12'hxx1;p1=12'hxx2;b1=12'hxx3;end
6:begin drawblock=0;eraseblock=0;p0=0;p1=0;b0=0;b1=0;end
7:begin drawblock=12'hz;eraseblock=12'hx;p0=12'hz;p1=12'hz;b0=12'hz;b1=12'hz;end
endcase
#1;
if ((reference.q_addr[0][16:5] == reference.q[0].queue.g_bwc.oblk[0]) !== dut.q[0].queue.g_bwc.g_ctx.ctx_equal[0]) $fatal(1,"CONTEXT_MITER queue=0 slot=0 pattern=%0d code=%0d",pattern,code);
if ((reference.q_addr[0][16:5] == reference.q[0].queue.g_bwc.oblk[1]) !== dut.q[0].queue.g_bwc.g_ctx.ctx_equal[1]) $fatal(1,"CONTEXT_MITER queue=0 slot=1 pattern=%0d code=%0d",pattern,code);
if ((reference.q_addr[1][16:5] == reference.q[1].queue.g_bwc.oblk[0]) !== dut.q[1].queue.g_bwc.g_ctx.ctx_equal[0]) $fatal(1,"CONTEXT_MITER queue=1 slot=0 pattern=%0d code=%0d",pattern,code);
if ((reference.q_addr[1][16:5] == reference.q[1].queue.g_bwc.oblk[1]) !== dut.q[1].queue.g_bwc.g_ctx.ctx_equal[1]) $fatal(1,"CONTEXT_MITER queue=1 slot=1 pattern=%0d code=%0d",pattern,code);
checks++;if($isunknown(pref) && p0 === p1)unknown_identical++;
end
if(unknown_identical<1)$fatal(1,"MISSING_UNKNOWN_IDENTICAL");
$display("PASS_CONTEXT_MITER checks=%0d unknown_identical=%0d",checks,unknown_identical);$finish;end
endmodule
