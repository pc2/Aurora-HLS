#
# Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# AuroraFlow library build.
# Produces .xo kernels for three execution modes:
#   hw      : real Aurora GT transceiver
#   hw_emu  : RTL with DPI-C GT stub using named pipes
#   sw_emu  : HLS file-link kernel using named pipes
#
# Supports out-of-tree builds via BUILD_DIR override.
#

# Library source root (absolute path to this Makefile's directory)
AURORA_FLOW_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR       ?= $(AURORA_FLOW_DIR)/build

.PHONY: all aurora_hw aurora_hw_emu aurora_sw_emu clean

all: aurora_hw aurora_hw_emu aurora_sw_emu

# Aurora IP Core Version
AURORA_VERSION ?= 12.0

# Target board
PART     := xcu280-fsvh2892-2L-e
PLATFORM ?= xilinx_u280_gen3x16_xdma_1_202211_1

# Configuration parameters
INS_LOSS_NYQ := 8
RX_EQ_MODE := LPM
USE_FRAMING := 0
DRAIN_AXI_ON_RESET := 0

# Supported: 32 and 64
FIFO_WIDTH := 64

# Hardware normally exposes one scalable platform clock. Integrations that
# split the mandatory 300 MHz AXI-Lite control port from a faster AXI-Stream
# data path can place the latter on clock ID 1.
HW_INTERFACE_CLOCK_ID ?= 0
ifeq ($(filter $(HW_INTERFACE_CLOCK_ID),0 1),)
  $(error HW_INTERFACE_CLOCK_ID must be 0 or 1)
endif

# hw_emu can use the legacy single-clock kernel (1) or expose both scalable
# platform clocks (2).  By default the external interfaces remain on clock ID
# 0 and ap_clk_2 models the independent Aurora user clock.  Integrations that
# already place their data path on clock ID 1 can put the AXI-Stream side and
# GT stub there while AXI-Lite control remains on clock ID 0.
HW_EMU_CLOCKS ?= 2
HW_EMU_INTERFACE_CLOCK_ID ?= 0
ifeq ($(filter $(HW_EMU_CLOCKS),1 2),)
  $(error HW_EMU_CLOCKS must be 1 or 2)
endif
ifeq ($(filter $(HW_EMU_INTERFACE_CLOCK_ID),0 1),)
  $(error HW_EMU_INTERFACE_CLOCK_ID must be 0 or 1)
endif
ifeq ($(HW_EMU_CLOCKS):$(HW_EMU_INTERFACE_CLOCK_ID),1:1)
  $(error HW_EMU_INTERFACE_CLOCK_ID=1 requires HW_EMU_CLOCKS=2)
endif

ifeq ($(FIFO_WIDTH), 32)
	SKIP_DATAWIDTH_CONVERTER := 1
else
	SKIP_DATAWIDTH_CONVERTER := 0
endif

RX_FIFO_SIZE := 65536
RX_FIFO_DEPTH := $(shell echo $$(( $(RX_FIFO_SIZE) / $(FIFO_WIDTH) )))
RX_FIFO_PROG_FULL := $(shell echo $$(( $(RX_FIFO_DEPTH) / 2 )))
RX_FIFO_PROG_EMPTY := $(shell echo $$(( $(RX_FIFO_DEPTH) / 8 )))

TX_FIFO_SIZE := 8192
TX_FIFO_DEPTH := $(shell echo $$(( $(TX_FIFO_SIZE) / $(FIFO_WIDTH) )))
TX_FIFO_PROG_FULL := $(shell echo $$(( $(TX_FIFO_DEPTH) / 4 * 3 )))
TX_FIFO_PROG_EMPTY := $(shell echo $$(( $(TX_FIFO_DEPTH) / 4 )))

ifeq ($(USE_FRAMING), 1)
	HAS_TKEEP := 1
	HAS_TLAST := 1
else
	HAS_TKEEP := 0
	HAS_TLAST := 0
endif

# ---------------------------------------------------------------------------
# IP creation
#   The create_*_ip.tcl scripts write to ./ip_creation/ relative to CWD,
#   so we cd into $(BUILD_DIR) before invoking vivado.
# ---------------------------------------------------------------------------

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci: $(AURORA_FLOW_DIR)/tcl/create_aurora_ip.tcl | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/ip_creation
	rm -rf $(BUILD_DIR)/ip_creation/aurora_64b66b_0
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs $(PART) 0 $(INS_LOSS_NYQ) $(RX_EQ_MODE) $(USE_FRAMING) $(AURORA_VERSION)

