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
PART     ?= xcu280-fsvh2892-2L-e
TARGET   ?= hw
FIFO_WIDTH ?= 64
HLS_WIDTH ?= $(FIFO_WIDTH)
HLS_CLOCK_HZ ?= 300000000
AXI_CLOCK_HZ ?= 300000000
HW_INTERFACE_CLOCK_ID ?= 0
HW_EMU_GT_CLOCK_HZ ?= 402800000
HW_EMU_CLOCKS ?= 2
HW_EMU_INTERFACE_CLOCK_ID ?= 0
CLOCK_BRIDGE ?= 0
VPP_DEBUG ?= 0

ifeq ($(filter $(CLOCK_BRIDGE),0 1),)
  $(error CLOCK_BRIDGE must be 0 or 1)
endif
ifeq ($(filter $(VPP_DEBUG),0 1),)
  $(error VPP_DEBUG must be 0 or 1)
endif

ifeq ($(HW_EMU_CLOCKS):$(HW_EMU_INTERFACE_CLOCK_ID),1:1)
  $(error HW_EMU_INTERFACE_CLOCK_ID=1 requires HW_EMU_CLOCKS=2)
endif
ifeq ($(HW_EMU_INTERFACE_CLOCK_ID),1)
  ifneq ($(AXI_CLOCK_HZ),$(HW_EMU_GT_CLOCK_HZ))
    $(error split-clock hw_emu requires AXI_CLOCK_HZ to equal HW_EMU_GT_CLOCK_HZ)
  endif
endif
ifeq ($(CLOCK_BRIDGE),1)
  ifeq ($(TARGET),hw)
    ifneq ($(HW_INTERFACE_CLOCK_ID),1)
      $(error CLOCK_BRIDGE=1 with TARGET=hw requires HW_INTERFACE_CLOCK_ID=1)
    endif
  else ifeq ($(TARGET),hw_emu)
    ifneq ($(HW_EMU_CLOCKS),2)
      $(error CLOCK_BRIDGE=1 with TARGET=hw_emu requires HW_EMU_CLOCKS=2)
    endif
    ifneq ($(HW_EMU_INTERFACE_CLOCK_ID),1)
      $(error CLOCK_BRIDGE=1 with TARGET=hw_emu requires HW_EMU_INTERFACE_CLOCK_ID=1)
    endif
  else
    $(error CLOCK_BRIDGE=1 is supported only for TARGET=hw or TARGET=hw_emu)
  endif
  ifneq ($(AXI_CLOCK_HZ),400000000)
    $(error CLOCK_BRIDGE=1 requires AXI_CLOCK_HZ=400000000)
  endif
  ifneq ($(FIFO_WIDTH),32)
    $(error CLOCK_BRIDGE=1 requires FIFO_WIDTH=32 for the 256-bit AuroraFlow side)
  endif
  ifneq ($(HLS_WIDTH),64)
    $(error CLOCK_BRIDGE=1 requires HLS_WIDTH=64 for the 512-bit HLS side)
  endif
  ifneq ($(HLS_CLOCK_HZ),300000000)
    $(error CLOCK_BRIDGE=1 requires HLS_CLOCK_HZ=300000000)
  endif
endif

# AXI_CLOCK_HZ is the selected AXI-Stream data clock. In split-clock hw_emu,
# clock 0 remains at 300 MHz for HLS and AXI-Lite control while clock 1 drives
# the AuroraFlow AXI-Stream interfaces and GT stub. The optional clock bridge
# provides explicit CDC and 512/256-bit conversion between those domains.
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

VPP_DEBUG_FLAGS :=
ifeq ($(VPP_DEBUG),1)
  VPP_DEBUG_FLAGS := --debug
endif

VPP_HLSCFLAGS := --compile --platform $(PLATFORM) --target $(TARGET) --save-temps $(VPP_DEBUG_FLAGS) \
                 -DDATA_WIDTH_BYTES=$(HLS_WIDTH) -DUSE_FRAMING=$(USE_FRAMING)

