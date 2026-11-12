/* Host integration fixture for the repository CDB controller/main loop.
 * Hardware MMIO and the external cooperative SMPC/disc source are adapters.
 * The runner binds the included source and exact adapter substitutions by hash.
 */
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include <string.h>

static volatile uint32_t regs[64], cdmem[0x40000];
static uint32_t flags, start_tick, now_tick, elapsed_first, timer_reads;
static int previous_offset = -1, iteration, scenario, failures;
static bool reset_gate;
static int32_t initial_counter = 10000;
static bool source_pending;
static unsigned source_reads, source_cancels;
static jmp_buf completed;
static volatile uint32_t *test_io(unsigned offset)
{
 if(previous_offset == 0 && regs[0] != flags) flags &= ~regs[0];
 if(offset == 0) regs[0] = flags;
 if(offset == 12) {
  if(timer_reads == 0) regs[3] = start_tick;
  else if(timer_reads == 1) regs[3] = now_tick;
  else regs[3] = now_tick + (timer_reads - 1);
  timer_reads++;
 }
 previous_offset = offset;
 return &regs[offset / 4];
}
#define main firmware_power_on
#define abs firmware_abs
#include "controller.c"
#undef main
#undef abs

bool cd_cmd_idle, cd_running, smpc_cd_deadline_on;
uint32_t smpc_cd_deadline, __cd_bss_start[1], __cd_bss_end[1];
void smpc_init(void) { }
void smpc_poll(void) { if(reset_gate) { if(smpc_cd_deadline_on) failures++; longjmp(completed,1); } }
bool smpc_cd_released(void) { return !reset_gate; }
void src_power_on(void) { }
void src_init(void) { }
void src_poll(void) { }
bool src_toc(TOC *t) { memset(t, 0, sizeof(*t)); return false; }
unsigned src_read(int32_t lba, unsigned pf) { (void)lba; source_reads++; return pf & 255; }
bool src_pending(void) { return source_pending; }
void src_cancel(void) { source_pending=false; source_cancels++; }
void src_hint(int32_t lba) { (void)lba; }
static void check(bool good, const char *what)
{
 if(!good) { fprintf(stderr, "FAIL %s\n", what); failures++; }
}
void smpc_poll_main(void)
{
 if(iteration++ == 0) {
  check(!cd_cmd_idle && DrivePhase == DRIVEPHASE_RESETTING && CommandPhase == -1 && !SecPreBuf_In, "native CDB_Reset(true) checkpoint");
  /* A legal playing/idle checkpoint, then the native coroutine consumes CR. */
  DrivePhase = scenario == 2 ? DRIVEPHASE_STOPPED : DRIVEPHASE_PLAY;
  DriveCounter = initial_counter;
  CommandPhase = 0; CommandClockCounter = 0;
  PeriodicIdleCounter = 1000000;
  CurPosInfo.status = scenario == 2 ? STATUS_STANDBY : STATUS_PLAY;
  if(scenario == 3) DriveCounter = 0; /* unresolved source: inactive deadline */
  if(scenario == 3) { SecPreBuf_In = 1; flags |= F_SEC_BUSY; }
  if(scenario != 1 && scenario != 3) flags |= F_CMD_PEND;
  regs[4] = scenario == 4 ? COMMAND_SEEK << 8 : COMMAND_GET_CDSTATUS << 8;
  previous_offset = -1;
  return;
 }
 const uint32_t sampled = timer_reads > 2 ? now_tick + timer_reads - 2 : now_tick;
 const uint32_t expected = sampled + (uint32_t)DriveCounter;
 check(smpc_cd_deadline == expected, "deadline anchored to last actual CDB_Run sample");
 check(smpc_cd_deadline_on == (DrivePhase == DRIVEPHASE_PLAY && DriveCounter > 0), "native active guard");
 if(scenario == 0 || scenario == 1) {
  check(smpc_cd_deadline_on, "playing deadline active");
  check(smpc_cd_deadline == start_tick + (uint32_t)initial_counter, "drive due invariant");
 }
 if(scenario == 2 || scenario == 3 || scenario == 4) check(!smpc_cd_deadline_on, "cancel/stopped/overdue guard inactive");
 if(scenario == 4) check(DrivePhase == DRIVEPHASE_STOPPED, "real SEEK-stop command cancelled play");
 if(scenario != 1) check(!CmdPickupEat, "real command pickup wait completed");
 printf("scenario=%d initial=%u elapsed=%u pickup_wait=%u phase=%d counter=%lld deadline=%u expected=%u active=%d failures=%d\n", scenario, start_tick, elapsed_first, sampled-now_tick, DrivePhase, (long long)DriveCounter, smpc_cd_deadline, expected, smpc_cd_deadline_on, failures);
 longjmp(completed, 1);
}
static void setup_pending(void)
{
 CDB_Reset(true); SWReset(); CommandPhase=0; CommandClockCounter=0;
 DrivePhase=DRIVEPHASE_PLAY; DriveCounter=1; PeriodicIdleCounter=PeriodicIdleCounter_Reload; CurPosInfo.status=STATUS_PLAY;
 CurPlayStart=0x800000;CurPlayEnd=0;CurPosInfo.tno=1;
 SecPreBuf_In=1;flags=F_DISC_IN|F_DT_WR_IDLE;previous_offset=-1;
 source_pending=true;source_reads=0;source_cancels=0;
 Cur_CDIF=true;toc.first_track=1;toc.last_track=1;
 toc.tracks[1].lba=0;toc.tracks[1].control=4;toc.tracks[1].adr=1;toc.tracks[1].valid=true;
 toc.tracks[100].lba=1000000;toc.tracks[100].control=4;toc.tracks[100].adr=1;toc.tracks[100].valid=true;
 CurSector=150;SubQBuf_Safe[0]=0x40;ScanMode=-1;AuthDiscType=0;
}
static void trace(const char *label)
{
 printf("TRACE %s phase=%d counter=%lld periodic=%d sector=%d reads=%u cancels=%u pending=%d pre=%d free=%d status=%u\n",label,DrivePhase,(long long)DriveCounter,PeriodicIdleCounter,CurSector,source_reads,source_cancels,source_pending,SecPreBuf_In,FreeBufferCount,CurPosInfo.status);
}
static int policy_case(int which)
{
 setup_pending();
 if(which==7) { /* Normal actual-C pending traces, including zero elapsed. */
  for(int i=0;i<10000;i++){Drive_Run(i%997);if(i%1000==0)trace("normal");}
  trace("normal_end");return 0;
 }
 if(which==8 || which==9 || which==10 || which==11 || which==15) {
  int64_t ideal=1,expected=1;
  for(int i=1;i<=(which==15?50000:20000);i++) {
   const int32_t delta=112896; /* 10 ms: crosses debt limit with small per-call deltas. */
   ideal-=delta;expected-=delta;
   CDB_Run(delta);
   if((int64_t)DriveCounter!=expected){fprintf(stderr,"FAIL FULL_DEBT_ORACLE step=%d got=%lld expected=%lld\n",i,(long long)DriveCounter,(long long)expected);return 11;}

   if(DrivePhase!=DRIVEPHASE_PLAY || !SecPreBuf_In || !source_pending)return 13;
  }
  printf("DEBT elapsed_ticks=%lld mathematical=%lld retained=%lld discarded=%lld\n",(long long)(which==15?5644800000LL:2257920000LL),(long long)ideal,(long long)DriveCounter,(long long)(DriveCounter-ideal));
  trace(which==15?"pending_500s":"pending_200s");
  if(which==9 || which==15){source_pending=false;CDB_Run(0);trace("release");if(DriveCounter!=1||source_reads!=(which==15?75000u:30000u)||CurSector!=(which==15?75150:30150))return 14;}
  if(which==10){
   flags|=F_CMD_PEND;regs[4]=COMMAND_SEEK<<8;regs[5]=0;previous_offset=-1;
   CDB_Run(0);CDB_Run(84);trace("guest_stop");
   if(DrivePhase!=DRIVEPHASE_STOPPED||source_pending||SecPreBuf_In||DriveCounter!=380000||source_cancels!=1)return 15;
  }
  if(which==11){CDB_Reset(true);trace("reset");if(!source_pending||SecPreBuf_In||DriveCounter!=0x7fffffff||DrivePhase!=DRIVEPHASE_RESETTING)return 16; ClearPendingSec();trace("explicit_cancel");if(source_pending||source_cancels!=1)return 20;}
  return 0;
 }
 if(which==13){ /* Actual C boundary subtraction with pending source. */
  const int32_t starts[]={INT32_MIN,INT32_MIN+1,-2000000000,-1,0,1,INT32_MAX};
  const int32_t deltas[]={0,1,84,112896,11289600,INT32_MAX};
  for(unsigned a=0;a<7;a++)for(unsigned b=0;b<6;b++){
   setup_pending();DriveCounter=starts[a];int64_t ex=(int64_t)starts[a]-deltas[b];
   Drive_Run(deltas[b]);if(DriveCounter!=ex){fprintf(stderr,"FAIL BOUNDARY a=%u b=%u\n",a,b);return 18;}
  }
  puts("PASS_BOUNDARY actual_Drive_Run=42 positive_or_zero_deltas");return 0;
 }
#ifdef TEST_WIDE
 if(which==14){DriveCounter=-(INT64_C(1)<<40);Drive_Run(0);if(DriveCounter!=-(INT64_C(1)<<40))return 21;Drive_Run(112896);if(DriveCounter!=-(INT64_C(1)<<40)-112896)return 22;trace("wide_checkpoint");return 0;}
#endif
 return 19;
}
int main(int argc, char **argv)
{
 if(argc != 5) return 2;
 scenario = atoi(argv[1]);
 start_tick = (uint32_t)strtoull(argv[2], 0, 0);
 elapsed_first = (uint32_t)strtoul(argv[3], 0, 0);
 initial_counter = (int32_t)strtol(argv[4], 0, 0);
 now_tick = start_tick + elapsed_first;
 flags = F_DISC_IN | F_DT_WR_IDLE;
 if(scenario >= 7) return policy_case(scenario);
 if(scenario == 6) {
  reset_gate=true;smpc_cd_deadline_on=true;
  if(!setjmp(completed))cd_restart();
  printf("native cd_restart reset gate active=%d failures=%d\n",smpc_cd_deadline_on,failures);
  return failures || smpc_cd_deadline_on;
 }
 for(unsigned restart=0;restart<3;restart++) {
  if(restart) start_tick+=0xfffffff0u;
  now_tick=start_tick+elapsed_first; timer_reads=0; iteration=0; previous_offset=-1;
  memset((void*)regs,0,sizeof(regs)); flags=F_DISC_IN | F_DT_WR_IDLE;
  if(!setjmp(completed)) cd_main();
 }
 return failures != 0;
}
