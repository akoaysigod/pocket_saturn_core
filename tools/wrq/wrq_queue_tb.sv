module queue_tb;
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
 if($value$plusargs("seed=%d",seed))begin end
 seed=$urandom(seed);
 for(int cycle=0;cycle<52000;cycle++)begin
  @(negedge clk); #1;
  rst=cycle<3 || (cycle>100 && cycle<50000 && cycle%12000<2);
  req_valid=0; m_ready=0; m_wd_pop=0;
  if(!rst) begin
   // Directed sole-open take+contiguous-write: this write MUST become a new command.
   if(cycle==3 || cycle==4 || cycle==7) begin req_valid=1;req_addr=(cycle==3)?1:(cycle==4)?2:3;end
   if(cycle==7) m_ready=1;
   if(cycle>10)begin
    m_wd_pop=remain>0 && ($urandom_range(0,3)!=0);
    m_ready=(remain==0 || (remain==1 && m_wd_pop)) && ($urandom_range(0,3)!=0);
    req_valid=cycle<50000 && !rf && ($urandom_range(0,3)!=0);
    case($urandom_range(0,5))
     0:req_addr=AW'($urandom);
     1:req_addr={reference.o_next[AW-1:5],5'd0};
     default:req_addr=reference.o_next;
    endcase
    // Fill under backpressure, and deliberately build a full aligned 32-word burst
    // when DD permits. The initial word closes the preceding random open command.
    if(cycle>=100 && cycle<140)begin
     m_ready=0; m_wd_pop=0;
     req_valid=!rf && cycle<132;
     req_addr=AW'(cycle-100+64);
    end
   end
   req_data=16'($urandom); req_be=2'(cycle);
  end
  #1; check();
  if(rst)begin accepted=0;issued=0;consumed=0;remain=0;end
  else begin
   if(reference.ccnt>(1<<CD) || reference.dcnt>(1<<DD)) $fatal(1,"TEST_OVERFLOW");
   if(req_valid)begin ea[accepted]=req_addr;ed[accepted]=req_data;eb[accepted]=req_be;accepted++;bemask|=1<<req_be;end
   if(rv && m_ready)begin
    lim=int'(rl)+1;
    if(issued+lim>accepted || ra !== ea[issued]) $fatal(1,"COMMAND_ORDER_OR_LENGTH");
    for(k=0;k<lim;k++)begin
     if(ea[issued+k] !== AW'(ra+k) || ea[issued+k][AW-1:5] !== ra[AW-1:5]) $fatal(1,"BURST_BOUNDARY_OR_ADDRESS");
    end
    issued+=lim;remain+=lim;ncommands++;
    if(lim==32) nburst32++;
   end
   if(m_wd_pop)begin
    if(consumed>=issued || {rb,rd} !== {eb[consumed],ed[consumed]}) $fatal(1,"DATA_ORDER_OR_BYTE_ENABLE");
    consumed++;remain--;
   end
   if(reference.merge)nmerge++;
   if(reference.take && reference.push)ntakepush++;
   if(reference.take && reference.merge)ntakemerge++;
   if(m_wd_pop && reference.merge)npopmerge++;
   if(rf)nfull++;
   if(reference.push && &reference.ctail[CD-1:0])nwrap++;
   if(reference.push && req_addr[4:0]==0)nblock++;
   if(rv && !m_ready)nstall++;
  end
  @(posedge clk); #1; check();
 end
 if(accepted!=consumed || remain!=0 || !re || rv) $fatal(1,"DRAIN_INCOMPLETE");
 if(nmerge<100 || ntakepush<10 || ntakemerge<10 || npopmerge<100 || nfull<10 || nwrap<10 || nblock<10 || nstall<10 || bemask!=15) $fatal(1,"INSUFFICIENT_COVERAGE");
 if(DD>=6 && nburst32==0) $fatal(1,"NO_32_WORD_BURST");
 $display("PASS_QUEUE CD=%0d DD=%0d checks=%0d commands=%0d merge=%0d take_push=%0d take_merge=%0d pop_merge=%0d full=%0d wraps=%0d block=%0d stall=%0d be_mask=%0d burst32=%0d",CD,DD,checks,ncommands,nmerge,ntakepush,ntakemerge,npopmerge,nfull,nwrap,nblock,nstall,bemask,nburst32);
 $finish;
end
endmodule
