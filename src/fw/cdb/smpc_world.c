// SMPC firmware: the world of the translated MCU program (smpc_mcu_gen.c on the runtime smpc_rt.c), on SMPC_FW.sv.
//
// Time is SMPC_CE edges since RST_N. The hardware counts them (24 bits, extended here) and stamps the last VBLANK
// change and the last COMREG write with their edge, so the program sees its inputs at the edges the real MCU would.
// The program runs behind the present: smpc_poll() lets it run up to the edge the world knows (now); its outputs
// reach the SH-2 side when the poll runs, so they are late by the poll's delay, never early.
#include "hw.h"
#include "smpc.h"
#include "smpc_mcu.h"

#define SIO(w)      IO(0x80 + 4 * (w))
#define S_TIME      SIO(0)       // {EXT_RTC[47:40], CE edges [23:0]}
#define S_EVT       SIO(1)       // {RTC toggle, COMREG writes [1:0], COMREG edge - 1 [13:0], IRQV_N, its edge [13:0]}
#define S_COM2      SIO(5)       // {last COMREG value, the one before's, 0 [15:14], the one before's edge - 1 [13:0]}
#define S_INP(i)    SIO(2 + 4 * (i))   // {IREG[i], EXT_RTC[36:32], D3, R5, PIOB_I, PIOA_I}
#define S_RTC       SIO(3)
#define S_DPIN      SIO(16)      // {CDRES_N, D10..D4, D0}
#define S_PA        SIO(17)      // {direction [14:8], output [6:0]}
#define S_PB        SIO(18)
#define S_SR        SIO(19)
#define S_SFCLR     SIO(20)
#define S_OREG      SIO(21)      // {index [12:8], byte}

static inline int wt_lt(uint32_t a, uint32_t b) { return (int32_t)(a - b) < 0; }
static const uint32_t mcu_brk_zero;      // (smpc_poll_main: MCU_YIELD's break word while no CD command can break a run)

static uint32_t now;             // the inputs are known up to this edge
static uint32_t now24;
static bool changed;             // a VBLANK change or COMREG write seen since the last run
// VBLANK: the last changes (from that edge on, the value), oldest first
enum { NVBL = 4 };
static uint32_t vbl_e[NVBL]; static uint8_t vbl_v[NVBL]; static uint8_t vbl_n;
static uint8_t vbl_seen_v;       // IRQV_N as last taken in
// COMREG writes not taken by the program yet: the edge each is visible from, oldest first
enum { NCOM = 3 };
static uint32_t com_e[NCOM]; static uint8_t com_n, com_cnt;
// COMREG's value by edge (the program reads it after its interrupt, at its own edge, which can be after the host's
// next write in real time): the last NCV writes (edge from which visible, value), oldest first; com_v0 before them
enum { NCV = 4 };
static uint32_t cv_e[NCV]; static uint8_t cv_v[NCV], cv_n, com_v0;
static void com_add(uint32_t ce, uint8_t v)
{
	if (com_n == NCOM) { for (int i = 1; i < NCOM; i++) com_e[i - 1] = com_e[i]; com_n--; }
	com_e[com_n++] = ce;
	if (cv_n == NCV) { com_v0 = cv_v[0]; for (int i = 1; i < NCV; i++) { cv_e[i - 1] = cv_e[i]; cv_v[i - 1] = cv_v[i]; } cv_n--; }
	cv_e[cv_n] = ce; cv_v[cv_n] = v; cv_n++;
}
// IREG0 while the program is stopped in a loop that reads it (w_ireg_watch; INTBACK's continue / break wait): SMPC_FW.sv
// reports no IREG write as an event, so the poll compares IREG0 itself while irw_on (cleared when the program runs)
static uint8_t irw_on, irw_v;
static inline bool irw_changed(void) { return irw_on && (uint8_t)(S_INP(0) >> 24) != irw_v; }
// outputs
static uint16_t d_pins;          // D_O | ~D_D (0xFFFF after RST_N: smpc_init)
static uint8_t r_o[8], r_dcr[8], cdres;
// RTC_INIT (SMPC.sv): the default after RST_N, a copy of EXT_RTC on every toggle of its bit 64; the last toggle state
// survives RST_N (SMPC.sv does not reset it)
static uint8_t rtc_nib[16];
static uint8_t rtc_old __attribute__((section(".noinit")));
bool cd_running;

