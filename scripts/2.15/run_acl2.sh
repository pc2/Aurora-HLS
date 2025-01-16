#!/usr/bin/bash
#SBATCH -p fpga
#SBATCH -t 00:30:00
#SBATCH -N 1
#SBATCH --constraint=xilinx_u280_xrt2.15
#SBATCH --tasks-per-node 2
#SBATCH --mail-type=ALL

if ! command -v v++ &> /dev/null
then
    source env.sh
fi

ml xilinx/xrt/2.15

./scripts/reset.sh

echo "configuring loopback on acl2"

#https://pc2.github.io/fpgalink-gui/index.html?import=%20--fpgalink%3Dn00%3Aacl0%3Ach0-n00%3Aacl0%3Ach0%20--fpgalink%3Dn00%3Aacl0%3Ach1-n00%3Aacl0%3Ach1%20--fpgalink%3Dn00%3Aacl1%3Ach0-n00%3Aacl2%3Ach0%20--fpgalink%3Dn00%3Aacl1%3Ach1-n00%3Aacl2%3Ach1
changeFPGAlinksXilinx --fpgalink=n00:acl0:ch0-n00:acl1:ch0 --fpgalink=n00:acl1:ch1-n00:acl0:ch1 --fpgalink=n00:acl2:ch0-n00:acl2:ch0 --fpgalink=n00:acl2:ch1-n00:acl2:ch1

./host_aurora_flow_test -d 0 -m 0 -c $@