$(BUILD_DIR)/ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci: $(AURORA_FLOW_DIR)/tcl/create_fifo_ip.tcl | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/ip_creation
	rm -rf $(BUILD_DIR)/ip_creation/axis_data_fifo_rx
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs $(PART) rx $(FIFO_WIDTH) $(RX_FIFO_DEPTH) $(RX_FIFO_PROG_FULL) $(RX_FIFO_PROG_EMPTY) $(HAS_TKEEP) $(HAS_TLAST)

$(BUILD_DIR)/ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci: $(AURORA_FLOW_DIR)/tcl/create_fifo_ip.tcl | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/ip_creation
	rm -rf $(BUILD_DIR)/ip_creation/axis_data_fifo_tx
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs $(PART) tx $(FIFO_WIDTH) $(TX_FIFO_DEPTH) $(TX_FIFO_PROG_FULL) $(TX_FIFO_PROG_EMPTY) $(HAS_TKEEP) $(HAS_TLAST)

$(BUILD_DIR)/ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci: $(AURORA_FLOW_DIR)/tcl/create_axis_dwidth_converter_ip.tcl | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/ip_creation
	rm -rf $(BUILD_DIR)/ip_creation/axis_dwidth_converter_rx
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs $(PART) rx $(FIFO_WIDTH) $(HAS_TKEEP) $(HAS_TLAST)

$(BUILD_DIR)/ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci: $(AURORA_FLOW_DIR)/tcl/create_axis_dwidth_converter_ip.tcl | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/ip_creation
	rm -rf $(BUILD_DIR)/ip_creation/axis_dwidth_converter_tx
	cd $(BUILD_DIR) && vivado -mode batch -source $< -tclargs $(PART) tx $(FIFO_WIDTH) $(HAS_TKEEP) $(HAS_TLAST)

# ---------------------------------------------------------------------------
# Verilog templating and define generation
# ---------------------------------------------------------------------------

$(BUILD_DIR)/rtl/aurora_flow_0.v: $(AURORA_FLOW_DIR)/rtl/aurora_flow.v.template.v
	mkdir -p $(BUILD_DIR)/rtl
	cp $< $@
	sed -i 's/@@@instance@@@/0/g' $@

$(BUILD_DIR)/rtl/aurora_flow_1.v: $(AURORA_FLOW_DIR)/rtl/aurora_flow.v.template.v
	mkdir -p $(BUILD_DIR)/rtl
	cp $< $@
	sed -i 's/@@@instance@@@/1/g' $@

$(BUILD_DIR)/rtl/hw_emu/aurora_flow_0.v: $(AURORA_FLOW_DIR)/rtl/aurora_flow.v.template.v
	mkdir -p $(BUILD_DIR)/rtl/hw_emu
	cp $< $@
	sed -i 's/@@@instance@@@/0/g' $@

$(BUILD_DIR)/rtl/hw_emu/aurora_flow_1.v: $(AURORA_FLOW_DIR)/rtl/aurora_flow.v.template.v
	mkdir -p $(BUILD_DIR)/rtl/hw_emu
	cp $< $@
	sed -i 's/@@@instance@@@/1/g' $@