VPP_RECV_HLS_CLOCK_FLAGS :=
VPP_SEND_HLS_CLOCK_FLAGS :=
ifeq ($(CLOCK_BRIDGE),1)
  VPP_RECV_HLS_CLOCK_FLAGS := --hls.clock $(HLS_CLOCK_HZ):recv
  VPP_SEND_HLS_CLOCK_FLAGS := --hls.clock $(HLS_CLOCK_HZ):send
endif

VPP_LINKFLAGS := --link --optimize 3 --platform $(PLATFORM) --save-temps $(VPP_DEBUG_FLAGS)

# Keep the selected frequency in the file name so changing AXI_CLOCK_HZ in
# an existing build directory cannot silently reuse a stale clock directive.
AURORA_AXI_CLOCK_CONFIG := $(BUILD_DIR)/aurora_flow_axi_clock_$(AXI_CLOCK_HZ)_data_clock_$(HW_INTERFACE_CLOCK_ID)_bridge_$(CLOCK_BRIDGE).cfg

all: host xclbin

$(BUILD_DIR):
	mkdir -p $@

# ---------------------------------------------------------------------------
# Application HLS kernels
# ---------------------------------------------------------------------------

HLS_LAYOUT_FILE := $(BUILD_DIR)/.hls_$(TARGET)_layout

.PHONY: HLS_LAYOUT_FORCE
HLS_LAYOUT_FORCE:

$(HLS_LAYOUT_FILE): HLS_LAYOUT_FORCE | $(BUILD_DIR)
	printf '%s:%s:%s:%s:%s:%s\n' \
	    '$(PLATFORM)' '$(HLS_WIDTH)' '$(USE_FRAMING)' \
	    '$(HLS_CLOCK_HZ)' '$(CLOCK_BRIDGE)' '$(VPP_DEBUG)' > $@.tmp
	if ! cmp -s $@.tmp $@; then mv $@.tmp $@; else rm -f $@.tmp; fi

$(BUILD_DIR)/recv_$(TARGET).xo: hls/recv.cpp $(HLS_LAYOUT_FILE) | $(BUILD_DIR)
	v++ $(VPP_HLSCFLAGS) $(VPP_RECV_HLS_CLOCK_FLAGS) --temp_dir $(BUILD_DIR)/_x_recv_$(TARGET) --kernel recv --output $@ $<

$(BUILD_DIR)/send_$(TARGET).xo: hls/send.cpp $(HLS_LAYOUT_FILE) | $(BUILD_DIR)
	v++ $(VPP_HLSCFLAGS) $(VPP_SEND_HLS_CLOCK_FLAGS) --temp_dir $(BUILD_DIR)/_x_send_$(TARGET) --kernel send --output $@ $<

$(AURORA_AXI_CLOCK_CONFIG): Makefile | $(BUILD_DIR)
	if [ $(HW_INTERFACE_CLOCK_ID) = 1 ]; then \
		if [ $(CLOCK_BRIDGE) = 1 ]; then \
			printf '[clock]\nfreqHz=%s:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk,clock_bridge_0.ap_clk,clock_bridge_1.ap_clk\nfreqHz=%s:aurora_flow_0.ap_clk_2,aurora_flow_1.ap_clk_2,clock_bridge_0.ap_clk_2,clock_bridge_1.ap_clk_2\n' \
			       '$(HLS_CLOCK_HZ)' '$(AXI_CLOCK_HZ)' > $@; \
		else \
			printf '[clock]\nfreqHz=300000000:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\nfreqHz=%s:aurora_flow_0.ap_clk_2,aurora_flow_1.ap_clk_2\n' \
			       '$(AXI_CLOCK_HZ)' > $@; \
		fi; \
	else \
		printf '[clock]\nfreqHz=%s:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\n' \
		       '$(AXI_CLOCK_HZ)' > $@; \
	fi

# ---------------------------------------------------------------------------
# Line-rate split-clock bridge
# ---------------------------------------------------------------------------

CLOCK_BRIDGE_LAYOUT_FILE := $(BUILD_DIR)/rtl/clock_bridge/.layout
CLOCK_BRIDGE_DEFINE := $(BUILD_DIR)/rtl/clock_bridge/aurora_flow_clock_bridge_define.vh
CLOCK_BRIDGE_XO := $(BUILD_DIR)/aurora_flow_clock_bridge.xo

