set -euo pipefail

artifact="aurora_flow_test_hw_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_a${AXI_CLOCK_HZ}_xrt${XRT}.xclbin"
run_dir="$PWD/run"
mkdir -p "$run_dir"
if [[ "$BUILD_SYS" == "make" ]]; then
  make -C "$CI_PROJECT_DIR/test" \
    BUILD_DIR="$run_dir" \
    FIFO_WIDTH="$WIDTH" \
    USE_FRAMING="$FRAMING" \
    host
else
  cmake -S "$CI_PROJECT_DIR/test" -B "$run_dir/cmake-host"
  cmake --build "$run_dir/cmake-host" --parallel 8 --target host_aurora_flow_test
  cp "$run_dir/cmake-host/host_aurora_flow_test" "$run_dir/"
fi
cp "$artifact" "$run_dir/aurora_flow_test_hw.xclbin"

if BUILD_DIR="$run_dir" "$CI_PROJECT_DIR/test/scripts/run_pair_hw.sh" \
    -p aurora_flow_test_hw.xclbin -f "$FRAME_SIZE" -l -i 20 -b 268435456 \
    > benchmark.log 2>&1; then
  :
else
  status=$?
  cat benchmark.log
  exit "$status"
fi
cat benchmark.log
test -s "$run_dir/results.csv"
cp "$run_dir/results.csv" benchmark.csv