# VPL compiles linked RTL kernels in a shared Verilog macro scope. Clear every
# optional setting first so another packaged kernel cannot select our layout.
$(BUILD_DIR)/rtl/aurora_flow_define.v: $(AURORA_FLOW_DIR)/Makefile
	mkdir -p $(BUILD_DIR)/rtl
	printf '%s\n' \
		"\`undef AURORA_FLOW_IO_MODULE" \
		"\`undef AURORA_FLOW_AXIS_DATA_FIFO_RX_MODULE" \
		"\`undef AURORA_FLOW_AXIS_DATA_FIFO_TX_MODULE" \
		"\`undef AURORA_FLOW_AXIS_DWIDTH_CONVERTER_RX_MODULE" \
		"\`undef AURORA_FLOW_AXIS_DWIDTH_CONVERTER_TX_MODULE" \
		"\`undef FIFO_WIDTH" \
		"\`undef USE_FRAMING" \
		"\`undef SKIP_DATAWIDTH_CONVERTER" \
		"\`undef DRAIN_AXI_ON_RESET" \
		"\`undef HAS_TKEEP" \
		"\`undef HAS_TLAST" \
		"\`undef RX_FIFO_DEPTH" \
		"\`undef RX_FIFO_PROG_FULL" \
		"\`undef RX_FIFO_PROG_EMPTY" \
		"\`undef RX_EQ_MODE" \
		"\`undef INS_LOSS_NYQ" > $@
	if [ $(USE_FRAMING) = 1 ]; then \
		echo "\`define USE_FRAMING" >> $@; \
	fi
	if [ $(DRAIN_AXI_ON_RESET) = 1 ]; then \
		echo "\`define DRAIN_AXI_ON_RESET" >> $@; \
	fi
	echo "\`define HAS_TKEEP $(HAS_TKEEP)" >> $@
	echo "\`define HAS_TLAST $(HAS_TKEEP)" >> $@
	echo "\`define FIFO_WIDTH $(FIFO_WIDTH)" >> $@
	if [ $(SKIP_DATAWIDTH_CONVERTER) = 1 ]; then \
		echo "\`define SKIP_DATAWIDTH_CONVERTER" >> $@; \
	fi
	echo "\`define RX_FIFO_DEPTH $(RX_FIFO_DEPTH)" >> $@
	echo "\`define RX_FIFO_PROG_FULL $(RX_FIFO_PROG_FULL)" >> $@
	echo "\`define RX_FIFO_PROG_EMPTY $(RX_FIFO_PROG_EMPTY)" >> $@
	echo "\`define RX_EQ_MODE \"$(RX_EQ_MODE)\"" >> $@
	echo "\`define INS_LOSS_NYQ $(INS_LOSS_NYQ)" >> $@

HW_EMU_CLOCK_LAYOUT_FILE := $(BUILD_DIR)/rtl/hw_emu/.clock-layout
HW_CLOCK_LAYOUT_FILE := $(BUILD_DIR)/rtl/hw/.clock-layout

.PHONY: FORCE
FORCE:

$(HW_EMU_CLOCK_LAYOUT_FILE): FORCE
	mkdir -p $(BUILD_DIR)/rtl/hw_emu
	printf '%s:%s\n' '$(HW_EMU_CLOCKS)' '$(HW_EMU_INTERFACE_CLOCK_ID)' > $@.tmp
	if ! cmp -s $@.tmp $@; then mv $@.tmp $@; else rm -f $@.tmp; fi

$(HW_CLOCK_LAYOUT_FILE): FORCE
	mkdir -p $(BUILD_DIR)/rtl/hw
	printf '%s\n' '$(HW_INTERFACE_CLOCK_ID)' > $@.tmp
	if ! cmp -s $@.tmp $@; then mv $@.tmp $@; else rm -f $@.tmp; fi

$(BUILD_DIR)/rtl/hw/aurora_flow_define.v: $(BUILD_DIR)/rtl/aurora_flow_define.v $(HW_CLOCK_LAYOUT_FILE)
	mkdir -p $(BUILD_DIR)/rtl/hw
	cp $< $@
	if [ $(HW_INTERFACE_CLOCK_ID) = 1 ]; then \
		echo "\`define AURORA_FLOW_SECONDARY_CLOCK" >> $@; \
		echo "\`define AURORA_FLOW_DATA_CLOCK_2" >> $@; \
	fi

$(BUILD_DIR)/rtl/hw_emu/aurora_flow_define.v: $(BUILD_DIR)/rtl/aurora_flow_define.v $(HW_EMU_CLOCK_LAYOUT_FILE)
	mkdir -p $(BUILD_DIR)/rtl/hw_emu
	cp $< $@
	echo "\`define HW_EMU" >> $@
	if [ $(HW_EMU_CLOCKS) = 2 ]; then \
		echo "\`define HW_EMU_TWO_CLOCKS" >> $@; \
		echo "\`define AURORA_FLOW_SECONDARY_CLOCK" >> $@; \
	fi
	if [ $(HW_EMU_INTERFACE_CLOCK_ID) = 1 ]; then \
		echo "\`define AURORA_FLOW_DATA_CLOCK_2" >> $@; \
	fi

