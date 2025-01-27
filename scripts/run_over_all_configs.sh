#!/usr/bin/bash
#SBATCH -p fpga
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH --constraint=xilinx_u280_xrt2.14
#SBATCH --tasks-per-node 6
#SBATCH --mail-type=ALL

if ! command -v v++ &> /dev/null
then
    source env.sh
fi

./scripts/configure_pair.sh
./scripts/reset.sh

./host_aurora_flow_test -m 1 -p aurora_flow_test_hw_0_64.xclbin -f 0 $@

for frame_size in 4 16 32 128
do 
    ./host_aurora_flow_test -m 1 -p aurora_flow_test_hw_1_64.xclbin -f $frame_size $@
done

./host_aurora_flow_test -m 1 -p aurora_flow_test_hw_0_32.xclbin -f 0 $@

for frame_size in 4 16 32 128
do 
    ./host_aurora_flow_test -m 1 -p aurora_flow_test_hw_1_32.xclbin -f $frame_size $@
done
