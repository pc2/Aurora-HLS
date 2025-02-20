#!/usr/bin/bash
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -q fpgasynthesis
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --mail-type=ALL

source env.sh

make aurora_flow_ring_hw.xclbin -j6 $@
