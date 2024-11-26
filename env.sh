#!/usr/bin/bash
module reset
ml fpga devel toolchain lib tools && ml xilinx/xrt/2.14 foss/2022a changeFPGAlinks git-lfs
