set -euo pipefail

artifact="aurora_flow_test_hw_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_a${AXI_CLOCK_HZ}_xrt${XRT}.xclbin"
run_dir="$PWD/run"
mkdir -p "$run_dir"
make -C "$CI_PROJECT_DIR/test" BUILD_DIR="$run_dir" host
cp "$artifact" "$run_dir/aurora_flow_test_hw.xclbin"

if ! BUILD_DIR="$run_dir" "$CI_PROJECT_DIR/test/scripts/run_pair_hw.sh" \
    -p aurora_flow_test_hw.xclbin -f "$FRAME_SIZE" -l -i 20 -b 268435456 \
    > benchmark.log 2>&1; then
  cat benchmark.log
  exit 1
fi
cat benchmark.log
test -s "$run_dir/results.csv"
cp "$run_dir/results.csv" benchmark.csv
