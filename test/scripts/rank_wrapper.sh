#!/bin/bash
# Invoked by mpirun. cds into the rank's pipe dir (which contains link_i*_{tx,rx})
# and symlinks the host binary + xclbin + emconfig.json into it.

set -e

PIPE_DIR="${1:?usage: rank_wrapper.sh <pipe_dir> <emu_mode> [host args...]}"
EMU_MODE="${2:?usage: rank_wrapper.sh <pipe_dir> <emu_mode> [host args...]}"
shift 2

RANK=${OMPI_COMM_WORLD_RANK:-${PMIX_RANK:-${PMI_RANK:-${SLURM_PROCID:-0}}}}
BASE_DIR="$(pwd)"
RANK_DIR="${PIPE_DIR}/rank${RANK}"
RANK_TMP_DIR="${RANK_DIR}/tmp"

mkdir -p "$RANK_TMP_DIR"

ln -sf "${BASE_DIR}/aurora_flow_test_${EMU_MODE}.xclbin" "${RANK_DIR}/"
ln -sf "${BASE_DIR}/emconfig.json"                       "${RANK_DIR}/"
ln -sf "${BASE_DIR}/host_aurora_flow_test"               "${RANK_DIR}/"
[ -e "${BASE_DIR}/xrt.ini" ] && ln -sf "${BASE_DIR}/xrt.ini" "${RANK_DIR}/"

export AURORA_PIPE_DIR="${PIPE_DIR}"
export TMPDIR="$RANK_TMP_DIR"
cd "$RANK_DIR"
printf 'emulation rank %s: cwd=%s TMPDIR=%s\n' "$RANK" "$PWD" "$TMPDIR" >&2
exec ./host_aurora_flow_test "$@"
