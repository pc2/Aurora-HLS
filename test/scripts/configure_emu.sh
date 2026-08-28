#!/usr/bin/env bash
# configure_emu.sh <loopback|pair|ring> <num_ranks> <pipe_dir>
# Configure an emulation topology with topomux.
set -euo pipefail

TOPOLOGY="${1:?usage: configure_emu.sh <loopback|pair|ring> <num_ranks> <pipe_dir>}"
NUM_RANKS="${2:?usage: configure_emu.sh <loopback|pair|ring> <num_ranks> <pipe_dir>}"
PIPE_DIR="${3:?usage: configure_emu.sh <loopback|pair|ring> <num_ranks> <pipe_dir>}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

case "$TOPOLOGY" in
    loopback|pair|ring) ;;
    *)
        echo "configure_emu.sh: unsupported topology '$TOPOLOGY'" >&2
        exit 2
        ;;
esac

"${SCRIPT_DIR}/topomux" "$TOPOLOGY" "$NUM_RANKS" \
    --backend emulation --base-dir "$PIPE_DIR" | bash -e
