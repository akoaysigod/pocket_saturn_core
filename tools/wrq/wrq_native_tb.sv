module tb;
logic clk=0; always #5 clk=~clk;
int checks=0,commands=0,vcommands=0,newfills=0,chunkupdates=0,invalidations=0,flushes=0,simultaneous=0;
int seed=1;
int boundary=0, contenders=0, masked_writes=0, write_beats=0, read_beats=0, stalled=0;
int directed_cycle=-1;
logic  rst='0;
logic  flush='0;
wire  r_ready,d_ready;
logic [19:2] ramh_addr='0;
wire [31:0] r_ramh_dout,d_ramh_dout;
logic [31:0] ramh_din='0;
logic  ramh_dz='0;
logic  ramh_rd='0;
logic [3:0] ramh_wr='0;
wire  r_ramh_busy,d_ramh_busy;
logic [18:1] cdram_addr='0;
wire [15:0] r_cdram_dout,d_cdram_dout;
logic [15:0] cdram_din='0;
logic  cdram_rd='0;
logic [1:0] cdram_wr='0;
wire  r_cdram_busy,d_cdram_busy;
logic [21:1] raml_addr='0;
wire [15:0] r_raml_dout,d_raml_dout;
logic [15:0] raml_din='0;
logic  raml_rd='0;
logic [1:0] raml_wr='0;
wire  r_raml_busy,d_raml_busy;
logic [18:1] vdp1vram_addr='0;
wire [15:0] r_vdp1vram_dout,d_vdp1vram_dout;
logic [15:0] vdp1vram_din='0;
logic  vdp1vram_rd='0;
logic [1:0] vdp1vram_wr='0;
logic [8:0] vdp1vram_blen='0;
wire  r_vdp1vram_busy,d_vdp1vram_busy;
logic [25:1] cart_addr='0;
wire [15:0] r_cart_dout,d_cart_dout;
logic [15:0] cart_din='0;
logic  cart_rd='0;
logic [1:0] cart_wr='0;
wire  r_cart_busy,d_cart_busy;
logic [23:1] bios_addr='0;
logic [15:0] bios_din='0;
logic [1:0] bios_wr='0;
wire  r_bios_busy,d_bios_busy;
logic [20:1] bsram_addr='0;
wire [15:0] r_bsram_dout,d_bsram_dout;
logic [15:0] bsram_din='0;
logic  bsram_rd='0;
logic [1:0] bsram_wr='0;
wire  r_bsram_busy,d_bsram_busy;
wire [21:16] r_p_a,d_p_a;
wire [15:0] r_p_dq_out,d_p_dq_out;
wire  r_p_dq_oe,d_p_dq_oe;
logic [15:0] p_dq_in='0;
wire  r_p_clk,d_p_clk;
wire  r_p_adv_n,d_p_adv_n;
wire  r_p_cre,d_p_cre;
wire  r_p_ce0_n,d_p_ce0_n;
wire  r_p_ce1_n,d_p_ce1_n;
wire  r_p_oe_n,d_p_oe_n;
wire  r_p_we_n,d_p_we_n;
wire  r_p_ub_n,d_p_ub_n;
wire  r_p_lb_n,d_p_lb_n;
wire  r_dbg_wait,d_dbg_wait;
logic  p_wait='0;
owner_ref #(.PS_INIT(4)) reference(.clk(clk),.rst(rst),.flush(flush),.ready(r_ready),.ramh_addr(ramh_addr),.ramh_dout(r_ramh_dout),.ramh_din(ramh_din),.ramh_dz(ramh_dz),.ramh_rd(ramh_rd),.ramh_wr(ramh_wr),.ramh_busy(r_ramh_busy),.cdram_addr(cdram_addr),.cdram_dout(r_cdram_dout),.cdram_din(cdram_din),.cdram_rd(cdram_rd),.cdram_wr(cdram_wr),.cdram_busy(r_cdram_busy),.raml_addr(raml_addr),.raml_dout(r_raml_dout),.raml_din(raml_din),.raml_rd(raml_rd),.raml_wr(raml_wr),.raml_busy(r_raml_busy),.vdp1vram_addr(vdp1vram_addr),.vdp1vram_dout(r_vdp1vram_dout),.vdp1vram_din(vdp1vram_din),.vdp1vram_rd(vdp1vram_rd),.vdp1vram_wr(vdp1vram_wr),.vdp1vram_blen(vdp1vram_blen),.vdp1vram_busy(r_vdp1vram_busy),.cart_addr(cart_addr),.cart_dout(r_cart_dout),.cart_din(cart_din),.cart_rd(cart_rd),.cart_wr(cart_wr),.cart_busy(r_cart_busy),.bios_addr(bios_addr),.bios_din(bios_din),.bios_wr(bios_wr),.bios_busy(r_bios_busy),.bsram_addr(bsram_addr),.bsram_dout(r_bsram_dout),.bsram_din(bsram_din),.bsram_rd(bsram_rd),.bsram_wr(bsram_wr),.bsram_busy(r_bsram_busy),.p_a(r_p_a),.p_dq_out(r_p_dq_out),.p_dq_oe(r_p_dq_oe),.p_dq_in(p_dq_in),.p_clk(r_p_clk),.p_adv_n(r_p_adv_n),.p_cre(r_p_cre),.p_ce0_n(r_p_ce0_n),.p_ce1_n(r_p_ce1_n),.p_oe_n(r_p_oe_n),.p_we_n(r_p_we_n),.p_ub_n(r_p_ub_n),.p_lb_n(r_p_lb_n),.dbg_wait(r_dbg_wait),.p_wait(p_wait));
`ifdef MUTANT
owner_bad #(.PS_INIT(4)) dut(.clk(clk),.rst(rst),.flush(flush),.ready(d_ready),.ramh_addr(ramh_addr),.ramh_dout(d_ramh_dout),.ramh_din(ramh_din),.ramh_dz(ramh_dz),.ramh_rd(ramh_rd),.ramh_wr(ramh_wr),.ramh_busy(d_ramh_busy),.cdram_addr(cdram_addr),.cdram_dout(d_cdram_dout),.cdram_din(cdram_din),.cdram_rd(cdram_rd),.cdram_wr(cdram_wr),.cdram_busy(d_cdram_busy),.raml_addr(raml_addr),.raml_dout(d_raml_dout),.raml_din(raml_din),.raml_rd(raml_rd),.raml_wr(raml_wr),.raml_busy(d_raml_busy),.vdp1vram_addr(vdp1vram_addr),.vdp1vram_dout(d_vdp1vram_dout),.vdp1vram_din(vdp1vram_din),.vdp1vram_rd(vdp1vram_rd),.vdp1vram_wr(vdp1vram_wr),.vdp1vram_blen(vdp1vram_blen),.vdp1vram_busy(d_vdp1vram_busy),.cart_addr(cart_addr),.cart_dout(d_cart_dout),.cart_din(cart_din),.cart_rd(cart_rd),.cart_wr(cart_wr),.cart_busy(d_cart_busy),.bios_addr(bios_addr),.bios_din(bios_din),.bios_wr(bios_wr),.bios_busy(d_bios_busy),.bsram_addr(bsram_addr),.bsram_dout(d_bsram_dout),.bsram_din(bsram_din),.bsram_rd(bsram_rd),.bsram_wr(bsram_wr),.bsram_busy(d_bsram_busy),.p_a(d_p_a),.p_dq_out(d_p_dq_out),.p_dq_oe(d_p_dq_oe),.p_dq_in(p_dq_in),.p_clk(d_p_clk),.p_adv_n(d_p_adv_n),.p_cre(d_p_cre),.p_ce0_n(d_p_ce0_n),.p_ce1_n(d_p_ce1_n),.p_oe_n(d_p_oe_n),.p_we_n(d_p_we_n),.p_ub_n(d_p_ub_n),.p_lb_n(d_p_lb_n),.dbg_wait(d_dbg_wait),.p_wait(p_wait));
`else
owner_dut #(.PS_INIT(4)) dut(.clk(clk),.rst(rst),.flush(flush),.ready(d_ready),.ramh_addr(ramh_addr),.ramh_dout(d_ramh_dout),.ramh_din(ramh_din),.ramh_dz(ramh_dz),.ramh_rd(ramh_rd),.ramh_wr(ramh_wr),.ramh_busy(d_ramh_busy),.cdram_addr(cdram_addr),.cdram_dout(d_cdram_dout),.cdram_din(cdram_din),.cdram_rd(cdram_rd),.cdram_wr(cdram_wr),.cdram_busy(d_cdram_busy),.raml_addr(raml_addr),.raml_dout(d_raml_dout),.raml_din(raml_din),.raml_rd(raml_rd),.raml_wr(raml_wr),.raml_busy(d_raml_busy),.vdp1vram_addr(vdp1vram_addr),.vdp1vram_dout(d_vdp1vram_dout),.vdp1vram_din(vdp1vram_din),.vdp1vram_rd(vdp1vram_rd),.vdp1vram_wr(vdp1vram_wr),.vdp1vram_blen(vdp1vram_blen),.vdp1vram_busy(d_vdp1vram_busy),.cart_addr(cart_addr),.cart_dout(d_cart_dout),.cart_din(cart_din),.cart_rd(cart_rd),.cart_wr(cart_wr),.cart_busy(d_cart_busy),.bios_addr(bios_addr),.bios_din(bios_din),.bios_wr(bios_wr),.bios_busy(d_bios_busy),.bsram_addr(bsram_addr),.bsram_dout(d_bsram_dout),.bsram_din(bsram_din),.bsram_rd(bsram_rd),.bsram_wr(bsram_wr),.bsram_busy(d_bsram_busy),.p_a(d_p_a),.p_dq_out(d_p_dq_out),.p_dq_oe(d_p_dq_oe),.p_dq_in(p_dq_in),.p_clk(d_p_clk),.p_adv_n(d_p_adv_n),.p_cre(d_p_cre),.p_ce0_n(d_p_ce0_n),.p_ce1_n(d_p_ce1_n),.p_oe_n(d_p_oe_n),.p_we_n(d_p_we_n),.p_ub_n(d_p_ub_n),.p_lb_n(d_p_lb_n),.dbg_wait(d_dbg_wait),.p_wait(p_wait));
`endif
task check;
checks++;
if ({r_ready,r_ramh_dout,r_ramh_busy,r_cdram_dout,r_cdram_busy,r_raml_dout,r_raml_busy,r_vdp1vram_dout,r_vdp1vram_busy,r_cart_dout,r_cart_busy,r_bios_busy,r_bsram_dout,r_bsram_busy,r_p_a,r_p_dq_out,r_p_dq_oe,r_p_clk,r_p_adv_n,r_p_cre,r_p_ce0_n,r_p_ce1_n,r_p_oe_n,r_p_we_n,r_p_ub_n,r_p_lb_n,r_dbg_wait} !== {d_ready,d_ramh_dout,d_ramh_busy,d_cdram_dout,d_cdram_busy,d_raml_dout,d_raml_busy,d_vdp1vram_dout,d_vdp1vram_busy,d_cart_dout,d_cart_busy,d_bios_busy,d_bsram_dout,d_bsram_busy,d_p_a,d_p_dq_out,d_p_dq_oe,d_p_clk,d_p_adv_n,d_p_cre,d_p_ce0_n,d_p_ce1_n,d_p_oe_n,d_p_we_n,d_p_ub_n,d_p_lb_n,d_dbg_wait}) $fatal(1,"owner output mismatch check=%0d",checks);
if (reference.cmd_valid !== dut.cmd_valid) $fatal(1,"command valid mismatch");
if (reference.cmd_valid && {reference.sel_we,reference.sel_addr,reference.sel_len} !== {dut.sel_we,dut.sel_addr,dut.sel_len}) $fatal(1,"command mismatch check=%0d",checks);
if ({reference.cmd_ready,reference.acc,reference.wd_pop,reference.rd_valid} !==
    {dut.cmd_ready,dut.acc,dut.wd_pop,dut.rd_valid}) $fatal(1,"handshake mismatch check=%0d",checks);
if (reference.wd_pop && {reference.wd_data,reference.wd_be} !== {dut.wd_data,dut.wd_be})
    $fatal(1,"write beat mismatch check=%0d",checks);
if (reference.rd_valid && {reference.rd_data,reference.rd_last} !== {dut.rd_data,dut.rd_last})
    $fatal(1,"read beat mismatch check=%0d",checks);
endtask
initial begin if($value$plusargs("seed=%d",seed))begin end seed=$urandom(seed);
for(int cycle=0;cycle<160000;cycle++)begin
@(negedge clk); #1;
rst=cycle<4 || cycle%19001<2; flush=cycle%23003==7;
p_dq_in=$urandom; p_wait=(cycle%257<7);
if (directed_cycle < 0 || cycle < directed_cycle + 512) begin
    vdp1vram_rd=0;
    cdram_rd=0;
    raml_rd=0;
    bios_wr=r_bios_busy ? 2'b01 : 2'b00;
    if (directed_cycle < 0 && r_ready && !rst) begin
        directed_cycle=cycle;
        vdp1vram_addr=18'd13;
        vdp1vram_blen=9'd19;
        vdp1vram_rd=1;
        cdram_addr=18'h1250;
        cdram_rd=1;
        raml_addr=21'h0320;
        raml_rd=1;
        bios_addr=23'h100004;
        bios_din=16'h96c3;
        bios_wr=2'b01;
    end
end else begin
vdp1vram_rd=0; vdp1vram_wr=0;
if(cycle%701==10 || (!r_vdp1vram_busy && cycle%17==0))begin
vdp1vram_addr=$urandom; vdp1vram_blen=9'($urandom);
case((cycle/17)%7) 0:vdp1vram_blen=0;1:vdp1vram_blen=1;2:vdp1vram_blen=32;3:vdp1vram_blen=511;default:;endcase
vdp1vram_rd=1; end
if(cycle%997==8)begin vdp1vram_wr=3; vdp1vram_din=$urandom;invalidations++;end
cdram_rd=cycle%1301==100; if(cdram_rd)cdram_addr=$urandom;
raml_rd=cycle%1709==200; if(raml_rd)raml_addr=$urandom;
cart_rd=cycle%1907==300; if(cart_rd)cart_addr=$urandom;
bsram_rd=cycle%2203==400; if(bsram_rd)bsram_addr=$urandom;
bios_wr=cycle%3001==1000 ? 3 : 0; if(bios_wr)begin bios_addr=$urandom;bios_din=$urandom;end
    if (cycle % 5003 == 1000) begin
        cdram_rd=1;
        raml_rd=1;
        cart_rd=1;
    end
    ramh_rd=(cycle % 2609 == 127) && !r_ramh_busy;
    ramh_wr=(cycle % 4099 == 211 && !r_ramh_busy) ? 4'b0101 : 0;
    if (ramh_rd || ramh_wr != 0) begin
        ramh_addr=18'($urandom);
        ramh_din=$urandom;
    end
end
#1;check();
if(reference.acc)begin commands++;if(reference.sel==7)begin vcommands++;chunkupdates++;end end
if (directed_cycle >= 0 && cycle < directed_cycle + 512) begin
    if (reference.acc && reference.sel==reference.C_V_R && reference.v_ca==18'd13 &&
        reference.v_left==9'd19 && reference.sel_len==5'd18) boundary++;
    if (reference.acc && reference.sel==reference.C_CD_R && reference.g_rr==0 &&
        reference.g_req[0] && reference.g_req[1]) contenders++;
    if (reference.wd_pop && reference.cur==reference.C_BI_W && reference.wd_be==2'b01 &&
        reference.wd_data==16'h96c3) masked_writes++;
end
if (reference.wd_pop) write_beats++;
if (reference.rd_valid) read_beats++;
if (reference.phy.win[reference.phy.RDLAT-1] && reference.phy.rd_on &&
    reference.phy.rle_r && reference.phy.wait_s && reference.phy.USE_WAIT) stalled++;
if(reference.v_nf)newfills++; if(flush)flushes++;if(reference.v_nf && reference.acc)simultaneous++;
@(posedge clk);#1;check();end
if(vcommands<100 || newfills<100 || flushes<1 || chunkupdates<100)$fatal(1,"insufficient owner coverage");
$display("COVER directed_cycle=%0d boundary=%0d contenders=%0d masked=%0d write_beats=%0d read_beats=%0d stalled=%0d",
    directed_cycle,boundary,contenders,masked_writes,write_beats,read_beats,stalled);
if (directed_cycle<0 || boundary!=1 || contenders<1 || masked_writes!=1 ||
    write_beats<1 || read_beats<1 || stalled<1)
    $fatal(1,"missing directed coverage");
$display("PASS native owner checks=%0d commands=%0d vcommands=%0d newfills=%0d invalidations=%0d flushes=%0d simultaneous=%0d",checks,commands,vcommands,newfills,invalidations,flushes,simultaneous);$finish;end endmodule
