# AuroraFlow link test

This bundle contains hosts for XRT 2.14, 2.15, and 2.16 with framed and unframed hardware bitstreams.
The bitstreams target `xilinx_u280_gen3x16_xdma_1_202211_1` and use a 512 bit stream at 300 MHz.
The `2.14`, `2.15`, and `2.16` directories each contain `linktest`, the default framed `aurora_flow_test_hw.xclbin`, and `aurora_flow_test_hw_streaming.xclbin`.
The collected `hpc-ci-results.json` identifies the bitstream builds, and `host-commit.txt` identifies the host source revision.

Use an FPGA allocation with the matching XRT version and the Noctua 2 modules provided by `env.sh`.
The host also requires the matching MPI environment.
The launchers reset three local FPGAs and configure their links.
Run the following commands from the extracted `linktest` directory inside your allocation.

```bash
export XRT=2.16
source env.sh
export BUILD_DIR="$PWD/$XRT"
bash test/scripts/run_pair_hw.sh -p aurora_flow_test_hw.xclbin -f 128 -l -i 20 -b 268435456
bash test/scripts/run_pair_hw.sh -p aurora_flow_test_hw_streaming.xclbin -l -i 20 -b 268435456
```

The pair test verifies payload data and writes `results.csv` into the selected version directory.
Larger frames reduce framing overhead.
The unframed 512 bit configuration has measured approximately 96.6 Gbit/s with XRT 2.16.
Throughput benchmarks currently cover XRT 2.16 only.
Artifact availability confirms successful host and bitstream builds, and does not imply that every hardware test passed.

Use the existing `run_any_hw.sh` launcher for concurrent traffic over ring wiring without payload verification.

```bash
bash test/scripts/run_any_hw.sh -p aurora_flow_test_hw.xclbin -f 128 -r 2 -i 20 -b 268435456
bash test/scripts/run_any_hw.sh -p aurora_flow_test_hw_streaming.xclbin -r 2 -i 20 -b 268435456
```
