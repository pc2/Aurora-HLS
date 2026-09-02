set -euo pipefail

build_dir="$PWD/build"
case "$TARGET" in
  sw_emu)
    artifact="aurora_flow_test_sw_emu_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_xrt${XRT}.xclbin"
    ;;
  hw)
    artifact="aurora_flow_test_hw_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_a${AXI_CLOCK_HZ}_xrt${XRT}.xclbin"
    ;;
  hw_emu)
    artifact="aurora_flow_test_hw_emu_${BUILD_SYS}_f${FRAMING}_w${WIDTH}_a${AXI_CLOCK_HZ}_gt${HW_EMU_GT_CLOCK_HZ}_clocks${HW_EMU_CLOCKS}_xrt${XRT}.xclbin"
    ;;
  *)
    echo "unsupported target: $TARGET" >&2
    exit 2
    ;;
esac

if [[ "$BUILD_SYS" == "make" ]]; then
  make_args=(
    BUILD_DIR="$build_dir"
    TARGET="$TARGET"
    FIFO_WIDTH="$WIDTH"
    USE_FRAMING="$FRAMING"
  )
  if [[ "$TARGET" != "sw_emu" ]]; then
    make_args+=(
      HLS_WIDTH="${HLS_WIDTH:-$WIDTH}"
      HLS_CLOCK_HZ="${HLS_CLOCK_HZ:-300000000}"
      AXI_CLOCK_HZ="$AXI_CLOCK_HZ"
      CLOCK_BRIDGE="${CLOCK_BRIDGE:-0}"
    )
  fi
  if [[ "$TARGET" == "hw" ]]; then
    make_args+=(HW_INTERFACE_CLOCK_ID="${HW_INTERFACE_CLOCK_ID:-0}")
  fi
  if [[ "$TARGET" == "hw_emu" ]]; then
    make_args+=(
      HW_EMU_GT_CLOCK_HZ="$HW_EMU_GT_CLOCK_HZ"
      HW_EMU_CLOCKS="$HW_EMU_CLOCKS"
      HW_EMU_INTERFACE_CLOCK_ID="${HW_EMU_INTERFACE_CLOCK_ID:-0}"
    )
  fi
  make -C "$CI_PROJECT_DIR/test" "${make_args[@]}" xclbin
else
  cmake_args=(
    -DAURORA_FLOW_FIFO_WIDTH="$WIDTH"
    -DAURORA_FLOW_USE_FRAMING="$FRAMING"
  )
  if [[ "$TARGET" != "sw_emu" ]]; then
    cmake_args+=(-DAURORA_FLOW_AXI_CLOCK_HZ="$AXI_CLOCK_HZ")
  fi
  if [[ "$TARGET" == "hw" ]]; then
    cmake_args+=(-DAURORA_FLOW_HW_INTERFACE_CLOCK_ID="${HW_INTERFACE_CLOCK_ID:-0}")
  fi
  if [[ "$TARGET" == "hw_emu" ]]; then
    cmake_args+=(
      -DAURORA_FLOW_HW_EMU_GT_CLOCK_HZ="$HW_EMU_GT_CLOCK_HZ"
      -DAURORA_FLOW_HW_EMU_CLOCKS="$HW_EMU_CLOCKS"
      -DAURORA_FLOW_HW_EMU_INTERFACE_CLOCK_ID="${HW_EMU_INTERFACE_CLOCK_ID:-0}"
    )
  fi
  cmake -S "$CI_PROJECT_DIR/test" -B "$build_dir" "${cmake_args[@]}"
  cmake --build "$build_dir" --parallel 16 --target "xclbin_${TARGET}" emconfig
fi

cp "$build_dir/aurora_flow_test_${TARGET}.xclbin" "$artifact"
cp "$build_dir/emconfig.json" emconfig.json

if [[ "$TARGET" != "sw_emu" && "${CLOCK_BRIDGE:-0}" == "1" ]]; then
  "$CI_PROJECT_DIR/test/scripts/check_clock_bridge_link.sh" "$build_dir" "$TARGET"
fi

if [[ "$TARGET" == "hw" ]]; then
  if [[ "$BUILD_SYS" == "make" ]]; then
    clock_config="$build_dir/aurora_flow_axi_clock_${AXI_CLOCK_HZ}_data_clock_${HW_INTERFACE_CLOCK_ID:-0}_bridge_${CLOCK_BRIDGE:-0}.cfg"
  else
    clock_config="$build_dir/aurora_flow_axi_clock_${AXI_CLOCK_HZ}_data_clock_${HW_INTERFACE_CLOCK_ID:-0}.cfg"
  fi
  cp "$clock_config" clock.cfg
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