# ---------------------------------------------------------------------------
# RTL source lists (for dependency tracking)
# ---------------------------------------------------------------------------

RTL_STATIC := $(AURORA_FLOW_DIR)/rtl/aurora_flow_control_s_axi.v \
              $(AURORA_FLOW_DIR)/rtl/aurora_flow_io.v \
              $(AURORA_FLOW_DIR)/rtl/aurora_flow_nfc.v \
              $(AURORA_FLOW_DIR)/rtl/aurora_flow_configuration.v \
              $(AURORA_FLOW_DIR)/rtl/aurora_flow_monitor.v

IP_COMMON := $(BUILD_DIR)/ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci \
             $(BUILD_DIR)/ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci \
             $(BUILD_DIR)/ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci \
             $(BUILD_DIR)/ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci

RTL_HW_SRC_0 := $(RTL_STATIC) \
                $(AURORA_FLOW_DIR)/rtl/aurora_flow_reset.v \
                $(BUILD_DIR)/rtl/aurora_flow_0.v \
                $(BUILD_DIR)/rtl/hw/aurora_flow_define.v \
                $(BUILD_DIR)/ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci \
                $(IP_COMMON) \
                $(AURORA_FLOW_DIR)/xdc/aurora_64b66b_0.xdc

RTL_HW_SRC_1 := $(RTL_STATIC) \
                $(AURORA_FLOW_DIR)/rtl/aurora_flow_reset.v \
                $(BUILD_DIR)/rtl/aurora_flow_1.v \
                $(BUILD_DIR)/rtl/hw/aurora_flow_define.v \
                $(BUILD_DIR)/ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci \
                $(IP_COMMON) \
                $(AURORA_FLOW_DIR)/xdc/aurora_64b66b_1.xdc

RTL_HW_EMU_SRC_0 := $(RTL_STATIC) \
                    $(AURORA_FLOW_DIR)/rtl/aurora_flow_gt_stub.sv \
                    $(BUILD_DIR)/rtl/hw_emu/aurora_flow_0.v \
                    $(BUILD_DIR)/rtl/hw_emu/aurora_flow_define.v \
                    $(IP_COMMON)

RTL_HW_EMU_SRC_1 := $(RTL_STATIC) \
                    $(AURORA_FLOW_DIR)/rtl/aurora_flow_gt_stub.sv \
                    $(BUILD_DIR)/rtl/hw_emu/aurora_flow_1.v \
                    $(BUILD_DIR)/rtl/hw_emu/aurora_flow_define.v \
                    $(IP_COMMON)

# ---------------------------------------------------------------------------
# Kernel packaging (hw)
# ---------------------------------------------------------------------------

aurora_hw: $(BUILD_DIR)/aurora_flow_hw_0.xo $(BUILD_DIR)/aurora_flow_hw_1.xo

$(BUILD_DIR)/aurora_flow_hw_0.xo: $(RTL_HW_SRC_0) $(AURORA_FLOW_DIR)/tcl/pack_kernel.tcl
	rm -rf $(BUILD_DIR)/aurora_flow_hw_0_project
	mkdir -p $(BUILD_DIR)/aurora_flow_hw_0_project
	cd $(BUILD_DIR)/aurora_flow_hw_0_project && vivado -mode batch \
		-source $(AURORA_FLOW_DIR)/tcl/pack_kernel.tcl \
		-tclargs $(PART) 0 $(AURORA_FLOW_DIR) $(BUILD_DIR) \
		$(HW_INTERFACE_CLOCK_ID)

$(BUILD_DIR)/aurora_flow_hw_1.xo: $(RTL_HW_SRC_1) $(AURORA_FLOW_DIR)/tcl/pack_kernel.tcl
	rm -rf $(BUILD_DIR)/aurora_flow_hw_1_project
	mkdir -p $(BUILD_DIR)/aurora_flow_hw_1_project
	cd $(BUILD_DIR)/aurora_flow_hw_1_project && vivado -mode batch \
		-source $(AURORA_FLOW_DIR)/tcl/pack_kernel.tcl \
		-tclargs $(PART) 1 $(AURORA_FLOW_DIR) $(BUILD_DIR) \
		$(HW_INTERFACE_CLOCK_ID)

