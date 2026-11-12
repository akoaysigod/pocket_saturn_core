# Framebuffer producer-context regression

Run with Python3 and Questa `vlog`, `vlib`, `vsim` on PATH:

```
python3 /path/to/test_framebuffer.py --repo /path/to/public-checkout --output /new/output/directory
```

The working directory is irrelevant; output must not exist. No Git, network, firmware, campaign archive or private ROM is used by the runner. Tests require the exact API-corrected framebuffer producer/queue source pair and public PHY/SRAM revision identified by source hashes in the runner. Rejects every macro-marked line outside the supported full-line grammar; extracts all71 macros from the actual checkout `src/fpga/ap_core.qsf`; snapshots all inputs, commands, tool version and relevant runtime environment. License environment values may be present in local receipts; inspect before sharing receipts.

`reference_producer.sv` is public upstream77fae10 vdp1fb_ext. `reference_queue.sv` is its public fb_queue with the preceding four cw_a/cw_d keep attributes (f5501947), the exact semantic parent. These GPL reference fixtures avoid a Git-history/network dependency and do not contain firmware. Original source notices are retained; the accompanying LICENSE is copied from the public repository. All derived fixtures and this regression are distributed under that same GPL license.

The producer and both queues with real public PHY execute reset/framebuffer clear, draw/erase/prefetch traffic, command and byte/read comparisons. Test PHY startup PS_INIT=4 shortens configuration delay; the full16,384-command framebuffer clear still runs. Production PS_INIT is unchanged by the candidate. Native test clocks are10ns/20ns; this is functional evidence, not timing or hardware qualification.

A separate actual-producer arbitrary-state X/Z miter deliberately forces internal captured state/open blocks and checks procedural draw/erase priority and indexed prefetch selection, including unknown index with identical prefetch blocks. It does not assume selectors are known. Old positional parameters/ports with omitted trailing context inputs check the default-disabled API; named enabled interface runs X/Z/ready/byte/stale-state checks. An independent byte scoreboard verifies overwrite lanes, holes and delayed pops.

Mandatory compiled controls corrupt the draw-block comparison (must fail on an emitted queue1 address) and substitute ternary prefetch selection (must fail at the exact unknown-index case). Compile failures/timeouts do not count as successful negative tests. Only simulation forward declarations pa_req/pa_clr are moved, with exact inverse checks; expressions are unchanged. Per-run generated-input hashes are derived before writes; live/snapshot/generated/log bytes are rechecked after execution and after artifact collection, including failure paths. Any read/hash failure is a failed run; A pending-output receipt is saved before PASS output; terminal acceptance requires another live/generated/log/artifact verification after output. A mutation during output fails the receipt and exit even if text has already reached stdout. Print exceptions fail the receipt. Optimized Python is rejected.

This fixture targets one frozen transformation and revision, not arbitrary framebuffer refactors. It does not prove exhaustive native reachability, physical setup/hold, game/media operation or hardware behavior. The native comparisons and separately forced miter have distinct scopes. There is no synthesis or mapping invocation.
