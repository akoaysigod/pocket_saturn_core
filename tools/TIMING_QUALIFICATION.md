# Saturn timing and correctness integration

This change combines the blank-latched VDP2 layer-admission fix, producer-context framebuffer comparisons, the equivalent WRQ merge-address rewrite, the six-sector CD-ring memory layout, and explicit SCSP-to-SDRAM hold buffers. It is based on the cumulative deadline/counter firmware in PRs #18 and #21. The VDP2 simulation-reset repair is shared with PR #20; the ring regression is shared with PR #19.

The SCSP capture retains its existing clock, enable and latency. Two Intel `lcell` identity primitives per data bit prevent the failing direct-register route; the additional SDC requires 0.600 ns minimum data delay on all 16 SCSP capture bits and all 32 SDRAM-to-VDP2 read bits, including physical duplicates. The existing clock constraints are retained. Source-level identity alone is insufficient: inspect the routed paths to confirm both stages remain.

## Recorded matched full build

Quartus Standard 25.1std.0 Build 1129, Cyclone V 5CEBA4F23C8, seed 10, eight processors. The QSF includes the tested Standard-edition metadata and eight-processor setting as well as the supplemental SDC. These recipe fields differ from the Git upstream QSF; the source ledger was compared with the matched, identically prepared upstream build.

| Metric | Matched upstream | This integration | Change |
|---|---:|---:|---:|
| Placed ALMs | 18033 | 18000 | -33 |
| Needed ALMs | 17497 | 17532 | +35 |
| Occupied LABs | 1847 | 1844 | -3 |
| M10K blocks | 283 | 281 | -2 |
| DSP blocks | 47 | 47 | 0 |
| Registers | 21256 | 21190 | -66 |
| Worst original setup slack, ns | +0.096 | +0.203 | +0.107 |
| Worst original hold slack, ns | +0.106 | +0.052 | -0.054 |

The modest placed-resource savings are a combined result, not an isolated cost claim for each edit. Needed ALMs increase and the hold margin decreases relative to upstream; no faster clock, FPS or gameplay improvement is claimed. Ring capacity remains six sectors. The predeclared mixed-resource budget and all original timing guards pass.

| Original timing corner | Setup ns | Hold ns | Supplemental A hold ns | Supplemental B hold ns |
|---|---:|---:|---:|---:|
| Slow 1100mV 85C | +0.343 | +0.273 | +1.226 | +1.813 |
| Slow 1100mV 0C | +0.203 | +0.262 | +1.110 | +1.759 |
| Fast 1100mV 85C | +2.554 | +0.122 | +0.283 | +0.271 |
| Fast 1100mV 0C | +3.082 | +0.052 | +0.158 | +0.191 |

A is SDRAM dout-to-VDP2; B is SCSP MEM_D-to-SDRAM din2. All 40 physical A sinks and 16 B sinks pass at every corner. Every one of the 64 B paths retains ordered hold0/hold1 combinational stages and the 0.600 ns exception. Recovery, removal and pulse-width minima are +8.250, +1.175 and +0.873 ns. The original setup/hold acceptance guard is +0.050 ns; worst hold has only +0.002 ns headroom over that guard. This is one fixed-recipe build, not a multiseed robustness result.

Full compilation, fit, assembly, original-only STA and supplemental STA completed successfully. Original-only analysis reloads HDL constraints and the original APF/FX68K SDCs, excluding the supplemental SDC, and preserves 100 timing rows, four corners, 80 detailed paths and 12 clock definitions. Compiled firmware banks were checked against the rebuilt image; native CD/SMPC qualification is documented in COUNTER_TEST.md. Separate independent reviews checked raw reports, all 133 build inputs, all 171 firmware artifacts and runtime/source provenance.

## Exact coverage exception and limits

The original strict count-only screen remains rejected: unconstrained input-path counts changed from 37 to 38 in both setup and hold. A separately reviewed new audit passes only after proving the sole addition is `bridge_spiss -> io_bridge_peripheral:ibs|rx_latch_idx.00~DUPLICATE`, on `bridge_spiclk`. The fitter transformation table explicitly maps the existing parent to this copy under Router Logic Cell Insertion and Logic Duplication / Routability optimization. All 37 original input tuples, including the parent, remain. All 79 output tuples, 18 input-port identities, 60 output-port identities, clock health and original constraints remain identical. Relevant APF source is unchanged.

