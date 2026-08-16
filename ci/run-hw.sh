set -euo pipefail

artifact="aurora_flow_test_hw_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_c${TARGET_CLOCK_HZ}_xrt${XRT}.xclbin"
run_dir="$PWD/run"
mkdir -p "$run_dir"
make -C "$CI_PROJECT_DIR/test" BUILD_DIR="$run_dir" host
cp "$artifact" "$run_dir/aurora_flow_test_hw.xclbin"

if [[ "$RUN_KIND" == "nfc" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_pair_hw.sh" -p aurora_flow_test_hw.xclbin -n -l)
else
  command=("$CI_PROJECT_DIR/test/scripts/run_${TOPOLOGY}_hw.sh" -p aurora_flow_test_hw.xclbin -r 1 -i 1)
fi

if ! BUILD_DIR="$run_dir" "${command[@]}" > hw-run.log 2>&1; then
  cat hw-run.log
  exit 1
fi
cat hw-run.log
test -s "$run_dir/results.csv"
cp "$run_dir/results.csv" results.csv
