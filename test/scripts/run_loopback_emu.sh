#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/../build}"
cd "$BUILD_DIR"

EMU_MODE="${1:-sw_emu}"
NUM_RANKS="${2:-2}"
shift 2 2>/dev/null || shift $# 2>/dev/null || true
PIPE_DIR="${PIPE_DIR:-$(pwd)/aurora_emu_$$}"
export XCL_EMULATION_MODE=$EMU_MODE

rm -rf "$PIPE_DIR"
mkdir -p "$PIPE_DIR"
cleanup_pipe_dir() {
    status=$?
    if (( status == 0 )); then
        rm -rf "$PIPE_DIR"
    else
        echo "Preserving failed emulation directory: $PIPE_DIR" >&2
    fi
}
trap cleanup_pipe_dir EXIT

"${SCRIPT_DIR}/configure_emu.sh" loopback "$NUM_RANKS" "$PIPE_DIR"

mpirun -x XCL_EMULATION_MODE -n $NUM_RANKS \
    "${SCRIPT_DIR}/rank_wrapper.sh" "$PIPE_DIR" "$EMU_MODE" -m 0 "$@"
