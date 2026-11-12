/* Host integration fixture for the unmodified CDB controller/main loop.
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
unsigned src_read(int32_t lba, unsigned pf) { (void)lba; return pf & 255; }
bool src_pending(void) { return false; }
void src_cancel(void) { }
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
 printf("scenario=%d initial=%u elapsed=%u pickup_wait=%u phase=%d counter=%d deadline=%u expected=%u active=%d failures=%d\n", scenario, start_tick, elapsed_first, sampled-now_tick, DrivePhase, DriveCounter, smpc_cd_deadline, expected, smpc_cd_deadline_on, failures);
 longjmp(completed, 1);
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
