#!/usr/bin/bash
module reset

ml fpga
ml xilinx/xrt/${XRT:-2.16}
export XILINX_LOCAL_USER_DATA=no

ml tools
ml changeFPGAlinks

ml toolchain
ml gompi/2025b

ml devel
ml CMake/4.0.3-GCCcore-14.3.0
