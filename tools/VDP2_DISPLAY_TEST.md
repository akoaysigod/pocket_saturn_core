# VDP2 display-admission regression

Copy `tools/test_vdp2_display.py` and `tools/vdp2_display/` into the public repository. Requires Python 3 and Verilator 5.x with its native C++ build tools. Run:

```
python3 tools/test_vdp2_display.py --out /tmp/vdp2-display-new
```

`--source`, `--package`, and `--qsf` override repository defaults. Output must be fresh; omitting it creates a temporary directory. Every selected input and the runner itself are snapshotted as exact bytes before use. Parsing and compilation use those snapshots. Generated expected bytes come directly from the in-memory normalization/control strings, never from rereading staged files. Live inputs, snapshots and generated simulation sources are rechecked around each command and again in finalization before and after artifact hashing. Any mismatch or error overrides the receipt to passed=false and raises; the receipt is authoritative even if a provisional PASS message preceded a finalization error. Receipts retain hashes, complete logs, command lines and timeouts; a compiler failure cannot satisfy a semantic control.

The QSF parser accepts literal `set_global_assignment -name VERILOG_MACRO "NAME[=VALUE]"` lines, forwards every definition, and rejects unsupported syntax or repeated macro names. The tested production QSF has 71 definitions; the tool does not silently choose a smaller macro subset.

The runner supports both a plain upstream display-only change and the same change on PR20's simulation repair. It locally applies only PR20's known simulator repairs inside existing `synopsys translate_off/on` blocks: remove six undeclared CDL reset assignments, initialize all five VA_PIPE entries with a typed struct default, and remove five stale dot resets for continuously driven signals. It records the exact patch, proves all bytes outside excluded blocks identical, and reconstructs the original source exactly by restoring those blocks. This is a limited lexical check, not vendor synthesis equivalence. The selected repository source is never edited. The normalization does not change any display guard. An unpatched upstream source compiles after normalization and then fails the display-admission requirement.

Four positive cases cover PAL/NTSC and LSMD 0/3, 22 checkpoints each, with native raster/blank/field progression, actual TVMD and palette bus writes, enabled/disabled transitions, six layer eligibility paths, priorities/ties, sorter output and RGB checks. Four mandatory controls compile the same normalized input with only the three LV admission guards reverted from DISP_INT to DISP, then must fail precisely `DISPLAY_ADMISSION layer=0 admitted=0`. Every interlace case checks two field edges.

Pixels (SDOT, R0DOT, N0DOT–N3DOT and BACK_DC) are explicitly seeded with force statements. Raster, VBLANK, pixel enables and clocks are not forced. VRAM inputs are zero; the public palette model implements fixture-required memory behavior. This tests admission and compositor behavior, not texture fetching, complete video modes, target oscillator timing, hardware or gameplay. HRES 0 and a 20 ns fixture clock are the tested scope. No firmware, ROM, MIF, vendor license or copied candidate RTL is needed by the public tool.
