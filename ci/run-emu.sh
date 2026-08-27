set -euo pipefail

if [[ "$TARGET" == "hw_emu" ]]; then
  artifact="aurora_flow_test_hw_emu_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_a${AXI_CLOCK_HZ}_gt${HW_EMU_GT_CLOCK_HZ}_clocks${HW_EMU_CLOCKS}_xrt${XRT}.xclbin"
else
  artifact="aurora_flow_test_sw_emu_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_xrt${XRT}.xclbin"
fi
run_dir="$PWD/run"
mkdir -p "$run_dir"

if [[ "$BUILD_SYS" == "make" ]]; then
  make -C "$CI_PROJECT_DIR/test" BUILD_DIR="$run_dir" host
else
  cmake -S "$CI_PROJECT_DIR/test" -B "$run_dir/cmake-host"
  cmake --build "$run_dir/cmake-host" --parallel 8 --target host_aurora_flow_test
  cp "$run_dir/cmake-host/host_aurora_flow_test" "$run_dir/"
fi
cp "$artifact" "$run_dir/aurora_flow_test_${TARGET}.xclbin"
cp emconfig.json "$run_dir/"

if [[ "$RUN_KIND" == "nfc" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_pair_emu.sh" "$TARGET" "$RUN_RANKS" -r 1 -i 1 -b 65536 -n)
elif [[ "$TARGET" == "hw_emu" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_${TOPOLOGY}_emu.sh" "$TARGET" "$RUN_RANKS" -r 2 -i 2 -b 256)
else
  command=("$CI_PROJECT_DIR/test/scripts/run_${TOPOLOGY}_emu.sh" "$TARGET" "$RUN_RANKS" -r 2 -i 10)
fi

if ! BUILD_DIR="$run_dir" "${command[@]}" 2>&1 | tee emu-run.log; then
  exit 1
fi
