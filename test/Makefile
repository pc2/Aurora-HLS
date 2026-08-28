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
AXI_CLOCK_HZ ?= 300000000
HW_INTERFACE_CLOCK_ID ?= 0
HW_EMU_GT_CLOCK_HZ ?= 402800000
HW_EMU_CLOCKS ?= 2
HW_EMU_INTERFACE_CLOCK_ID ?= 0

ifeq ($(HW_EMU_CLOCKS):$(HW_EMU_INTERFACE_CLOCK_ID),1:1)
  $(error HW_EMU_INTERFACE_CLOCK_ID=1 requires HW_EMU_CLOCKS=2)
endif
ifeq ($(HW_EMU_INTERFACE_CLOCK_ID),1)
  ifneq ($(AXI_CLOCK_HZ),$(HW_EMU_GT_CLOCK_HZ))
    $(error split-clock hw_emu requires AXI_CLOCK_HZ to equal HW_EMU_GT_CLOCK_HZ)
  endif
endif

# AXI_CLOCK_HZ is the selected AXI-Stream data clock. In split-clock hw_emu,
# clock 0 remains at 300 MHz for HLS and AXI-Lite control while clock 1 drives
# both the AXI-Stream interfaces and the GT stub.
# --kernel_frequency uses MHz.
AXI_CLOCK_MHZ := $(shell awk 'BEGIN { printf "%.6f", $(AXI_CLOCK_HZ) / 1000000 }')
HW_EMU_GT_CLOCK_MHZ := $(shell awk 'BEGIN { printf "%.6f", $(HW_EMU_GT_CLOCK_HZ) / 1000000 }')
ifeq ($(HW_EMU_CLOCKS),1)
  VPP_HW_EMU_CLOCK_FLAGS := --kernel_frequency "0:$(AXI_CLOCK_MHZ)"
else ifeq ($(HW_EMU_CLOCKS),2)
  ifeq ($(HW_EMU_INTERFACE_CLOCK_ID),1)
    VPP_HW_EMU_CLOCK_FLAGS := --kernel_frequency "0:300|1:$(HW_EMU_GT_CLOCK_MHZ)"
  else
    VPP_HW_EMU_CLOCK_FLAGS := --kernel_frequency "0:$(AXI_CLOCK_MHZ)|1:$(HW_EMU_GT_CLOCK_MHZ)"
  endif
else
  $(error HW_EMU_CLOCKS must be 1 or 2)
endif

MPICXX := mpic++

CXXFLAGS += -std=c++17 -Wall -g
CXXFLAGS += -I$(XILINX_XRT)/include
CXXFLAGS += $(AURORA_FLOW_INCLUDE)
CXXFLAGS += -fopenmp
LDFLAGS  := -L$(XILINX_XRT)/lib -lxrt_coreutil -luuid

VPP_HLSCFLAGS := --compile --platform $(PLATFORM) --target $(TARGET) --save-temps --debug \
                 -DDATA_WIDTH_BYTES=$(FIFO_WIDTH) -DUSE_FRAMING=$(USE_FRAMING)

VPP_LINKFLAGS := --link --optimize 3 --platform $(PLATFORM) --save-temps --debug

# Keep the selected frequency in the file name so changing AXI_CLOCK_HZ in
# an existing build directory cannot silently reuse a stale clock directive.
AURORA_AXI_CLOCK_CONFIG := $(BUILD_DIR)/aurora_flow_axi_clock_$(AXI_CLOCK_HZ)_data_clock_$(HW_INTERFACE_CLOCK_ID).cfg

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

$(AURORA_AXI_CLOCK_CONFIG): Makefile | $(BUILD_DIR)
	if [ $(HW_INTERFACE_CLOCK_ID) = 1 ]; then \
		printf '[clock]\nfreqHz=300000000:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\nfreqHz=%s:aurora_flow_0.ap_clk_2,aurora_flow_1.ap_clk_2\n' \
		       '$(AXI_CLOCK_HZ)' > $@; \
	else \
	printf '[clock]\nfreqHz=%s:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\n' \
	       '$(AXI_CLOCK_HZ)' > $@; \
	fi

# ---------------------------------------------------------------------------
# Linked xclbin (one rule per target execution mode)
# ---------------------------------------------------------------------------

# hw xclbin
$(BUILD_DIR)/aurora_flow_test_hw.xclbin: $(AURORA_FLOW_XOS_HW) \
                                          $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo \
                                          cfg/aurora_flow_test_hw.cfg \
	                                          $(AURORA_AXI_CLOCK_CONFIG) | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw \
	    --config cfg/aurora_flow_test_hw.cfg \
	    --config $(AURORA_AXI_CLOCK_CONFIG) \
	    --output $@ \
	    $(AURORA_FLOW_XOS_HW) $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo

# hw_emu xclbin (requires DPI-C source for xsim)
$(BUILD_DIR)/aurora_flow_test_hw_emu.xclbin: $(AURORA_FLOW_XOS_HW_EMU) \
                                              $(BUILD_DIR)/send_hw_emu.xo $(BUILD_DIR)/recv_hw_emu.xo \
                                              cfg/aurora_flow_test_hw_emu.cfg \
                                              $(AURORA_FLOW_DPI_SRC) | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw_emu $(VPP_HW_EMU_CLOCK_FLAGS) \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw_emu \
	    --config cfg/aurora_flow_test_hw_emu.cfg \
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