The new audit retains the raw physical count 38 and records derived logical coverage 37 only for this exact proven copy. It does not strip arbitrary duplicate suffixes or discard new logical paths. The exact fitter row, complete input/output tables and unchanged sources/constraints are required; negative controls reject missing proof, new endpoints, removed parents, changed ports/clocks/counts/outputs and source/report mutation. All other frozen timing/resource/firmware/runtime checks remain unchanged. Earlier failures are preserved.

Inherited external I/O lacks complete input/output delay constraints. This is internal timing and local functional qualification, not complete board timing or a new Pocket, disc, audio, PAL-game or gameplay result. Dual-clock RAM read/write collision behavior remains outside the ring regression's defined scope. The previous single CD-ring warning becomes separate low/high-bank warnings; no collision-safety improvement is claimed.

## Reproduce with your build inputs

First regenerate BOTH Pocket controller firmware banks using the cumulative firmware source and your required MCU/build inputs. The tested image uses SMPC_FW=1, CD_SRC=1, WORDS=22528 and BANK0=20480. For example, with your LLVM and LLD paths:

```sh
LLVM=/path/to/llvm/bin LD_LLD=/path/to/ld.lld SMPC_FW=1 CD_SRC=1 WORDS=22528 BANK0=20480 sh src/fw/cdb/build.sh
```

See COUNTER_TEST.md for firmware costs and functional limits. This PR contains source and tests; generated controller banks, MCU material, complete ELF files and bitstreams are not included. The repository's old prebuilt banks do not deliver the source changes. Regenerate both banks before building and distributing the integrated core.

For the matched Linux Quartus recipe, retain the QSF and SDC bytes and set these OpenMP settings in the build environment:

```sh
export KMP_FORKJOIN_BARRIER_PATTERN=linear,linear
export KMP_PLAIN_BARRIER_PATTERN=linear,linear
export KMP_REDUCTION_BARRIER_PATTERN=linear,linear
export KMP_SETTINGS=1
(cd src/fpga && quartus_sh --flow compile ap_core)
(cd src/fpga && quartus_sta -t ../../tools/timing/audit_original_only.tcl)
(cd src/fpga && quartus_sta -t ../../tools/timing/audit_margin.tcl)
```

The Tcl tools write reports; exit zero alone does not mean timing passed. Inspect every corner: original setup/hold must be at least +0.050 ns; recovery/removal/pulse width must be nonnegative; every supplemental target must have nonnegative hold slack, 0.600 ns relationship and complete physical sink coverage. Recheck both retained stages on every SCSP path, original coverage and any fitter-proven duplicate lineage. Requalify after source, tool, settings or firmware changes. The recorded receipt in timing/qualification_seed10.json contains hashes and measurements without private build paths or payloads.

Portable regressions are included for the exact changes:

```sh
python3 tools/test_cd_ring.py --out /tmp/saturn-ring-001
python3 tools/test_counter.py --source-dir src/fw/cdb --out /tmp/saturn-counter-001
python3 tools/test_vdp2_display.py --out /tmp/saturn-vdp2-001
python3 tools/framebuffer_context/test_framebuffer.py --repo . --output /tmp/saturn-fb-001
python3 tools/wrq/test_wrq.py --repo . --out /tmp/saturn-wrq-001
python3 tools/scsp_lcell/test_scsp_lcell.py --repo . --out /tmp/saturn-scsp-001
```

Each output directory must be fresh. Ring needs Icarus, counter needs Clang/UBSan, VDP2 needs Verilator 5.x, and framebuffer/WRQ/SCSP need licensed Questa on PATH. Read each accompanying README for the precise fixture scope, semantic negative controls and integrity checks. New runner-integrity/admission checks reuse unchanged native compiler-input/command evidence explicitly; they are not additional native runs. The actual new portable SCSP execution covered 400000 controller cycles with all-bit 0/1/X/Z capture and two compiled semantic negatives.
