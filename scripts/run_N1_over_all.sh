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

#https://pc2.github.io/fpgalink-gui/index.html?import=%20--fpgalink%3Dn00%3Aacl0%3Ach0-n00%3Aacl0%3Ach0%20--fpgalink%3Dn00%3Aacl0%3Ach1-n00%3Aacl0%3Ach1%20--fpgalink%3Dn00%3Aacl1%3Ach0-n00%3Aacl1%3Ach0%20--fpgalink%3Dn00%3Aacl1%3Ach1-n00%3Aacl1%3Ach1%20--fpgalink%3Dn00%3Aacl2%3Ach0-n00%3Aacl2%3Ach0%20--fpgalink%3Dn00%3Aacl2%3Ach1-n00%3Aacl2%3Ach1
srun -n 1 changeFPGAlinksXilinx --fpgalink=n00:acl0:ch0-n00:acl0:ch0 --fpgalink=n00:acl0:ch1-n00:acl0:ch1 --fpgalink=n00:acl1:ch0-n00:acl1:ch0 --fpgalink=n00:acl1:ch1-n00:acl1:ch1 --fpgalink=n00:acl2:ch0-n00:acl2:ch0 --fpgalink=n00:acl2:ch1-n00:acl2:ch1

srun -n 1 ./scripts/reset.sh
srun -n 6 -l ./host_aurora_flow_test -p aurora_flow_test_hw_0_64.xclbin -f 0 $@

for frame_size in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304
do 
    srun -n 1 ./scripts/reset.sh
    srun -n 6 -l ./host_aurora_flow_test -p aurora_flow_test_hw_1_64.xclbin -f $frame_size $@
done

srun -n 1 ./scripts/reset.sh
srun -n 6 -l ./host_aurora_flow_test -p aurora_flow_test_hw_0_32.xclbin -f 0 $@

for frame_size in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608
do 
    srun -n 1 ./scripts/reset.sh
    srun -n 6 -l ./host_aurora_flow_test -p aurora_flow_test_hw_1_32.xclbin -f $frame_size $@
done
