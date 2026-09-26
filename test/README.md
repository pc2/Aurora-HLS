# AuroraFlow test application

A benchmark/verification application that uses the AuroraFlow library across all three execution modes (`hw`, `hw_emu`, `sw_emu`). This also serves as a reference for how to use the library from both Make and CMake.

## What it does

Two simple HLS kernels (`hls/send.cpp`, `hls/recv.cpp`) send and receive data over the Aurora link.
The host program (`host/host_aurora_flow_test.cpp`) uses MPI and up to three FPGAs per node with four traffic modes.

- **Loopback** (`-m 0`), each Aurora core loops back to itself.
- **Pair** (`-m 1`), ch0 and ch1 of the same FPGA talk to each other.
- **Ring** (`-m 2`), every FPGA's ch1 talks to the next FPGA's ch0.
- **Any** (`-m 3`), all ports transfer concurrently without acknowledgements or payload verification.

For each (topology × message size × frame size) combination, the host measures latency and throughput, reads back the AuroraFlow status counters via the library's C++ API, and writes one line per repetition to `results.csv`.
Modes 0 through 2 verify payload data on the host.
Mode 3 supports arbitrary connected topologies.

The host binary is identical across all three execution modes. It picks up `XCL_EMULATION_MODE` at runtime and the library code in `AuroraFlow.hpp` routes accordingly.

## Layout

```
test/
├── Makefile              Make build (via aurora_flow.mk)
├── CMakeLists.txt        CMake build (via find_package(AuroraFlow))
├── hls/
│   ├── send.cpp          HLS kernel: reads DDR, writes AXI-Stream
│   └── recv.cpp          HLS kernel: reads AXI-Stream, writes DDR
├── host/
│   ├── host_aurora_flow_test.cpp
│   ├── Configuration.hpp (CLI parsing, ExecutionMode enum)
│   ├── Kernel.hpp        (SendKernel / RecvKernel wrappers)
│   └── Results.hpp       (result aggregation + csv writing)
├── cfg/
│   ├── aurora_flow_test_hw.cfg      v++ link config (hw)
│   ├── aurora_flow_test_hw_emu.cfg  v++ link config (hw_emu)
│   ├── aurora_flow_test_clock_bridge.cfg
│   │                                  300/400 MHz hw_emu bridge link config
│   ├── aurora_flow_test_clock_bridge_hw.cfg
│   │                                  bridge link config with U280 QSFP mappings
│   └── aurora_flow_test_sw_emu.cfg  v++ link config (sw_emu)
├── rtl/
│   └── aurora_flow_clock_bridge.v   reusable CDC + 512/256-bit test kernel
├── tcl/
│   └── pack_clock_bridge.tcl        packages the test bridge as an RTL XO
├── scripts/
│   ├── configure_emu.sh             pipe topology setup via topomux
│   ├── clock_bridge.sh              builds the 300/400 MHz bridge variant
│   ├── check_clock_bridge_link.sh    audits its generated Vitis connections
│   ├── topomux                      pinned uv launcher for topomux
│   ├── hw_emu_rank_wrapper.sh       xsim per-rank isolation (hw_emu + MPI)
│   ├── run_*_emu.sh                 emulation launchers (sw_emu / hw_emu)
│   ├── run_*_hw.sh                  hardware launchers (Noctua 2)
│   ├── configure_*_hw.sh            QSFP link configuration
│   └── reset.sh, synth.sh, ...      assorted helpers
├── eval/
│   └── eval.jl           Julia script for post-processing results.csv
└── cxxopts.hpp           Vendored single-header CLI parser
```

## Building with Make

CI publishes a single `auroraflow-linktest` artifact from the `linktest:publish` job.
It contains hosts for XRT 2.14, 2.15, and 2.16 with framed and unframed 512 bit hardware bitstreams and the hardware launchers.
The included README describes the required environment and link test commands.

```bash
make host                        # host_aurora_flow_test
make xclbin TARGET=sw_emu        # aurora_flow_test_sw_emu.xclbin
make xclbin TARGET=hw_emu        # aurora_flow_test_hw_emu.xclbin
make xclbin TARGET=hw            # aurora_flow_test_hw.xclbin (synthesis, slow)
```

