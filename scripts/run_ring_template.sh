#!/bin/bash

#SBATCH -t 02:00:00
#SBATCH -n {0}
#SBATCH --ntasks-per-node 3
#SBATCH -J "afr_{0}"
#SBATCH -o aurora_flow_ring_n{0}_%j.out
#SBATCH -p fpga
#SBATCH -A hpc-lco-kenter
#SBATCH --constraint xilinx_u280_xrt2.14

## Load environment modules
source env.sh

#https://pc2.github.io/fpgalink-gui/index.html?import={3}
changeFPGAlinksXilinx {2}
srun -l -n {1} --spread-job ./scripts/reset.sh

srun -l -n {0} ./host_aurora_flow_ring -s -m 2 -i 1024
