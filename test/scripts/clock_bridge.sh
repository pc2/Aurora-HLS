#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/../.." && pwd)"

if ! command -v v++ >/dev/null 2>&1; then
    echo "v++ is not available; source ${repo_dir}/env.sh first" >&2
    exit 2
fi

target="${TARGET:-hw_emu}"
case "${target}" in
    hw|hw_emu) ;;
    *)
        echo "TARGET must be hw or hw_emu" >&2
        exit 2
        ;;
esac

build_dir="${BUILD_DIR:-${repo_dir}/test/build-clock-bridge-${target}-400mhz}"
jobs="${JOBS:-4}"
framing="${USE_FRAMING:-1}"
vpp_debug="${VPP_DEBUG:-0}"

echo "Building line-rate split-clock ${target} variant"
echo "  HLS side:           512 bits at 300 MHz"
echo "  AuroraFlow side:    256 bits at 400 MHz"
echo "  framing:            ${framing}"
echo "  Vitis debug:         ${vpp_debug}"
echo "  output:             ${build_dir}"

make_args=(
    BUILD_DIR="${build_dir}"
    TARGET="${target}"
    FIFO_WIDTH=32
    HLS_WIDTH=64
    HLS_CLOCK_HZ=300000000
    USE_FRAMING="${framing}"
    AXI_CLOCK_HZ=400000000
    CLOCK_BRIDGE=1
    VPP_DEBUG="${vpp_debug}"
)

if [[ "${target}" == "hw" ]]; then
    make_args+=(HW_INTERFACE_CLOCK_ID=1)
else
    make_args+=(
        HW_EMU_GT_CLOCK_HZ=400000000
        HW_EMU_CLOCKS=2
        HW_EMU_INTERFACE_CLOCK_ID=1
    )
fi

make -C "${repo_dir}/test" --jobs="${jobs}" "${make_args[@]}" host xclbin

"${script_dir}/check_clock_bridge_link.sh" "${build_dir}" "${target}"

echo
echo "Built ${build_dir}/aurora_flow_test_${target}.xclbin"