The `test/Makefile` includes `../aurora_flow.mk`, which locates the library. Variables like `FIFO_WIDTH=32` and `USE_FRAMING=1` are forwarded to the library Makefile automatically.

Vitis waveform collection is disabled by default.
Set `VPP_DEBUG=1` for the Make build, or `AURORA_FLOW_VPP_DEBUG=ON` for CMake, when waveforms are needed.

## Building with CMake

```bash
mkdir build && cd build
cmake ..
cmake --build . --target host_aurora_flow_test
cmake --build . --target xclbin_sw_emu
cmake --build . --target xclbin_hw_emu
cmake --build . --target xclbin_hw
cmake --build . --target emconfig
```

Cache variables can be passed at configure time:

```bash
cmake .. \
  -DAURORA_FLOW_PLATFORM=xilinx_u280_gen3x16_xdma_1_202211_1 \
  -DAURORA_FLOW_FIFO_WIDTH=32 \
  -DAURORA_FLOW_USE_FRAMING=1 \
  -DAURORA_FLOW_AXI_CLOCK_HZ=300000000 \
  -DAURORA_FLOW_HW_INTERFACE_CLOCK_ID=1 \
  -DAURORA_FLOW_HW_EMU_CLOCKS=2 \
  -DAURORA_FLOW_HW_EMU_INTERFACE_CLOCK_ID=0 \
  -DAURORA_FLOW_HW_EMU_GT_CLOCK_HZ=400000000
```

The CMake build uses the same library artifacts. `find_package(AuroraFlow)` delegates kernel packaging back to the library Makefile, and CMake invokes v++ for the HLS kernel compile and xclbin link step.
The line-rate bridge is currently a Make/CI integration target

## Running

All build artifacts (host binary, xclbin, `emconfig.json`) live in `test/build/`.
The run scripts `cd` into that directory automatically before invoking `mpirun`, so you can launch them from `test/`.
Override with `BUILD_DIR=...` if you built somewhere else.

### Emulation

```bash
./scripts/run_loopback_emu.sh sw_emu 3 -r 2 -i 10       # sw_emu, loopback, 3 ranks
./scripts/run_pair_emu.sh     hw_emu 3 -r 2 -i 2 -b 256 # hw_emu, pair, 3 ranks
./scripts/run_ring_emu.sh     sw_emu 2 -r 1 -i 100      # sw_emu, ring, 2 ranks
./scripts/run_any_emu.sh      sw_emu 3 -r 2 -i 10

make xclbin TARGET=sw_emu FIFO_WIDTH=32 USE_FRAMING=1
./scripts/run_ring_emu.sh     sw_emu 2 -r 2 -i 10 -b 257 -f 2
```

Arguments: `<emu_mode> [num_ranks] [host_args...]`. All trailing arguments are forwarded to `host_aurora_flow_test`.

Each `run_*_emu.sh` script does three things:
1. Creates `AURORA_PIPE_DIR` and invokes `configure_emu.sh`, which uses the pinned topomux version to create the per-rank FIFOs and topology symlinks. The pipe naming follows the library contract documented in the root README.
2. For `sw_emu`, launches `mpirun -n N ./host_aurora_flow_test ...` directly.
3. For `hw_emu`, launches `mpirun -n N ./hw_emu_rank_wrapper.sh ...` so each rank gets its own working directory (xsim uses fixed socket/lock filenames that would collide between processes on the same host).

### Hardware

```bash
./scripts/run_loopback_hw.sh -p aurora_flow_test_hw.xclbin
./scripts/run_pair_hw.sh     -p aurora_flow_test_hw.xclbin -l -i 10
./scripts/run_ring_hw.sh     -p aurora_flow_test_hw.xclbin
./scripts/run_any_hw.sh      -p aurora_flow_test_hw.xclbin
```

These scripts source `env.sh` (Noctua 2 module loads), reset the FPGAs, configure QSFP links for the requested topology, and run the host with the correct `-m` flag. Additional arguments are passed through to the host binary.

