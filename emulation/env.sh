#!/usr/bin/bash
module reset
ml fpga devel toolchain lib tools && ml xilinx/xrt/2.14 zmqpp CMake/3.23.1-GCCcore-11.3.0 Boost/1.79.0-GCC-11.3.0 foss/2022a changeFPGAlinks git-lfs
