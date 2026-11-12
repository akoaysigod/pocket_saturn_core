module fourstate_tb;
parameter AW=19, CD=3, DD=5;
logic clk=0; always #5 clk=~clk;
logic rst=1, req_valid=0, m_ready=0, m_wd_pop=0;
logic [AW-1:0] req_addr=0;
logic [15:0] req_data=0;
logic [1:0] req_be=0;
wire rf,re,rv,df,de,dv;
wire [AW-1:0] ra,da;
wire [4:0] rl,dl;
wire [15:0] rd,dd;
wire [1:0] rb,db;
`ifdef FRESH_VBUSY
wire rfn,dfn;
`endif
queue_ref #(.AW(AW),.CD(CD),.DD(DD)) reference(.clk(clk),.rst(rst),.req_valid(req_valid),.req_addr(req_addr),.req_data(req_data),.req_be(req_be),.full(rf),.empty(re),.m_valid(rv),.m_ready(m_ready),.m_addr(ra),.m_len(rl),.m_wd_pop(m_wd_pop),.m_wd_data(rd),.m_wd_be(rb)
`ifdef FRESH_VBUSY
,.full_n(rfn)
`endif
);
`ifdef MUTANT
queue_bad
`else
queue_dut
`endif
#(.AW(AW),.CD(CD),.DD(DD)) dut(.clk(clk),.rst(rst),.req_valid(req_valid),.req_addr(req_addr),.req_data(req_data),.req_be(req_be),.full(df),.empty(de),.m_valid(dv),.m_ready(m_ready),.m_addr(da),.m_len(dl),.m_wd_pop(m_wd_pop),.m_wd_data(dd),.m_wd_be(db)
`ifdef FRESH_VBUSY
,.full_n(dfn)
`endif
);
int seed=1, checks=0, accepted=0, issued=0, consumed=0, remain=0;
int nmerge=0, ntakepush=0, ntakemerge=0, npopmerge=0, nfull=0, nwrap=0, nblock=0, nstall=0, nburst32=0;
int bemask=0, ncommands=0;
logic [AW-1:0] ea[100000];
logic [15:0] ed[100000];
logic [1:0] eb[100000];
int k, lim;
task check;
 checks++;
 if(reference.merge === 1'b1 && (req_addr === reference.o_next) !== 1'b1) $fatal(1,"KNOWN_TRUE_MERGE_PROOF");
 if ({rf,re,rv,ra,rl,rd,rb} !== {df,de,dv,da,dl,dd,db}) $fatal(1,"QUEUE_OUTPUT_MISMATCH check=%0d",checks);
`ifdef FRESH_VBUSY
 if(rfn !== dfn) $fatal(1,"QUEUE_FULL_NEXT_MISMATCH");
`endif
 if ({reference.chead,reference.ctail,reference.ccnt,reference.dhead,reference.dtail,reference.dcnt,reference.open,reference.o_next,reference.lw_v} !==
     {dut.chead,dut.ctail,dut.ccnt,dut.dhead,dut.dtail,dut.dcnt,dut.open,dut.o_next,dut.lw_v})
  $fatal(1,"QUEUE_STATE_MISMATCH check=%0d take=%b req=%b sole_open=%b",checks,reference.take,req_valid,reference.head_is_open);
 if ({reference.merge,reference.push} !== {dut.merge,dut.push})
  $fatal(1,"QUEUE_ACCEPTANCE_MISMATCH check=%0d take=%b req=%b sole_open=%b",checks,reference.take,req_valid,reference.head_is_open);
 for(int j=0;j<(1<<CD);j++) begin
  if(reference.amem[j] !== dut.amem[j]) $fatal(1,"COMMAND_RAM_MISMATCH");
`ifndef FRESH_WRQ_LENRAM
  if(reference.len[j] !== dut.len[j]) $fatal(1,"LENGTH_MISMATCH");
`endif
 end
 for(int j=0;j<(1<<DD);j++) if(reference.dmem[j] !== dut.dmem[j]) $fatal(1,"DATA_RAM_MISMATCH");
`ifdef FRESH_WRQ_LENRAM
 if({reference.o_len,reference.o_lo,reference.head_q} !== {dut.o_len,dut.o_lo,dut.head_q}) $fatal(1,"OPEN_LENGTH_MISMATCH");
`endif
endtask
initial begin
 for(int cycle=0;cycle<5000;cycle++) begin
  @(negedge clk); #1;
  rst=cycle<3 || cycle%101==0;
  req_valid=0;req_addr=0;m_ready=0;m_wd_pop=0;
  if(cycle==3)begin req_valid=1;req_addr=1;end
  if(cycle==4)begin req_valid=1;req_addr=18'b000000000000000x10;end
  if(cycle==5)begin req_valid=1'bx;req_addr=2;end
  if(cycle>5)begin
   req_valid=1'($urandom);m_ready=1'($urandom);m_wd_pop=1'($urandom);
   req_addr=$urandom;req_data=$urandom;req_be=$urandom;
   case(cycle%7)
    0:begin req_addr=reference.o_next;req_valid=1'bx;end
    1:begin req_addr=reference.o_next;req_addr[1]=1'bx;end
    2:m_ready=1'bx;
    3:req_valid=1'bz;
    4:req_addr[0]=1'bz;
    5:m_ready=1'bz;
    default:;
   endcase
  end
  #1;check();
  @(posedge clk);#1;check();
 end
 $display("PASS_FOURSTATE checks=%0d includes unknown contiguous address and unknown req_valid",checks);
 $finish;
end
endmodule
