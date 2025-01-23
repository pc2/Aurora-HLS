#!/usr/bin/bash
#SBATCH -p fpga
#SBATCH -t 00:30:00
#SBATCH -N 1
#SBATCH --constraint=xilinx_u280_xrt2.14
#SBATCH --tasks-per-node 6
#SBATCH --mail-type=ALL

if ! command -v v++ &> /dev/null
then
    source env.sh
fi

./scripts/reset.sh

./scripts/configure_ring.sh

./host_aurora_flow_test -m 2 $@
