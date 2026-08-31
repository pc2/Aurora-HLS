#!/usr/bin/bash
set -euo pipefail

#SBATCH -p fpga
#SBATCH -t 00:30:00
#SBATCH -N 1
#SBATCH --constraint=xilinx_u280_xrt2.16
#SBATCH --mail-type=ALL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AURORA_FLOW_DIR="${AURORA_FLOW_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

if ! command -v v++ &> /dev/null
then
    source "${AURORA_FLOW_DIR}/env.sh"
fi

# Build artifacts live under test/build/
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/../build}"
cd "$BUILD_DIR"

"${SCRIPT_DIR}/reset.sh"

"${SCRIPT_DIR}/configure_ring_hw.sh"

exec ./host_aurora_flow_test -m 2 "$@"
