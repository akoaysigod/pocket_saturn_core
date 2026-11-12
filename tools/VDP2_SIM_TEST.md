# Portable VDP2 simulation-reset regression

The regression files are `tools/test_vdp2_sim_reset.py` and its adjacent
`tools/vdp2_sim_reset/{probe.sv,memory_stub.sv}`. They use Python 3 and Verilator 5.x (tested with 5.052)
with its normal `--binary` C++ build tools. No ROM, firmware, licensed FPGA tool,
external reference RTL or campaign path is required.

From the repository root, run:

```sh
python3 tools/test_vdp2_sim_reset.py --out fresh-results
```

`--source`, `--package` and `--qsf` override the inputs; the default package is
beside the selected source. Without --out, a fresh temporary directory is
created and printed. Existing output directories are rejected. Every quoted VERILOG_MACRO assignment from the QSF is passed identically
to both builds; unsupported assignment syntax and duplicate macro names fail. Source, package,
QSF, runner, fixtures, commands and logs have SHA256 receipts. Input changes,
compile errors, unexpected results and timeouts fail closed. Compile/run limits
are 240/30 seconds per case; no diagnostic suppression beyond -Wno-fatal is added.

The actual VDP2 module receives bus writes for BGON, priority and TVMD registers.
The test checks register values, display-enable latching, disable, enable within
a blank interval and retention afterward. It checks all six enabled layers
individually and equal nonzero-priority tie order in three enabled checkpoints:
21 layer/tie checks plus the bus/latch assertions. It deliberately makes **no
compositor assertion while DISP=1/DISP_INT=0**; a separately justified display
fix can pass without a source-switching oracle. The test records normal
invariants rather than preserving the known before-blank admission behavior.

Scope is explicit: VBLANK, dot enables, incoming sprite/background dots and
backscreen color are forced checkpoints. Palette/FIFO behavior uses a simple
public stub. This is not native raster/frame integration, memory-fetch/palette
qualification, final RGB correctness or gameplay. Zero-priority/mode/timing
combinations are not exhaustively tested.

Mandatory self-control: a unique source mutation keeps DISP_INT set instead of
clearing it on display disable. It must compile successfully, then fail with
DISABLE_LATCH, nonzero exit and no PASS. A compile failure is never accepted as
a successful control. No display-adapted RTL is included in the proposed tools.


Inputs are read once; hashes, compiler inputs, macros and the mutation derive
from those exact byte snapshots. Later input or runner edits fail the test.
This runner targets Verilator; Questa still has pre-existing declaration-order
errors in this module and is not qualified by this repair.