CLOCK_BRIDGE_RX_FIFO_SIZE := 65536
CLOCK_BRIDGE_RX_FIFO_DEPTH := $(shell echo $$(( $(CLOCK_BRIDGE_RX_FIFO_SIZE) / $(HLS_WIDTH) )))
CLOCK_BRIDGE_RX_FIFO_PROG_FULL := $(shell echo $$(( $(CLOCK_BRIDGE_RX_FIFO_DEPTH) / 2 )))
CLOCK_BRIDGE_RX_FIFO_PROG_EMPTY := $(shell echo $$(( $(CLOCK_BRIDGE_RX_FIFO_DEPTH) / 8 )))
CLOCK_BRIDGE_TX_FIFO_SIZE := 8192
CLOCK_BRIDGE_TX_FIFO_DEPTH := $(shell echo $$(( $(CLOCK_BRIDGE_TX_FIFO_SIZE) / $(HLS_WIDTH) )))
CLOCK_BRIDGE_TX_FIFO_PROG_FULL := $(shell echo $$(( $(CLOCK_BRIDGE_TX_FIFO_DEPTH) / 4 * 3 )))
CLOCK_BRIDGE_TX_FIFO_PROG_EMPTY := $(shell echo $$(( $(CLOCK_BRIDGE_TX_FIFO_DEPTH) / 4 )))

.PHONY: CLOCK_BRIDGE_FORCE
CLOCK_BRIDGE_FORCE:

$(CLOCK_BRIDGE_LAYOUT_FILE): CLOCK_BRIDGE_FORCE | $(BUILD_DIR)
	mkdir -p $(dir $@)
	printf '%s:%s:%s\n' '$(HLS_WIDTH)' '$(FIFO_WIDTH)' '$(USE_FRAMING)' > $@.tmp
	if ! cmp -s $@.tmp $@; then mv $@.tmp $@; else rm -f $@.tmp; fi

# The bridge and AuroraFlow share a VPL compilation. Reset the generic macros
# before selecting the bridge's 512-bit FIFO/DWC branch.
$(CLOCK_BRIDGE_DEFINE): $(CLOCK_BRIDGE_LAYOUT_FILE) Makefile
	mkdir -p $(dir $@)
	printf '%s\n' \
	    "\`undef AURORA_FLOW_IO_MODULE" \
	    "\`undef AURORA_FLOW_AXIS_DATA_FIFO_RX_MODULE" \
	    "\`undef AURORA_FLOW_AXIS_DATA_FIFO_TX_MODULE" \
	    "\`undef AURORA_FLOW_AXIS_DWIDTH_CONVERTER_RX_MODULE" \
	    "\`undef AURORA_FLOW_AXIS_DWIDTH_CONVERTER_TX_MODULE" \
	    "\`undef CLOCK_BRIDGE_HLS_WIDTH" \
	    "\`undef CLOCK_BRIDGE_AURORA_WIDTH" \
	    "\`undef FIFO_WIDTH" \
	    "\`undef USE_FRAMING" \
	    "\`undef SKIP_DATAWIDTH_CONVERTER" \
	    "\`define AURORA_FLOW_IO_MODULE aurora_flow_clock_bridge_io" \
	    "\`define AURORA_FLOW_AXIS_DATA_FIFO_RX_MODULE axis_data_fifo_clock_bridge_rx" \
	    "\`define AURORA_FLOW_AXIS_DATA_FIFO_TX_MODULE axis_data_fifo_clock_bridge_tx" \
	    "\`define AURORA_FLOW_AXIS_DWIDTH_CONVERTER_RX_MODULE axis_dwidth_converter_clock_bridge_rx" \
	    "\`define AURORA_FLOW_AXIS_DWIDTH_CONVERTER_TX_MODULE axis_dwidth_converter_clock_bridge_tx" \
	    "\`define CLOCK_BRIDGE_HLS_WIDTH $(HLS_WIDTH)" \
	    "\`define CLOCK_BRIDGE_AURORA_WIDTH $(FIFO_WIDTH)" \
	    "\`define FIFO_WIDTH $(HLS_WIDTH)" > $@
	if [ $(USE_FRAMING) = 1 ]; then printf '%s\n' "\`define USE_FRAMING" >> $@; fi

