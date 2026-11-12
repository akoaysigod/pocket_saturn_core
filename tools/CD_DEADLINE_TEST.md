# Portable CD deadline regression

Run from the repository root with Python 3 and a host C compiler:

```sh
python3 tools/test_cd_deadline.py --output /tmp/cd-deadline-results
```

The output directory must not already exist. `--cc clang` selects another compiler; `CC` may also name a compiler executable. `--source /path/to/src/fw/cdb` tests another firmware source directory. There are no ROM/MIF, FPGA, RISC-V toolchain, package, network, or campaign-path dependencies.

The runner compiles the actual local `cdb_hle.c` in full, with its local headers, into the host fixture. It does not duplicate the controller or deadline implementation. Exactly three validated `hw.h` substitutions adapt MMIO/CD RAM; SMPC and disc-source calls are stubbed. The fixture lets the native reset execute, then seeds a legal controller checkpoint. It exercises the actual `cd_main`, `CDB_Run`, drive state transitions, command pickup wait, and deadline publication. These seeded host-C cases are separate from native firmware boot and hardware qualification.

The 60-case matrix combines five scenarios (playing command 00, playing idle, stopped command 00, unresolved source wait, and SEEK-stop cancellation), four timer origins including two near wrap, and elapsed times 0/83/84. Each case enters the native main loop three times with fresh controller reset and shifted timer origin. A further test checks deadline disable at the native restart gate. The timer adapter advances deterministically on reads; tests cover modular wrap and the 84-tick pickup delay, not real CPU timing. The independent invariant is that playing without a reschedule preserves the original due time despite the additional pickup wait.

An exactly validated, reversible substitution changes the deadline anchor from `last` to `now` in a temporary copy. That stale-anchor control must exit 1 with only the named deadline/invariant failures and an observed 84-tick pickup wait. The actual candidate is tested before mutation: running this script against the original stale source fails the first controller case. Compilation errors, timeouts, and unrelated failures do not count as control success. All logs, source hashes, adapter substitutions, mutation hashes, and status are saved to `result.json` and adjacent logs; temporary build sources/binaries are removed.

The fixture uses explicit controller checkpoints. It does not simulate guest software, private SMPC execution, media streaming, gameplay, or optimization efficacy. Signed-counter behavior outside these bounded cases remains untested.

The fixed source passes all 60 cases × 3 entries, restart gating, and the stale-anchor negative control. To check an original source checkout, run:

```sh
python3 tools/test_cd_deadline.py --source /path/to/original/src/fw/cdb --output /tmp/cd-deadline-original
```

The original source intentionally fails: it publishes 9916 instead of 10000 after 84 ticks of pickup wait; the same discrepancy persists through timer wrap. Positive cases require exactly three structured checkpoints with matching scenario, timer origin and elapsed input, zero failures and equal actual/expected deadline. The restart gate requires its explicit successful checkpoint. Each stale-control checkpoint must show the 84-tick discrepancy. Output directories contain execution evidence and are not test inputs. Hardware qualification remains separate.