# ---------------------------------------------------------------------------
# Kernel packaging (hw_emu)
# ---------------------------------------------------------------------------

aurora_hw_emu: $(BUILD_DIR)/aurora_flow_hw_emu_0.xo $(BUILD_DIR)/aurora_flow_hw_emu_1.xo

$(BUILD_DIR)/aurora_flow_hw_emu_0.xo: $(RTL_HW_EMU_SRC_0) $(AURORA_FLOW_DIR)/tcl/pack_kernel_hw_emu.tcl
	rm -rf $(BUILD_DIR)/aurora_flow_hw_emu_0_project
	mkdir -p $(BUILD_DIR)/aurora_flow_hw_emu_0_project
	cd $(BUILD_DIR)/aurora_flow_hw_emu_0_project && vivado -mode batch \
		-source $(AURORA_FLOW_DIR)/tcl/pack_kernel_hw_emu.tcl \
		-tclargs $(PART) 0 $(AURORA_FLOW_DIR) $(BUILD_DIR) $(HW_EMU_CLOCKS) \
		$(HW_EMU_INTERFACE_CLOCK_ID)

$(BUILD_DIR)/aurora_flow_hw_emu_1.xo: $(RTL_HW_EMU_SRC_1) $(AURORA_FLOW_DIR)/tcl/pack_kernel_hw_emu.tcl
	rm -rf $(BUILD_DIR)/aurora_flow_hw_emu_1_project
	mkdir -p $(BUILD_DIR)/aurora_flow_hw_emu_1_project
	cd $(BUILD_DIR)/aurora_flow_hw_emu_1_project && vivado -mode batch \
		-source $(AURORA_FLOW_DIR)/tcl/pack_kernel_hw_emu.tcl \
		-tclargs $(PART) 1 $(AURORA_FLOW_DIR) $(BUILD_DIR) $(HW_EMU_CLOCKS) \
		$(HW_EMU_INTERFACE_CLOCK_ID)

# ---------------------------------------------------------------------------
# HLS kernel packaging (sw_emu)
# ---------------------------------------------------------------------------

aurora_sw_emu: $(BUILD_DIR)/aurora_flow_sw_emu.xo

SW_EMU_LAYOUT_FILE := $(BUILD_DIR)/.aurora_flow_sw_emu_layout

$(SW_EMU_LAYOUT_FILE): FORCE | $(BUILD_DIR)
	printf '%s:%s:%s\n' '$(PLATFORM)' '$(FIFO_WIDTH)' '$(USE_FRAMING)' > $@.tmp
	if ! cmp -s $@.tmp $@; then mv $@.tmp $@; else rm -f $@.tmp; fi

$(BUILD_DIR)/aurora_flow_sw_emu.xo: $(AURORA_FLOW_DIR)/hls/aurora_flow_sw_emu.cpp $(SW_EMU_LAYOUT_FILE) | $(BUILD_DIR)
	v++ --compile --platform $(PLATFORM) --target sw_emu --save-temps --debug \
	    -DDATA_WIDTH_BYTES=$(FIFO_WIDTH) \
	    -DUSE_FRAMING=$(USE_FRAMING) \
	    --temp_dir $(BUILD_DIR)/_x_aurora_flow_sw_emu \
	    --kernel aurora_flow_sw_emu --output $@ $<

# ---------------------------------------------------------------------------
# Verilog testbenches (run from CWD, use xsim.dir locally)
# ---------------------------------------------------------------------------

.PHONY: monitor_tb run_monitor_tb run_monitor_tb_gui

xsim.dir/work/aurora_flow_monitor.sdb: $(AURORA_FLOW_DIR)/rtl/aurora_flow_monitor.v
	xvlog $< -d XSIM -d USE_FRAMING

xsim.dir/work/aurora_flow_monitor_tb.sdb: $(AURORA_FLOW_DIR)/rtl/tb/aurora_flow_monitor_tb.v
	xvlog $< -d XSIM -d USE_FRAMING

xsim.dir/monitor_tb/xsimk: xsim.dir/work/aurora_flow_monitor.sdb xsim.dir/work/aurora_flow_monitor_tb.sdb
	xelab -debug typical aurora_flow_monitor_tb -s monitor_tb -d USE_FRAMING