$(BUILD_DIR)/ip_creation/axis_data_fifo_clock_bridge_rx/axis_data_fifo_clock_bridge_rx.xci: \
    $(AURORA_FLOW_DIR)/tcl/create_fifo_ip.tcl $(CLOCK_BRIDGE_LAYOUT_FILE) | $(BUILD_DIR)
	rm -rf $(dir $@)
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs \
	    $(PART) clock_bridge_rx $(HLS_WIDTH) $(CLOCK_BRIDGE_RX_FIFO_DEPTH) \
	    $(CLOCK_BRIDGE_RX_FIFO_PROG_FULL) $(CLOCK_BRIDGE_RX_FIFO_PROG_EMPTY) \
	    $(USE_FRAMING) $(USE_FRAMING)

$(BUILD_DIR)/ip_creation/axis_data_fifo_clock_bridge_tx/axis_data_fifo_clock_bridge_tx.xci: \
    $(AURORA_FLOW_DIR)/tcl/create_fifo_ip.tcl $(CLOCK_BRIDGE_LAYOUT_FILE) | $(BUILD_DIR)
	rm -rf $(dir $@)
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs \
	    $(PART) clock_bridge_tx $(HLS_WIDTH) $(CLOCK_BRIDGE_TX_FIFO_DEPTH) \
	    $(CLOCK_BRIDGE_TX_FIFO_PROG_FULL) $(CLOCK_BRIDGE_TX_FIFO_PROG_EMPTY) \
	    $(USE_FRAMING) $(USE_FRAMING)

$(BUILD_DIR)/ip_creation/axis_dwidth_converter_clock_bridge_rx/axis_dwidth_converter_clock_bridge_rx.xci: \
    $(AURORA_FLOW_DIR)/tcl/create_axis_dwidth_converter_ip.tcl $(CLOCK_BRIDGE_LAYOUT_FILE) | $(BUILD_DIR)
	rm -rf $(dir $@)
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs \
	    $(PART) clock_bridge_rx $(HLS_WIDTH) $(USE_FRAMING) $(USE_FRAMING) \
	    $(FIFO_WIDTH) $(HLS_WIDTH)

$(BUILD_DIR)/ip_creation/axis_dwidth_converter_clock_bridge_tx/axis_dwidth_converter_clock_bridge_tx.xci: \
    $(AURORA_FLOW_DIR)/tcl/create_axis_dwidth_converter_ip.tcl $(CLOCK_BRIDGE_LAYOUT_FILE) | $(BUILD_DIR)
	rm -rf $(dir $@)
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs \
	    $(PART) clock_bridge_tx $(HLS_WIDTH) $(USE_FRAMING) $(USE_FRAMING) \
	    $(HLS_WIDTH) $(FIFO_WIDTH)

$(CLOCK_BRIDGE_XO): rtl/aurora_flow_clock_bridge.v \
                    $(AURORA_FLOW_DIR)/rtl/aurora_flow_io.v \
                    $(CLOCK_BRIDGE_DEFINE) \
                    $(BUILD_DIR)/ip_creation/axis_data_fifo_clock_bridge_rx/axis_data_fifo_clock_bridge_rx.xci \
                    $(BUILD_DIR)/ip_creation/axis_data_fifo_clock_bridge_tx/axis_data_fifo_clock_bridge_tx.xci \
                    $(BUILD_DIR)/ip_creation/axis_dwidth_converter_clock_bridge_rx/axis_dwidth_converter_clock_bridge_rx.xci \
                    $(BUILD_DIR)/ip_creation/axis_dwidth_converter_clock_bridge_tx/axis_dwidth_converter_clock_bridge_tx.xci \
                    tcl/pack_clock_bridge.tcl
	rm -rf $(BUILD_DIR)/aurora_flow_clock_bridge_project
	mkdir -p $(BUILD_DIR)/aurora_flow_clock_bridge_project
	cd $(BUILD_DIR)/aurora_flow_clock_bridge_project && vivado -mode batch \
	    -source $(CURDIR)/tcl/pack_clock_bridge.tcl \
	    -tclargs $(PART) $(AURORA_FLOW_DIR) $(BUILD_DIR)

