#!/usr/bin/bash
#SBATCH -p fpga
#SBATCH -t 00:05:00
#SBATCH -N 2
#SBATCH --constraint=xilinx_u280_xrt2.15
#SBATCH --tasks-per-node 6
#SBATCH --mail-type=ALL

source env.sh

#https://pc2.github.io/fpgalink-gui/index.html?import=%20-N%202%20--fpgalink%3Dn01%3Aacl1%3Ach0-n01%3Aacl1%3Ach1%20--fpgalink%3Dn00%3Aacl2%3Ach0-n00%3Aacl2%3Ach1%20--fpgalink%3Dn00%3Aacl0%3Ach0-n00%3Aacl0%3Ach1%20--fpgalink%3Dn00%3Aacl1%3Ach0-n00%3Aacl1%3Ach1%20--fpgalink%3Dn01%3Aacl0%3Ach0-n01%3Aacl0%3Ach1%20--fpgalink%3Dn01%3Aacl2%3Ach0-n01%3Aacl2%3Ach1
changeFPGAlinksXilinx --fpgalink=n01:acl1:ch0-n01:acl1:ch1 --fpgalink=n00:acl2:ch0-n00:acl2:ch1 --fpgalink=n00:acl0:ch0-n00:acl0:ch1 --fpgalink=n00:acl1:ch0-n00:acl1:ch1 --fpgalink=n01:acl0:ch0-n01:acl0:ch1 --fpgalink=n01:acl2:ch0-n01:acl2:ch1

srun -n 12 -l ./host_aurora_hls_test $@

#https://pc2.github.io/fpgalink-gui/index.html?import=%20--fpgalink%3Dn00%3Aacl2%3Ach0-n01%3Aacl2%3Ach0%20--fpgalink%3Dn00%3Aacl1%3Ach0-n01%3Aacl1%3Ach0%20--fpgalink%3Dn00%3Aacl0%3Ach0-n01%3Aacl0%3Ach0%20--fpgalink%3Dn00%3Aacl0%3Ach1-n01%3Aacl0%3Ach1%20--fpgalink%3Dn00%3Aacl1%3Ach1-n01%3Aacl1%3Ach1%20--fpgalink%3Dn00%3Aacl2%3Ach1-n01%3Aacl2%3Ach1
changeFPGAlinksXilinx --fpgalink=n00:acl2:ch0-n01:acl2:ch0 --fpgalink=n00:acl1:ch0-n01:acl1:ch0 --fpgalink=n00:acl0:ch0-n01:acl0:ch0 --fpgalink=n00:acl0:ch1-n01:acl0:ch1 --fpgalink=n00:acl1:ch1-n01:acl1:ch1 --fpgalink=n00:acl2:ch1-n01:acl2:ch1

srun -n 12 -l ./host_aurora_hls_test $@

#https://pc2.github.io/fpgalink-gui/index.html?import=%20--fpgalink%3Dn00%3Aacl0%3Ach1-n00%3Aacl1%3Ach0%20--fpgalink%3Dn00%3Aacl0%3Ach0-n01%3Aacl0%3Ach0%20--fpgalink%3Dn00%3Aacl1%3Ach1-n01%3Aacl1%3Ach1%20--fpgalink%3Dn01%3Aacl1%3Ach0-n00%3Aacl2%3Ach0%20--fpgalink%3Dn00%3Aacl2%3Ach1-n01%3Aacl2%3Ach1%20--fpgalink%3Dn01%3Aacl2%3Ach0-n01%3Aacl0%3Ach1
changeFPGAlinksXilinx  --fpgalink=n00:acl0:ch1-n00:acl1:ch0 --fpgalink=n00:acl0:ch0-n01:acl0:ch0 --fpgalink=n00:acl1:ch1-n01:acl1:ch1 --fpgalink=n01:acl1:ch0-n00:acl2:ch0 --fpgalink=n00:acl2:ch1-n01:acl2:ch1 --fpgalink=n01:acl2:ch0-n01:acl0:ch1

srun -n 12 -l ./host_aurora_hls_test $@
