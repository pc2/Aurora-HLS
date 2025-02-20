#!/usr/bin/bash
module reset
ml fpga devel lib tools toolchain && ml xilinx/xrt/2.14 changeFPGAlinks gompi/2024a
