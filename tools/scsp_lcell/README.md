# SCSP capture lcell regression

This public-source regression compares the exact two-stage lcell SDRAM1 change (`79904fcc…`) against upstream commit `77fae10e6da2f444bfbafc0551fdedcb77911c37`. It runs the actual controller with Questa, 400,000 cycles across two seeds, all exposed outputs and internal capture/pipeline lockstep, all16 captured data bits exercised as0/1/X/Z, and two compiled semantic controls. It does not run Quartus, load firmware, or establish physical hold/setup, board/audio or gameplay correctness.

Requirements: Python3.10+, Git, an available licensed Questa installation (`vlog`, `vlib`, `vmap`, `vsim`). The checkout must contain the upstream commit's Git objects; a shallow checkout may need that commit fetched. No network access occurs in the test. The checked-out `src/fpga/rtl/sdram1.sv` must be the exact candidate, and its QSF must define `FRESH_SDRAM1_DIN=1` and `SDRAM1_RFC_SPACE=1`. Other assignments are parsed with full-line syntax and unique names.

From the repository root:

```sh
python3 tools/scsp_lcell/test_scsp_lcell.py --out /tmp/scsp-lcell-run
```

Or specify `--repo /path/to/checkout` and optional `--questa-bin /path/to/questa/bin`. The output directory must not exist. Tools have bounded180-second command timeouts; Git reads have30-second timeouts. Python `-O` is rejected. Full logs, input snapshots, command records and final `result.json` remain in the output directory.

Acceptance requires both exit0 and final receipt `status: PASS`; a printed PASS line alone is insufficient. Finalization rechecks live/reference/snapshot/generated/log/artifact bytes after artifact collection and after flushed PASS output. Stdout failure or a mutation triggered during printing changes the receipt to FAIL and raises an error.

Run the separate mocked integrity controls with:

```sh
python3 tools/scsp_lcell/test_integrity.py --repo . --out /tmp/scsp-lcell-integrity
```

These exercise real Git/source/snapshot/finalization code while replacing simulator execution. Their PASS is a provenance/error-handling result, not an RTL simulation result.

The source transformation is inverted byte-for-byte against upstream. Test-only adapters name the existing sequential block for observation, make static declaration lifetime explicit, and express the bidirectional SDRAM output through an equivalent internal driver; each adapter inverse is asserted. The local lcell model is a separately authored continuous identity assignment, matching Intel's installed `altera_mf.v` lcell definition, with exact X/Z identity and no added state or latency. No vendor simulation source is copied or required. The existing minimal altddio model supports bounded controller lockstep, not pad/board timing.

Positive seeds1/764089157 each exercise200,000 cycles and four restarts. Required coverage includes reads/writes, accepted transactions and unknown captured values on every data bit. The first negative substitutes capture bit9 for bit8 and must fail `CAPTURE_MISMATCH cycle=265`. The second independently inverts capture bit8 and disables internal comparisons; it must fail the real exposed-output oracle `OBSERVABLE_MISMATCH cycle=270`. Each mutant must compile successfully and fail the specified semantic diagnostic; compiler errors/timeouts do not qualify as negatives.

No arbitrary queue capacity assumptions, capture-enable changes, clock changes or state latency changes are accepted by this package. Physical retention of lcell buffers requires separate synthesis/STA qualification and appropriate Intel project settings; these tests make no physical claim.
