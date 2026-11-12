module queue_scoreboard;
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
`ifdef MUTANT
fb_bad
`else
queue_dut
`endif
#(.BWC(1),.CTX_BEQ(1)) dut(.ctx_draw_block(addr[16:5]),.ctx_erase_block(addr[16:5]),.ctx_pref0_block(addr[16:5]),.ctx_pref1_block(addr[16:5]),.ctx_draw(1'b1),.ctx_erase(1'b0),.ctx_pref_sel(1'b0),.clk(clk),.rst(rst),.req_valid(rv),.req_we(rwe),.req_addr(addr),.req_len(len),.req_data(data),.req_be(be),.req_tag(tag),
`ifdef A6_DBG
.req_nm(nm),
`endif
.full(b[0]),.empty(b[1]),.cmd_count(b[5:2]),.overflow(b[6]),
`ifdef FRESH_FBRDY
.full_n(b[7]),
`endif
.m_valid(b[8]),.m_ready(mready),.m_we(b[9]),.m_addr(b[26:10]),.m_len(b[31:27]),.m_wd_pop(pop),.m_wd_data(b[47:32]),.m_wd_be(b[49:48]),.m_rd_valid(rdv),.m_rd_data(rddata),.m_rd_last(rdlast),.rsp_valid(b[50]),.rsp_data(b[66:51]),.rsp_tag(b[74:67]),.rsp_last(b[75]));

int checks=0,commands=0,words=0;
task tick;
 #1;
 if(a[8] === 1'b1 && b[8] === 1'b1 && a[31:10] !== b[31:10]) $fatal(1,"FB_OBSERVABLE_COMMAND");
`ifndef MUTANT
 if(a !== b)$fatal(1,"FB_OUTPUT");
`endif
 @(posedge clk);#1;checks++;@(negedge clk);
endtask
task write_req(input logic[16:0] ad,input logic[15:0] dat,input logic[1:0] bytes);
 rv=1;rwe=1;addr=ad;data=dat;be=bytes;tick();rv=0;tick();
endtask
initial begin
 repeat(3)tick();rst=0;repeat(260)tick();
 write_req(17'h1,16'habcd,3);write_req(17'h1,16'h12ef,1);
 write_req(17'h3,16'h5678,2);write_req(17'h21,16'h9876,3);
 repeat(4)tick();
 for(int c=0;c<2;c++)begin
  int count;
  if(a[8] !== 1'b1)$fatal(1,"MISSING_COMMAND");
  if(a[26:10] !== (c==0 ? 17'h1:17'h21) || a[31:27] !== (c==0 ? 5'd2:5'd0))$fatal(1,"INDEPENDENT_COMMAND_SCOREBOARD");
  count=int'(a[31:27])+1;commands++;mready=1;tick();mready=0;tick();
  for(int w=0;w<count;w++)begin
   logic[1:0] eb;logic[15:0] ed;
   if(c==1)begin eb=3;ed=16'h9876;end
   else case(w)0:begin eb=3;ed=16'habef;end 1:begin eb=0;ed=0;end 2:begin eb=2;ed=16'h5600;end endcase
   if(a[49:48] !== eb || (eb[0] && a[39:32] !== ed[7:0]) || (eb[1] && a[47:40] !== ed[15:8]))$fatal(1,"INDEPENDENT_BYTE_SCOREBOARD");
   pop=1;tick();pop=0;tick();words++;
  end
 end
 repeat(4)tick();if(a[1] !== 1'b1 || a[6] !== 1'b0)$fatal(1,"DRAIN_OR_OVERFLOW");
 $display("PASS_FB_DIRECTED checks=%0d commands=%0d words=%0d merge_byte_overwrite_hole_blocksplit",checks,commands,words);$finish;
end
endmodule
