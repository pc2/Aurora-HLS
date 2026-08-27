#
# Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# AuroraFlow test/benchmark application.
# Consumes the AuroraFlow library via aurora_flow.mk.
#
# All build artifacts (host binary, HLS .xo files, xclbin, emconfig.json,
# v++ temp dirs) land under $(BUILD_DIR) (default: ./build). The library
# kernels are also told to build into the same directory, so a single
# `rm -rf build/` cleans everything that this Makefile produces.
#

AURORA_FLOW_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# All outputs go here. Override with `make BUILD_DIR=...` if needed.
BUILD_DIR ?= $(CURDIR)/build

# Tell the library to build into the same place (must be set before include).
AURORA_FLOW_BUILD_DIR := $(abspath $(BUILD_DIR))

include $(AURORA_FLOW_DIR)/aurora_flow.mk

.PHONY: all host xclbin clean test

# Export AURORA_FLOW_DIR so run_*_emu.sh scripts can find library scripts
export AURORA_FLOW_DIR

PLATFORM ?= xilinx_u280_gen3x16_xdma_1_202211_1
TARGET   ?= hw
FIFO_WIDTH ?= 64
TARGET_CLOCK_HZ ?= 300000000

MPICXX := mpic++

CXXFLAGS += -std=c++17 -Wall -g
CXXFLAGS += -I$(XILINX_XRT)/include
CXXFLAGS += $(AURORA_FLOW_INCLUDE)
CXXFLAGS += -fopenmp
LDFLAGS  := -L$(XILINX_XRT)/lib -lxrt_coreutil -luuid

VPP_HLSCFLAGS := --compile --platform $(PLATFORM) --target $(TARGET) --save-temps --debug \
                 -DDATA_WIDTH_BYTES=$(FIFO_WIDTH)

VPP_LINKFLAGS := --link --optimize 3 --platform $(PLATFORM) --save-temps --debug

# Keep the selected frequency in the file name so changing TARGET_CLOCK_HZ in
# an existing build directory cannot silently reuse a stale clock directive.
AURORA_CLOCK_CONFIG := $(BUILD_DIR)/aurora_flow_clock_$(TARGET_CLOCK_HZ).cfg

all: host xclbin

$(BUILD_DIR):
	mkdir -p $@

# ---------------------------------------------------------------------------
# Application HLS kernels
# ---------------------------------------------------------------------------

$(BUILD_DIR)/recv_$(TARGET).xo: hls/recv.cpp | $(BUILD_DIR)
	v++ $(VPP_HLSCFLAGS) --temp_dir $(BUILD_DIR)/_x_recv_$(TARGET) --kernel recv --output $@ $<

$(BUILD_DIR)/send_$(TARGET).xo: hls/send.cpp | $(BUILD_DIR)
	v++ $(VPP_HLSCFLAGS) --temp_dir $(BUILD_DIR)/_x_send_$(TARGET) --kernel send --output $@ $<

$(AURORA_CLOCK_CONFIG): Makefile | $(BUILD_DIR)
	printf '[clock]\nfreqHz=%s:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\n' \
	       '$(TARGET_CLOCK_HZ)' > $@

# ---------------------------------------------------------------------------
# Linked xclbin (one rule per target execution mode)
# ---------------------------------------------------------------------------

# hw xclbin
$(BUILD_DIR)/aurora_flow_test_hw.xclbin: $(AURORA_FLOW_XOS_HW) \
                                          $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo \
                                          cfg/aurora_flow_test_hw.cfg \
                                          $(AURORA_CLOCK_CONFIG) | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw \
	    --config cfg/aurora_flow_test_hw.cfg \
	    --config $(AURORA_CLOCK_CONFIG) \
	    --output $@ \
	    $(AURORA_FLOW_XOS_HW) $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo

# hw_emu xclbin (requires DPI-C source for xsim)
$(BUILD_DIR)/aurora_flow_test_hw_emu.xclbin: $(AURORA_FLOW_XOS_HW_EMU) \
                                              $(BUILD_DIR)/send_hw_emu.xo $(BUILD_DIR)/recv_hw_emu.xo \
                                              cfg/aurora_flow_test_hw_emu.cfg \
                                              $(AURORA_CLOCK_CONFIG) \
                                              $(AURORA_FLOW_DPI_SRC) | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw_emu \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw_emu \
	    --config cfg/aurora_flow_test_hw_emu.cfg \
	    --config $(AURORA_CLOCK_CONFIG) \
	    --vivado.prop "fileset.sim_1.{xsim.compile.xsc.more_options}={$(AURORA_FLOW_DPI_SRC)}" \
	    --output $@ \
	    $(AURORA_FLOW_XOS_HW_EMU) $(BUILD_DIR)/send_hw_emu.xo $(BUILD_DIR)/recv_hw_emu.xo

# sw_emu xclbin
$(BUILD_DIR)/aurora_flow_test_sw_emu.xclbin: $(AURORA_FLOW_XO_SW_EMU) \
                                              $(BUILD_DIR)/send_sw_emu.xo $(BUILD_DIR)/recv_sw_emu.xo \
                                              cfg/aurora_flow_test_sw_emu.cfg | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target sw_emu \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_sw_emu \
	    --config cfg/aurora_flow_test_sw_emu.cfg \
	    --output $@ \
	    $(AURORA_FLOW_XO_SW_EMU) $(BUILD_DIR)/send_sw_emu.xo $(BUILD_DIR)/recv_sw_emu.xo

$(BUILD_DIR)/emconfig.json: | $(BUILD_DIR)
	emconfigutil --platform $(PLATFORM) --od $(BUILD_DIR)

xclbin: $(BUILD_DIR)/aurora_flow_test_$(TARGET).xclbin $(BUILD_DIR)/emconfig.json

# ---------------------------------------------------------------------------
# Host binary
# ---------------------------------------------------------------------------

HOST_HDRS := host/Configuration.hpp host/Results.hpp host/Kernel.hpp cxxopts.hpp \
             $(AURORA_FLOW_HEADER)

$(BUILD_DIR)/host_aurora_flow_test: host/host_aurora_flow_test.cpp $(HOST_HDRS) | $(BUILD_DIR)
	$(MPICXX) -o $@ $< $(CXXFLAGS) $(LDFLAGS)

host: $(BUILD_DIR)/host_aurora_flow_test

# ---------------------------------------------------------------------------
# Quick sw_emu test
# ---------------------------------------------------------------------------

test: host $(BUILD_DIR)/aurora_flow_test_sw_emu.xclbin $(BUILD_DIR)/emconfig.json
	cd $(BUILD_DIR) && XCL_EMULATION_MODE=sw_emu ./host_aurora_flow_test -p aurora_flow_test_sw_emu.xclbin

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