static uint32_t stamp(uint32_t s14)               // a 14-bit edge stamp, at most 2^14 - 1 edges before now
{
	return now - ((now - s14) & 0x3FFF);
}
static void rtc_capture(void)
{
	uint32_t lo = S_RTC, t = S_TIME, in = S_INP(0);
	uint32_t mon = (in >> 19) & 31;               // EXT_RTC[36:32]
	rtc_nib[1] = lo & 15; rtc_nib[2] = (lo >> 4) & 15;
	rtc_nib[3] = (lo >> 8) & 15; rtc_nib[4] = (lo >> 12) & 15;
	rtc_nib[5] = (lo >> 16) & 15; rtc_nib[6] = (lo >> 20) & 15;
	rtc_nib[7] = (lo >> 24) & 15; rtc_nib[8] = (lo >> 28) & 15;
	rtc_nib[9] = (uint8_t)(((mon & 15) + ((mon & 16) ? 10 : 0)) & 15);
	rtc_nib[10] = 1;
	rtc_nib[11] = (t >> 24) & 15; rtc_nib[12] = (t >> 28) & 15; rtc_nib[13] = 0; rtc_nib[14] = 2;
}
static void rtc_default(void)
{
	static const uint8_t d[16] = { 0, 9, 5, 9, 5, 3, 2, 1, 3, 0xC, 5, 3, 9, 9, 1, 0 };
	for (int i = 1; i < 15; i++) rtc_nib[i] = d[i];
}

// read the events, then the time (an event's edge is then <= now)
static uint32_t last_ev;         // S_EVT as last taken in
static void refresh(void)
{
	uint32_t ev = S_EVT, c2 = 0;
	// new COMREG writes: COM2 as of the same count (a write between the two reads: read both again)
	if (((ev >> 29) & 3) != com_cnt)
		for (;;) { c2 = S_COM2; uint32_t e2 = S_EVT; if (!(((e2 ^ ev) >> 29) & 3)) break; ev = e2; }
	last_ev = ev;
	uint32_t t24 = S_TIME & 0xFFFFFF;
	now += (t24 - now24) & 0xFFFFFF;
	now24 = t24;
	mcu_lim = now;
	// VBLANK: a change flips IRQV_N (the stamp is taken in when the change is first seen: the polls are less than 4 ms
	// apart, and VBLANK changes are 2.5 ms or more apart)
	uint8_t vv = (ev >> 14) & 1;
	if (vv != vbl_seen_v) {
		uint32_t ve = stamp(ev & 0x3FFF);
		vbl_seen_v = vv;
		if (vbl_n == NVBL) { for (int i = 1; i < NVBL; i++) { vbl_e[i - 1] = vbl_e[i]; vbl_v[i - 1] = vbl_v[i]; } vbl_n--; }
		vbl_e[vbl_n] = ve; vbl_v[vbl_n] = vv; vbl_n++;
		changed = true;
		periph_dirty();
	}
	// COMREG: the writes since the last look, each at its own edge (the program's COMREG handshake merges them as
	// SMPC.sv's one-bit COMREG_PEND does). SMPC_FW.sv keeps the last two: of three or more in one look, the older
	// ones are lost (as one of two was with the one-bit toggle this replaces, and both when it flipped back)
	uint8_t cc = (ev >> 29) & 3;
	if (cc != com_cnt) {
		unsigned n = (unsigned)(cc - com_cnt) & 3;
		com_cnt = cc;
		if (n >= 2) com_add(stamp(c2 & 0x3FFF) + 1, (uint8_t)(c2 >> 16));
		com_add(stamp((ev >> 15) & 0x3FFF) + 1, (uint8_t)(c2 >> 24));
		changed = true;
		periph_dirty();
	}
	// IREG0 (the peripherals do not depend on it: no periph_dirty)
	if (irw_changed()) { irw_on = 0; changed = true; }
	// RTC
	uint8_t rt = (uint8_t)(ev >> 31);
	if (rt != rtc_old) { rtc_old = rt; rtc_capture(); }
}

void smpc_init(void)
{
	mcu_brk_p = &mcu_brk_zero;
	P.t0 = 0;
	now = 0; now24 = 0;
	vbl_n = 1; vbl_e[0] = 0; vbl_v[0] = 1; vbl_seen_v = 1;   // SMPC_FW after RST_N: IRQV_N 1 (from edge 0)
	com_n = 0; com_cnt = 0; cv_n = 0; com_v0 = 0;
	irw_on = 0;
	d_pins = 0xFFFF; cdres = 0;
	for (int i = 0; i < 8; i++) { r_o[i] = 0; r_dcr[i] = 0; }
	rtc_default();
	mcu_reset(1);
	refresh();
	changed = false;
}

