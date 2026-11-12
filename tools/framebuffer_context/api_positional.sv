module api_positional;
logic clk=0;always #5 clk=~clk;
logic rst=1,rv=0,rwe=0,mready=0,pop=0,rdv=0,rdlast=0,nm=0;
logic [16:0] addr=0;logic[4:0] len=0;logic[15:0] data=0,rddata=0;logic[1:0] be=0;logic[7:0] tag=0;
wire[75:0] a,b;
queue_ref #(.BWC(1)) reference(.clk(clk),.rst(rst),.req_valid(rv),.req_we(rwe),.req_addr(addr),.req_len(len),.req_data(data),.req_be(be),.req_tag(tag),
`ifdef A6_DBG
.req_nm(nm),
`endif
.full(a[0]),.empty(a[1]),.cmd_count(a[5:2]),.overflow(a[6]),
`ifdef FRESH_FBRDY
.full_n(a[7]),
`endif
.m_valid(a[8]),.m_ready(mready),.m_we(a[9]),.m_addr(a[26:10]),.m_len(a[31:27]),.m_wd_pop(pop),.m_wd_data(a[47:32]),.m_wd_be(a[49:48]),.m_rd_valid(rdv),.m_rd_data(rddata),.m_rd_last(rdlast),.rsp_valid(a[50]),.rsp_data(a[66:51]),.rsp_tag(a[74:67]),.rsp_last(a[75]));
queue_dut #(17,8,3,6,0,1) dut(clk,rst,rv,rwe,addr,len,data,be,tag,
`ifdef A6_DBG
nm,
`endif
b[0],b[1],b[5:2],b[6],
`ifdef FRESH_FBRDY
b[7],
`endif
b[8],mready,b[9],b[26:10],b[31:27],pop,b[47:32],b[49:48],rdv,rddata,rdlast,b[50],b[66:51],b[74:67],b[75]);
int checks=0,xready=0,merges=0,takes=0;
task check;
 checks++;
 if({reference.g_bwc.beq,reference.g_bwc.beq_stale} !== {dut.g_bwc.beq,dut.g_bwc.beq_stale})$fatal(1,"BEQ_STALE_MISMATCH");
 if(a!==b)$fatal(1,"FB_OUTPUT");
 if({reference.g_bwc.cw_a,reference.g_bwc.cw_d,reference.g_bwc.hit,reference.g_bwc.ccnt} !== {dut.g_bwc.cw_a,dut.g_bwc.cw_d,dut.g_bwc.hit,dut.g_bwc.ccnt})$fatal(1,"FB_CONE");
 for(int j=0;j<8;j++)if(reference.g_bwc.cmem[j]!==dut.g_bwc.cmem[j])$fatal(1,"FB_CMEM");
 for(int j=0;j<256;j++)if(reference.g_bwc.bmem[j]!==dut.g_bwc.bmem[j])$fatal(1,"FB_BMEM");
endtask
initial begin
 for(int k=0;k<2400;k++)begin
  @(negedge clk);rst=k<3||k%401<3;
  rv= k%401>260 && k%2==0;rwe=1;addr=17'(k%32);data=16'(k*73);be=2'(k);tag=8'(k);
  mready=k%23==0;
  if(k%401>350)begin
   case(k%4)0:mready=0;1:mready=1;2:mready=1'bx;3:mready=1'bz;endcase
   if(k%7==0)addr=17'hx; if(k%13==0)addr=17'hz; if(k%17==0)be=2'bxz;
   if(k%11==0)rv=1'bx;
  end
  #1;check();if(reference.g_bwc.merge===1'b1)merges++;if(reference.g_bwc.take===1'b1)takes++;
  if($isunknown(mready))xready++;
  @(posedge clk);#1;check();
 end
 $display("COVER fb checks=%0d merges=%0d takes=%0d xready=%0d",checks,merges,takes,xready);
 if(!merges||!xready)$fatal(1,"FB_COVERAGE");
 $display("PASS framebuffer attributes");$finish;
end
endmodule