On Noctua 2, there's also a helper that iterates over all FPGA nodes:

```bash
./scripts/for_every_node.sh ./scripts/run_over_all_configs.sh
```

## 32-byte/400 MHz line-rate variant

Users that clock their logic at line rate can use a 32-byte AXI-Stream interface and still achieve full throughput.
This variant is tested with a small wrapper that performs the data-width conversion and clock-domain crossing, allowing the regular HLS kernels to be reused.

```text
HLS 64-byte @ 300 MHz -> async FIFO -> 64/32-byte DWC -> AuroraFlow 32-byte @ 400 MHz
HLS 64-byte @ 300 MHz <- async FIFO <- 32/64-byte DWC <- AuroraFlow 32-byte @ 400 MHz
```

This variant supports both hardware emulation and real hardware. The helper selects the required clock IDs and builds the host and xclbin.

```bash
TARGET=hw_emu USE_FRAMING=1 ./scripts/clock_bridge.sh
TARGET=hw     USE_FRAMING=1 ./scripts/clock_bridge.sh
```

## CLI reference

```
Test program for AuroraFlow
Usage:
  host_aurora_flow_test [OPTION...]

  -d, --device_id arg    Device ID according to linkscript (default: 0)
  -p, --xclbin_path arg  Path to xclbin file (default:
                         aurora_flow_test_hw.xclbin)
  -r, --repetitions arg  Repetitions. Ignored when used with -l
                         (default: 1)
  -i, --iterations arg   Iterations in one repetition. Scaled up when used
                         with -l (default: 1)
  -f, --frame_size arg   Maximum frame size in multiples of the input width
                         (default: 128)
  -b, --num_bytes arg    Maximum number of bytes transferred per iteration.
                         Must be a multiple of the input width unless
                         the xclbin supports framing (default: 1048576)
  -m, --test_mode arg    0 for loopback, 1 for pair, 2 for ring, 3 for concurrent traffic without payload verification (default: 0)
  -c, --check_status     Check if the link is up and exit
  -n, --nfc_test         NFC test. Start the receive kernel 3 seconds after
                         the send kernel
  -l, --latency_test     Creates one repetition for every message size, up
                         to the maximum
  -s, --semaphore        Locks the results file. Needed for parallel
                         evaluation
  -t, --timeout_ms arg   Timeout in ms (default: 10000)
  -w, --wait             Wait for enter after loading bitstream. Needed for
                         chipscope
  -h, --help             Print usage
```

Results are printed to stdout and appended to `results.csv`. The `-s` flag serializes writes when running the test in parallel across nodes (the file must exist beforehand, otherwise the application will wait forever on the lock).

## Latency test (`-l`)

Sweeps through message sizes in powers of two from the channel width up to `--num_bytes`.
The number of iterations per message size is adjusted so every repetition has roughly the same duration.
The recv kernel acknowledges every iteration so that the actual transfer time is observable.
This requires the loopback or pair topology, for which an acknowledge stream in one FPGA exists.

Example, largest message size 128 MB:

```
./host_aurora_flow_test -l -i 10 -f 128

  Repetition       Bytes  Iterations  Frame Size
------------------------------------------------
           0          64     1405867           1
           1         128     1198316           2
           2         256      995838           4
  ...
          21   134217728          20         128
          22   268435456          10         128
```

## NFC test (`-n`)

Starts the recv kernel three seconds after the send kernel, forcing the RX FIFO to fill and the NFC flow control to trigger XOFF.
The test verifies that the link does not lose data under backpressure.
The host reads the `nfc_full_trigger_count`, `nfc_empty_trigger_count`, and `nfc_latency_count` counters from the AuroraFlow core afterwards.
Works in both `hw` and `hw_emu` modes.

```bash
./scripts/run_pair_hw.sh -p aurora_flow_test_hw.xclbin -n
./scripts/run_pair_emu.sh hw_emu 2 -r 1 -i 1 -b 65536 -n
```

<p align="center"><sup>Copyright&copy; 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)</sup></p>
