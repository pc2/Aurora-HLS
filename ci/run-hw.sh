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

if [[ "$RUN_KIND" == "short-keep" && "$FRAMING" != "1" ]]; then
  echo "short-keep requires FRAMING=1" >&2
  exit 2
fi

if [[ "$RUN_KIND" == "nfc" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_pair_hw.sh" -p aurora_flow_test_hw.xclbin -n -l)
elif [[ "$RUN_KIND" == "short-keep" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_${TOPOLOGY}_hw.sh" -p aurora_flow_test_hw.xclbin -r 1 -i 1 -b 257 -f 2)
elif [[ "$FRAMING" == "1" ]]; then
  command=("$CI_PROJECT_DIR/test/scripts/run_${TOPOLOGY}_hw.sh" -p aurora_flow_test_hw.xclbin -r 1 -i 1 -b 256 -f 2)
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