monitor_tb: xsim.dir/monitor_tb/xsimk

run_monitor_tb: monitor_tb
	xsim --tclbatch $(AURORA_FLOW_DIR)/tcl/run_monitor_tb.tcl monitor_tb --wdb monitor_tb.wdb

run_monitor_tb_gui: monitor_tb
	xsim --gui monitor_tb

.PHONY: nfc_tb run_nfc_tb run_nfc_tb_gui

xsim.dir/work/aurora_flow_nfc.sdb: $(AURORA_FLOW_DIR)/rtl/aurora_flow_nfc.v
	xvlog $< -d XSIM

xsim.dir/work/aurora_flow_nfc_tb.sdb: $(AURORA_FLOW_DIR)/rtl/tb/aurora_flow_nfc_tb.v
	xvlog $< -d XSIM

xsim.dir/nfc_tb/xsimk: xsim.dir/work/aurora_flow_nfc.sdb xsim.dir/work/aurora_flow_nfc_tb.sdb
	xelab -debug typical aurora_flow_nfc_tb -s nfc_tb

nfc_tb: xsim.dir/nfc_tb/xsimk

run_nfc_tb: nfc_tb
	xsim --tclbatch $(AURORA_FLOW_DIR)/tcl/run_nfc_tb.tcl nfc_tb --wdb nfc_tb.wdb

run_nfc_tb_gui: nfc_tb
	xsim --gui nfc_tb

.PHONY: configuration_tb run_configuration_tb run_configuration_tb_gui

xsim.dir/work/aurora_flow_configuration.sdb: $(AURORA_FLOW_DIR)/rtl/aurora_flow_configuration.v $(BUILD_DIR)/rtl/aurora_flow_define.v
	xvlog $(AURORA_FLOW_DIR)/rtl/aurora_flow_configuration.v -i $(BUILD_DIR)/rtl

xsim.dir/work/aurora_flow_configuration_tb.sdb: $(AURORA_FLOW_DIR)/rtl/tb/aurora_flow_configuration_tb.v
	xvlog $<

xsim.dir/configuration_tb/xsimk: xsim.dir/work/aurora_flow_configuration.sdb xsim.dir/work/aurora_flow_configuration_tb.sdb
	xelab -debug typical aurora_flow_configuration_tb -s configuration_tb

configuration_tb: xsim.dir/configuration_tb/xsimk

run_configuration_tb: configuration_tb
	xsim --tclbatch $(AURORA_FLOW_DIR)/tcl/run_configuration_tb.tcl configuration_tb --wdb configuration_tb.wdb

run_configuration_tb_gui: configuration_tb
	xsim --gui configuration_tb

.PHONY: control_s_axi_tb run_control_s_axi_tb run_control_s_axi_tb_gui

xsim.dir/work/aurora_flow_control_s_axi.sdb: $(AURORA_FLOW_DIR)/rtl/aurora_flow_control_s_axi.v $(BUILD_DIR)/rtl/aurora_flow_define.v
	xvlog $(AURORA_FLOW_DIR)/rtl/aurora_flow_control_s_axi.v -i $(BUILD_DIR)/rtl

xsim.dir/work/aurora_flow_control_s_axi_tb.sdb: $(AURORA_FLOW_DIR)/rtl/tb/aurora_flow_control_s_axi_tb.v
	xvlog $<

xsim.dir/control_s_axi_tb/xsimk: xsim.dir/work/aurora_flow_control_s_axi.sdb xsim.dir/work/aurora_flow_control_s_axi_tb.sdb
	xelab -mt 4 -timescale 1ns/1ps -debug typical aurora_flow_control_s_axi_tb -s control_s_axi_tb

control_s_axi_tb: xsim.dir/control_s_axi_tb/xsimk

run_control_s_axi_tb: control_s_axi_tb
	xsim --tclbatch $(AURORA_FLOW_DIR)/tcl/run_control_s_axi_tb.tcl control_s_axi_tb --wdb control_s_axi_tb.wdb

run_control_s_axi_tb_gui: control_s_axi_tb
	xsim --gui control_s_axi_tb

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------

clean:
	git clean -Xdf