HW_CONNECTIVITY_CONFIG := cfg/aurora_flow_test_hw.cfg
HW_EMU_CONNECTIVITY_CONFIG := cfg/aurora_flow_test_hw_emu.cfg
CLOCK_BRIDGE_EXTRA_XOS :=
ifeq ($(CLOCK_BRIDGE),1)
  HW_CONNECTIVITY_CONFIG := cfg/aurora_flow_test_clock_bridge_hw.cfg
  HW_EMU_CONNECTIVITY_CONFIG := cfg/aurora_flow_test_clock_bridge.cfg
  CLOCK_BRIDGE_EXTRA_XOS := $(CLOCK_BRIDGE_XO)
endif

# ---------------------------------------------------------------------------
# Linked xclbin (one rule per target execution mode)
# ---------------------------------------------------------------------------

# The debug setting changes the instrumentation embedded in the xclbin. Keep
# it in the prerequisite name so toggling VPP_DEBUG forces a relink in-place.
VPP_LINK_MODE_FILE := $(BUILD_DIR)/.vpp_$(TARGET)_debug_$(VPP_DEBUG)

$(VPP_LINK_MODE_FILE): | $(BUILD_DIR)
	printf '%s\n' '$(VPP_DEBUG)' > $@

# hw xclbin
$(BUILD_DIR)/aurora_flow_test_hw.xclbin: $(AURORA_FLOW_XOS_HW) \
                                          $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo \
	                                          $(HW_CONNECTIVITY_CONFIG) \
	                                          $(CLOCK_BRIDGE_EXTRA_XOS) \
	                                          $(AURORA_AXI_CLOCK_CONFIG) $(VPP_LINK_MODE_FILE) Makefile | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw \
	    --config $(HW_CONNECTIVITY_CONFIG) \
	    --config $(AURORA_AXI_CLOCK_CONFIG) \
	    --output $@ \
	    $(AURORA_FLOW_XOS_HW) $(CLOCK_BRIDGE_EXTRA_XOS) \
	    $(BUILD_DIR)/send_hw.xo $(BUILD_DIR)/recv_hw.xo

# hw_emu xclbin (requires DPI-C source for xsim)
$(BUILD_DIR)/aurora_flow_test_hw_emu.xclbin: $(AURORA_FLOW_XOS_HW_EMU) \
                                              $(BUILD_DIR)/send_hw_emu.xo $(BUILD_DIR)/recv_hw_emu.xo \
                                              $(HW_EMU_CONNECTIVITY_CONFIG) \
	                                              $(CLOCK_BRIDGE_EXTRA_XOS) \
	                                              $(AURORA_FLOW_DPI_SRC) $(VPP_LINK_MODE_FILE) Makefile | $(BUILD_DIR)
	v++ $(VPP_LINKFLAGS) --target hw_emu $(VPP_HW_EMU_CLOCK_FLAGS) \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_test_hw_emu \
	    --config $(HW_EMU_CONNECTIVITY_CONFIG) \
	    --vivado.prop "fileset.sim_1.{xsim.compile.xsc.more_options}={$(AURORA_FLOW_DPI_SRC)}" \
	    --output $@ \
	    $(AURORA_FLOW_XOS_HW_EMU) $(CLOCK_BRIDGE_EXTRA_XOS) \
	    $(BUILD_DIR)/send_hw_emu.xo $(BUILD_DIR)/recv_hw_emu.xo

# sw_emu xclbin
$(BUILD_DIR)/aurora_flow_test_sw_emu.xclbin: $(AURORA_FLOW_XO_SW_EMU) \
                                              $(BUILD_DIR)/send_sw_emu.xo $(BUILD_DIR)/recv_sw_emu.xo \
	                                              cfg/aurora_flow_test_sw_emu.cfg $(VPP_LINK_MODE_FILE) Makefile | $(BUILD_DIR)
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
