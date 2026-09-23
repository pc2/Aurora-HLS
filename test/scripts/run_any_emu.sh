#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TEST_MODE=3
exec "${SCRIPT_DIR}/run_ring_emu.sh" "$@"
