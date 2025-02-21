#!/usr/bin/bash
#SBATCH -p fpga
#SBATCH -t 28:00:00
#SBATCH -N 1
#SBATCH --constraint=xilinx_u280_xrt2.14
#SBATCH --mail-type=ALL

if ! command -v v++ &> /dev/null
then
    source env.sh
fi

./scripts/reset.sh

./scripts/configure_pair.sh

# approx. 2:15 hours
./host_aurora_flow_test -d 1 -m 1 -b 268435456 -i 184320 $@