// One poll: the program runs while it can make progress, up to POLL_BUDGET edges of real time (the CD code's latency):
// in runs of at most RUN_CAP edges of its own time (a long backlog is taken in several polls); when it waits for an edge
// at most SPIN edges ahead (a block of instructions waiting for the present), the poll waits for it.
#ifndef SMPC_POLL_BUDGET
#define SMPC_POLL_BUDGET 400
#endif
enum { POLL_BUDGET = SMPC_POLL_BUDGET, RUN_CAP = MCU_RUN_CAP, SPIN = 100 };
// Around the CD code's deadline (smpc.h; IO_TIMER ticks): no run from CD_GUARD before it until CD_LATE after it (the
// CD code then is busy elsewhere and takes the event late anyway), runs of MCU_RUN_MIN edges only from CD_NEAR before
// it. A run of MCU_RUN_MIN edges takes well under 0.2 ms of CPU, so the CD main loop takes the event on time.
enum { CD_GUARD = 2258, CD_NEAR = 11290, CD_LATE = 1129 };      // 200 us, 1 ms, 100 us
uint32_t smpc_cd_deadline;
bool smpc_cd_deadline_on;
static bool in_poll;
static uint32_t due24;           // the 24-bit edge from which the program can run (if no input event comes first)
static void poll_run(void) __attribute__((noinline));
// the CD code polls often (its main loop, long loops, memset / memcpy): nothing to do unless an input event came
// (S_EVT changed, or IREG0 while watched) or the program's next edge has come (the 24-bit edge count, sign of the
// difference)
void smpc_poll(void)
{
	if (S_EVT == last_ev && (int32_t)((S_TIME - due24) << 8) < 0 && !irw_changed()) return;
	if (in_poll) return;                         // memset / memcpy poll too: not from inside the SMPC code
	poll_run();
}
// the CD main loop's poll (smpc.h): a pending CD command the CD code could answer now (cd_cmd_idle) ends the poll at
// the program's next yield point (mcu_brk: MCU_YIELD looks at CMD_PEND then). Only while the CD code runs.
bool cd_cmd_idle;
volatile const uint32_t* mcu_brk_p;             // (set in smpc_init: no initialised .data in this image)
#ifndef CDFW_NOFIX
static inline bool cd_cmd_waits(void) { return cd_cmd_idle && (IO_FLAGS & F_CMD_PEND); }
#else
static inline bool cd_cmd_waits(void) { return false; }
#endif
void smpc_poll_main(void)
{
	if (cd_cmd_waits()) return;
	if (cd_running && cd_cmd_idle) mcu_brk_p = &IO_FLAGS;
	smpc_poll();
	mcu_brk_p = &mcu_brk_zero;
}
static void poll_run(void)
{
	in_poll = true;
	refresh();
	uint32_t start = now;
	while (!m.halted) {
		uint32_t cap = RUN_CAP;
#ifndef SMPC_NO_CD_GUARD                          // (experiments only: SMPC_DEFS=-DSMPC_NO_CD_GUARD, see REPORT.txt)
		if (cd_running && smpc_cd_deadline_on) {
			int32_t left = (int32_t)(smpc_cd_deadline - IO_TIMER);
			if (left <= CD_GUARD && left >= -CD_LATE) break;
			if (left > CD_GUARD && left <= CD_NEAR) cap = MCU_RUN_MIN;
		}
#endif
		bool go = m.waiting ? (changed || !wt_lt(now, m.wake_at)) : !wt_lt(now, m.wake_at);
		if (!go) {
			if (!m.waiting && (int32_t)(m.wake_at - now) <= SPIN && (int32_t)(now - start) < POLL_BUDGET) { refresh(); continue; }
			break;
		}
		changed = false;
		irw_on = 0;                              // (idle_head watches again if the program stops in the loop again)
		if (wt_lt(m.vt + cap, mcu_lim)) mcu_lim = m.vt + cap;
		mcu_exec();
		refresh();
		if ((int32_t)(now - start) >= POLL_BUDGET) break;
		if (mcu_brk_p != &mcu_brk_zero && cd_cmd_waits()) break;   // (smpc_poll_main: a CD command waits; the run stopped at a yield point)
	}
	// the next poll that has something to do: at the program's wake-up edge (now if it can run; at most 2^22 edges on,
	// for the 24-bit compare), or at an input event
	uint32_t due = now;
	if (m.halted) due = now + (1u << 22);
	else if (!(m.waiting && changed) && wt_lt(now, m.wake_at))
		due = (m.wake_at - now < (1u << 22)) ? m.wake_at : now + (1u << 22);
	due24 = due & 0xFFFFFF;
	in_poll = false;
	if (cd_running && !cdres) {
		// the SMPC holds the CD block in reset: its code starts again from the top (a fresh stack)
		extern void cd_restart_entry(void) __attribute__((noreturn));
		cd_running = false;
		cd_restart_entry();
	}
}

