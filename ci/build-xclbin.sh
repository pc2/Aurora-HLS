set -euo pipefail

build_dir="$PWD/build"
artifact="aurora_flow_test_${TARGET}_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_c${TARGET_CLOCK_HZ}_xrt${XRT}.xclbin"

if [[ "$BUILD_SYS" == "make" ]]; then
  make -C "$CI_PROJECT_DIR/test" \
    BUILD_DIR="$build_dir" \
    TARGET="$TARGET" \
    FIFO_WIDTH="$WIDTH" \
    USE_FRAMING="$FRAMING" \
    TARGET_CLOCK_HZ="$TARGET_CLOCK_HZ" \
    xclbin
else
  cmake -S "$CI_PROJECT_DIR/test" -B "$build_dir" \
    -DAURORA_FLOW_FIFO_WIDTH="$WIDTH" \
    -DAURORA_FLOW_USE_FRAMING="$FRAMING" \
    -DAURORA_FLOW_TARGET_CLOCK_HZ="$TARGET_CLOCK_HZ"
  cmake --build "$build_dir" --parallel 16 --target "xclbin_${TARGET}" emconfig
fi

cp "$build_dir/aurora_flow_test_${TARGET}.xclbin" "$artifact"
cp "$build_dir/emconfig.json" emconfig.json

if [[ "$TARGET" == "hw" ]]; then
  cp "$build_dir/aurora_flow_clock_${TARGET_CLOCK_HZ}.cfg" clock.cfg
  mkdir -p timing-reports
  report_count=0
  while IFS= read -r report; do
    cp "$report" "timing-reports/${report_count}_$(basename "$report")"
    report_count=$((report_count + 1))
  done < <(find "$build_dir" -type f -path '*impl_1*' -iname '*timing*.rpt' -print | sort)
  if (( report_count == 0 )); then
    echo "hardware link produced no implementation timing report" >&2
    exit 1
  fi
fi
