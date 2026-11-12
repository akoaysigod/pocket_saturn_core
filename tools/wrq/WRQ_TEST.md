# Public WRQ structural regression

Run from any directory with Python 3, Git, and Questa `vlib`, `vlog`, `vsim` on PATH:

```
python3 tools/test_wrq.py --repo /path/to/Saturn --out /path/to/fresh-results
python3 tools/test_wrq_integrity.py --repo /path/to/Saturn --out /path/to/fresh-integrity-results
```

Place the runner, integrity tool and three `wrq_*_tb.sv` fixtures together (the `tools/` name above is illustrative). Output directories must not exist. The checkout must contain local Git commit `77fae10e6da2f444bfbafc0551fdedcb77911c37` and exactly the reviewed WRQ change. No campaign archive, firmware, ROM, external helper script, absolute checkout location, or network access is required. This test rejects other arbiter/PHY changes and permits only the exact QSF alternatives documented below; other integration changes need separate qualification. Python `-O` is rejected before staging or launch.

## Exact source and semantic scope

The checked-out `src/fpga/glue/wr_queue.sv` must differ from the local Git baseline only in the packed command-RAM merge write:

```
{o_len + 5'd1, o_next[AW-1:5], o_lo}
{o_len + 5'd1, req_addr[AW-1:5], o_lo}
```

The first is baseline, second candidate. Whole-file inverse equality is mandatory. Baseline SHA256 is `36b6e33f29879acf0f7013d06b4dfb6e4221396819b6407690bd5b1eb68539f5`; exact candidate is `984aef6f92f0955cf694f9e6d51bd2c280e27a636354930768eae3353fdb213a`. Public arbiter and PHY must match the same Git revision; the QSF may additionally carry only the exact hold-SDC append documented below. All 71 production QSF macros are parsed with malformed/duplicate definitions rejected.

A procedural merge branch runs only when merge is known true. Its logical equality comparison then establishes equality of all request and o_next address bits; unknown equality cannot activate that branch. Keeping the original conditional assignment is essential to its X/Z behavior. Both queue fixtures explicitly check this known-true implication, in addition to reference/candidate comparisons. These simulations supplement that source argument; they are not exhaustive formal proof.

The fixtures derive from the previously exercised functional V2 suite. Defaults now explicitly match RAM-H AW19/CD3/DD5, rather than old AW18/CD2 defaults. Checks cover three random seeds, simultaneous take/push/merge and pop/merge, byte enables, full/backpressure, wrap and block boundaries, data ordering, and drain. CD4/DD6 stress additionally demands a full32-word burst. A 5,000-cycle X/Z case checks acceptance, output and internal state equivalence across unknown addresses/requests/ready values. Native arbiter plus actual public PHY runs three seeds with coverage assertions. A separate no-macro compile/run exercises the legacy queue branch.

Mandatory negative control compiles a queue whose merged upper address is XOR-corrupted. The mutant check task observes only differing addresses while both command-valid outputs are exactly1; it must fail with `WRQ_OBSERVABLE_ADDRESS`, not an internal RAM mismatch, compiler error, timeout or generic simulator error. Other existing fixture safety/scoreboard checks remain; their failure cannot substitute for the required precise diagnostic.

Only declaration ordering is normalized for Questa: the owner's rhc_on localparam and queue next-full wires move ahead of uses. Exact inverses restore original source; module renaming and owner queue-instance renaming instantiate the pair. The functional runner preserves the original fixture check task behind a compile-time observable-only mutant branch, also checked by inverse. No hardware source reset/latency change is introduced by the runner.

## Evidence and integrity

Every run snapshots live public source/fixtures and immutable Git-reference bytes. Generated compile-input digests are recorded from intended bytes before writing, not inferred from compiler-visible files afterward. Inputs are made read-only and checked before commands and in finalization, including failure paths. Each log is read once into raw bytes, hashed, then decoded for semantic acceptance; its same digest remains tracked through finalization. Artifact collection is followed by another live/snapshot/generated/log check. Read failures force a FAIL receipt; a pending receipt precedes terminal PASS output, and post-output verification precedes the final PASS receipt. Terminal output errors or persistent mutations rewrite it to FAIL. Fresh output and failure receipts prevent stale PASS reuse. Files, commands, tool-version logs, Python version, macros and expected hashes are retained.

The separate integrity tool mocks simulator execution only to inject generated writes, artifact-time generated/snapshot/log drift, generated/log read errors and final PASS-output errors/mutations. Each must return a precise failure and FAIL receipt; a mutation during printing may already have emitted the PASS line, which alone does not qualify a run. Its PASS is not simulation coverage.

This is functional regression only. It supplies no full-core PPA, clock-crossing timing, synthesis acceptance, hardware, firmware, gameplay or private-memory claim. Physical qualification and integration with other RTL edits remain separate.

## Exact QSF admission (v3)

The QSF may be one of exactly three byte recipes: (1) the Git77 baseline; (2) Git77 followed by `\nset_global_assignment -name SDC_FILE pocket_hold_margin.sdc\n`; (3) Git77 with its one LAST_QUARTUS_VERSION value changed from `25.1std.0 Lite Edition` to `25.1std.0 Standard Edition`, then `\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 8\n`, then the exact SDC append. Recipe3 must have SHA256 `a19c6fd3233f146ab8ef5d5c5046e143dc0f11f4d5df3f5871424997043c199b`, the frozen tested full-build QSF. Recipes2 and3 require `src/fpga/pocket_hold_margin.sdc` to have SHA256 `06abbc75b6843127901e3c007487502c7ef813284bf1ed00a281ef6bc162312b`; its bytes are captured, snapshotted, and checked through existing terminal closure. No other QSF or owner/PHY source changes are admitted. All71 macros remain identical to baseline.

The SDC is not compiled or interpreted by the simulator. This allowance makes the regression runnable with the exact tested integration constraint file; it does not establish physical qualification, hold timing, or resource acceptance. Actual native WRQ evidence is inherited from v1 with identical compiler inputs and commands. V3 admission/rejection/replay controls mock simulator execution and must not be counted as another RTL run.

V2 writes VERIFIED_PENDING_OUTPUT before final output, then revalidates tracked live/generated/snapshot/log/artifact bytes after printing and before terminal PASS. Stdout failure or persistent mutation during printing yields FAIL and nonzero exit. Acceptance requires both exit0 and a final PASS receipt; printed PASS alone is insufficient.