bool smpc_cd_released(void) { return cdres != 0; }

// ---------------------------------------------------------------- the world (smpc_mcu.h)
// what the world knows (the program's own run limit, mcu_lim, may be lower: RUN_CAP; a sleeping or idling program
// finds its next event up to here)
uint32_t w_limit(void) { return now; }
void w_sync(uint32_t t) { while (wt_lt(now, t)) refresh(); }
uint8_t w_vbl_n(uint32_t t)
{
	for (int i = vbl_n - 1; i >= 0; i--) if (!wt_lt(t, vbl_e[i])) return vbl_v[i];
	return vbl_v[0] ^ 1;
}
uint32_t w_vbl_next(uint32_t after)
{
	// the ring holds changes (each entry flips the value), oldest first, all of them known (<= now): the first one
	// after `after` is the next change
	for (int i = 0; i < vbl_n; i++) if (wt_lt(after, vbl_e[i])) return vbl_e[i] ? vbl_e[i] : 1;
	return 0;
}
int w_comreg(uint32_t t)
{
	int any = 0;
	while (com_n && !wt_lt(t, com_e[0])) { com_e[0] = com_e[1]; com_n--; any = 1; }
	return any;
}
// a write is known once it is seen (its edge - 1 <= now): visible from com_e[0], at most now + 1
uint32_t w_comreg_next(void) { return com_n ? com_e[0] : 0; }
uint8_t w_d3(uint32_t t) { (void)t; return (S_INP(0) >> 18) & 1; }
uint8_t w_pio(int port, uint32_t t) { (void)t; uint32_t in = S_INP(0); return (uint8_t)((port ? in >> 7 : in) & 0x7F); }
uint8_t w_area(void) { return (S_INP(0) >> 14) & 15; }
uint8_t w_ireg(int i, uint32_t t)
{
	if ((i & 7) == 7) {                          // COMREG: its value at the edge t (every write up to now is known)
		for (int k = cv_n - 1; k >= 0; k--) if (!wt_lt(t, cv_e[k])) return cv_v[k];
		return com_v0;
	}
	return (uint8_t)(S_INP(i & 7) >> 24);
}
void w_ireg_watch(uint8_t v) { irw_on = 1; irw_v = v; }
uint8_t w_rtc_init(int i) { return rtc_nib[i & 15]; }

static void dpin_out(void) { S_DPIN = ((uint32_t)cdres << 8) | (((d_pins >> 4) & 0x7F) << 1) | (d_pins & 1); }
void w_d_out(uint16_t pins, uint32_t t) { (void)t; d_pins = pins; dpin_out(); }
void w_r_out(int n, uint8_t o, uint8_t dcr, uint32_t t)
{
	(void)t;
	r_o[n & 7] = o; r_dcr[n & 7] = dcr;
	switch (n) {
	case 1: case 2:
		S_PA = ((uint32_t)(((r_dcr[2] >> 1) << 4) | r_dcr[1]) << 8) | (((r_o[2] >> 1) << 4) | r_o[1]);
		break;
	case 3: case 4:
		S_PB = ((uint32_t)(((r_dcr[4] >> 1) << 4) | r_dcr[3]) << 8) | (((r_o[4] >> 1) << 4) | r_o[3]);
		break;
	case 7:
		if (((o >> 2) & 1) != cdres) { cdres = (o >> 2) & 1; dpin_out(); }
		break;
	default: break;
	}
}
void w_oreg(int i, uint8_t v, uint32_t t) { (void)t; S_OREG = ((uint32_t)(i & 31) << 8) | v; }
void w_sr(uint8_t v, uint32_t t) { (void)t; S_SR = v; }
void w_sfclr(uint32_t t) { (void)t; S_SFCLR = 1; }
void w_fail(uint32_t pc) { (void)pc; }
