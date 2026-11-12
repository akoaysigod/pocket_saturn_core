# CD sector ring regression

Run from the repository root with Python 3 and Icarus Verilog (`iverilog` and
`vvp`) installed:

```sh
python3 tools/test_cd_ring.py
```

The test compiles the existing `src/fpga/glue/cd_ring.sv` and checks it against
an independent byte-array oracle. It needs no firmware, ROM, MIF, FPGA tool
license, or reference RTL. It preserves source snapshots, commands, logs and
SHA256 hashes in a printed temporary directory. Use `--out new-results` to
choose a fresh output directory, or `--source path/to/cd_ring.sv` to test an
isolated implementation. Existing output directories are rejected.

The 24 positive configurations cover both endian modes, two read-clock phases,
the four nominal system-clock rates, and faster/slower reader stress ratios.
They check every valid halfword of the six-sector buffer, sector/end boundaries,
bridge and read-address aliases, ignored byte-address bits, rejected windows,
concurrent disjoint-port accesses, unknown-bank accesses and registered read
latency. Nominal periods are rounded by the simulator's 1 ps precision.

Four mandatory negative controls mutate the supplied source: dropping the final
word and swapping halfwords, each in both endian modes. Each must compile and
then fail with its precise expected data diagnostic. A timeout, compilation
error or unrelated failure cannot satisfy a negative control. Unsupported source
shapes for these mutations produce an explicit failure and require updating the
control anchors when the RTL is refactored.

Each process has a 120-second timeout; the bench also has a simulated timeout.
The receipt marks success only after all expected outcomes pass. The suite was
validated with Icarus Verilog 13.0.

The default six-slot configuration is tested. Unknown and out-of-range addresses
are checked for RTL simulation behavior; they do not define physical RAM contents.
Same-address dual-clock read/write collisions are excluded. These tests do not
establish hardware compatibility, timing closure, power or performance.
