# AuroraFlow test application

A benchmark/verification application that uses the AuroraFlow library across all three execution modes (`hw`, `hw_emu`, `sw_emu`). This also serves as a reference for how to use the library from both Make and CMake.

## What it does

Two simple HLS kernels (`hls/send.cpp`, `hls/recv.cpp`) send and receive data over the Aurora link.
The host program (`host/host_aurora_flow_test.cpp`) is MPI-based and uses up to three FPGAs per node, in one of three topologies:

- **Loopback** (`-m 0`): each Aurora core loops back to itself
- **Pair** (`-m 1`): ch0 and ch1 of the same FPGA talk to each other
- **Ring** (`-m 2`): every FPGA's ch1 talks to the next FPGA's ch0

For each (topology × message size × frame size) combination, the host measures latency and throughput, reads back the AuroraFlow status counters via the library's C++ API, and writes one line per repetition to `results.csv`.
With the known topology, the data can be verified on the host. This can be disabled to test arbitrary topologies using `-m 3`.

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
│   └── aurora_flow_test_sw_emu.cfg  v++ link config (sw_emu)
├── scripts/
│   ├── configure_emu.sh             pipe topology setup via topomux
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

```bash
make host                        # host_aurora_flow_test
make xclbin TARGET=sw_emu        # aurora_flow_test_sw_emu.xclbin
make xclbin TARGET=hw_emu        # aurora_flow_test_hw_emu.xclbin
make xclbin TARGET=hw            # aurora_flow_test_hw.xclbin (synthesis, slow)
```

The `test/Makefile` includes `../aurora_flow.mk`, which locates the library. Variables like `FIFO_WIDTH=32` and `USE_FRAMING=1` are forwarded to the library Makefile automatically.

```bash
make xclbin TARGET=hw_emu FIFO_WIDTH=32 USE_FRAMING=1 \
  HW_EMU_CLOCKS=2 HW_EMU_INTERFACE_CLOCK_ID=1 \
  AXI_CLOCK_HZ=400000000 HW_EMU_GT_CLOCK_HZ=400000000

make xclbin TARGET=hw FIFO_WIDTH=32 USE_FRAMING=1 \
  HW_INTERFACE_CLOCK_ID=1 AXI_CLOCK_HZ=400000000
```

For split-clock `hw_emu`, clock 0 stays at 300 MHz for HLS and AXI-Lite control.
`HW_EMU_INTERFACE_CLOCK_ID=1` moves the AXI-Stream data path to `ap_clk_2`;
`AXI_CLOCK_HZ` and `HW_EMU_GT_CLOCK_HZ` must then match because the data path and GT stub share clock 1.

For split-clock `hw`, `ap_clk` and AXI-Lite control remain at 300 MHz while `HW_INTERFACE_CLOCK_ID=1` places the AXI-Stream data path on `ap_clk_2` at `AXI_CLOCK_HZ`.
The real Aurora IP generates its own clock>

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
  -DAURORA_FLOW_AXI_CLOCK_HZ=400000000 \
  -DAURORA_FLOW_HW_INTERFACE_CLOCK_ID=1 \
  -DAURORA_FLOW_HW_EMU_CLOCKS=2 \
  -DAURORA_FLOW_HW_EMU_INTERFACE_CLOCK_ID=1 \
  -DAURORA_FLOW_HW_EMU_GT_CLOCK_HZ=400000000
```

The CMake build uses the same library artifacts. `find_package(AuroraFlow)` delegates kernel packaging back to the library Makefile, and CMake invokes v++ for the HLS kernel compile and xclbin link step.

## Running

All build artifacts (host binary, xclbin, `emconfig.json`) live in `test/build/`.
The run scripts `cd` into that directory automatically before invoking `mpirun`,
so you can launch them from `test/`. Override with `BUILD_DIR=...` if you built
somewhere else.

### Emulation

```bash
./scripts/run_loopback_emu.sh sw_emu 3 -r 2 -i 10       # sw_emu, loopback, 3 ranks
./scripts/run_pair_emu.sh     hw_emu 3 -r 2 -i 2 -b 256 # hw_emu, pair, 3 ranks
./scripts/run_ring_emu.sh     sw_emu 2 -r 1 -i 100      # sw_emu, ring, 2 ranks
```

Arguments: `<emu_mode> [num_ranks] [host_args...]`. All trailing arguments are forwarded to `host_aurora_flow_test`.

Each `run_*_emu.sh` script does three things:
1. Creates `AURORA_PIPE_DIR` and invokes the matching `configure_*_emu.sh` to `mkfifo` the per-rank pipes and symlink them into the chosen topology. The pipe naming follows the library contract documented in the root README.
2. For `sw_emu`, launches `mpirun -n N ./host_aurora_flow_test ...` directly.
3. For `hw_emu`, launches `mpirun -n N ./hw_emu_rank_wrapper.sh ...` so each rank gets its own working directory (xsim uses fixed socket/lock filenames that would collide between processes on the same host).

### Hardware

```bash
./scripts/run_loopback_hw.sh -p aurora_flow_test_hw.xclbin
./scripts/run_pair_hw.sh     -p aurora_flow_test_hw.xclbin -l -i 10
./scripts/run_ring_hw.sh     -p aurora_flow_test_hw.xclbin
```

These scripts source `env.sh` (Noctua 2 module loads), reset the FPGAs, configure QSFP links for the requested topology, and run the host with the correct `-m` flag. Additional arguments are passed through to the host binary.

On Noctua 2, there's also a helper that iterates over all FPGA nodes:

```bash
./scripts/for_every_node.sh ./scripts/run_over_all_configs.sh
```

## CLI reference

```
Test program for AuroraFlow
Usage:
  host_aurora_flow_test [OPTION...]

  -d, --device_id arg    Device ID according to linkscript (default: 0)
  -p, --xclbin_path arg  Path to xclbin file (default:
                         aurora_flow_test_hw.xclbin)
  -r, --repetitions arg  Repetitions. Will be discarded, when used with -l
                         (default: 1)
  -i, --iterations arg   Iterations in one repetition. Will be scaled up,
                         when used with -l (default: 1)
  -f, --frame_size arg   Maximum frame size. In multiple of the input width
                         (default: 128)
  -b, --num_bytes arg    Maximum number of bytes transferred per iteration.
                         Must be a multiple of the input width (default:
                         1048576)
  -m, --test_mode arg    Topology. 0 for loopback, 1 for pair and 2 for
                         ring (default: 0)
  -c, --check_status     Check if the link is up and exit
  -n, --nfc_test         NFC Test. Recv Kernel will be started 3 seconds
                         later then the Send kernel.
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
