#
# Copyright 2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

ECHO=@echo

.PHONY: aurora host xclbin clean

# most important target
aurora: aurora_flow_0.xo aurora_flow_1.xo

CXX=c++
MPICXX=mpic++

# change here to test different boards
PART := xcu280-fsvh2892-2L-e
PLATFORM ?= xilinx_u280_gen3x16_xdma_1_202211_1

TARGET := hw

# configuration parameters
INS_LOSS_NYQ := 8
RX_EQ_MODE := LPM
USE_FRAMING := 0
DRAIN_AXI_ON_RESET := 0

#supported is 32 and 64
FIFO_WIDTH := 64

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

# create the ips
./ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci: ./tcl/create_aurora_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/aurora_64b66b_0
	vivado -mode batch -source $^ -tclargs $(PART) 0 $(INS_LOSS_NYQ) $(RX_EQ_MODE) $(USE_FRAMING)

./ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci: ./tcl/create_fifo_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/axis_data_fifo_rx
	vivado -mode batch -source $^ -tclargs $(PART) rx $(FIFO_WIDTH) $(RX_FIFO_DEPTH) $(RX_FIFO_PROG_FULL) $(RX_FIFO_PROG_EMPTY) $(HAS_TKEEP) $(HAS_TLAST)

./ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci: ./tcl/create_fifo_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/axis_data_fifo_tx
	vivado -mode batch -source $^ -tclargs $(PART) tx $(FIFO_WIDTH) $(TX_FIFO_DEPTH) $(TX_FIFO_PROG_FULL) $(TX_FIFO_PROG_EMPTY) $(HAS_TKEEP) $(HAS_TLAST)

./ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci: ./tcl/create_axis_dwidth_converter_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/axis_dwidth_converter_rx
	vivado -mode batch -source $^ -tclargs $(PART) rx $(FIFO_WIDTH) $(HAS_TKEEP) $(HAS_TLAST)

./ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci: ./tcl/create_axis_dwidth_converter_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/axis_dwidth_converter_tx
	vivado -mode batch -source $^ -tclargs $(PART) tx $(FIFO_WIDTH) $(HAS_TKEEP) $(HAS_TLAST)

./ip_creation/ila_nfc/ila_nfc.xci: ./tcl/create_ila_nfc_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/ila_nfc
	vivado -mode batch -source $^ -tclargs $(PART)

# synth flags
COMMFLAGS := --platform $(PLATFORM) --target $(TARGET) --save-temps --debug
HLSCFLAGS := --compile $(COMMFLAGS) -DDATA_WIDTH_BYTES=$(FIFO_WIDTH)
LINKFLAGS := --link --optimize 3 $(COMMFLAGS)

# collect the RTL source code
RTL_SRC := ./rtl/aurora_flow_control_s_axi.v
RTL_SRC += ./rtl/aurora_flow_io.v
RTL_SRC += ./rtl/aurora_flow_nfc.v
RTL_SRC += ./rtl/aurora_flow_define.v
RTL_SRC += ./rtl/aurora_flow_configuration.v
RTL_SRC += ./rtl/aurora_flow_reset.v
RTL_SRC += ./rtl/aurora_flow_monitor.v
RTL_SRC += ./ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci 
RTL_SRC += ./ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci
RTL_SRC += ./ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci
RTL_SRC += ./ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci
RTL_SRC += ./ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci

RTL_SRC_0 := $(RTL_SRC) ./rtl/aurora_flow_0.v ./xdc/aurora_64b66b_0.xdc
RTL_SRC_1 := $(RTL_SRC) ./rtl/aurora_flow_1.v ./xdc/aurora_64b66b_1.xdc

# some verilog templating
./rtl/aurora_flow_0.v: ./rtl/aurora_flow.v.template.v
	cp ./rtl/aurora_flow.v.template.v ./rtl/aurora_flow_0.v
	sed -i 's/@@@instance@@@/0/g' ./rtl/aurora_flow_0.v

./rtl/aurora_flow_1.v: ./rtl/aurora_flow.v.template.v
	cp ./rtl/aurora_flow.v.template.v ./rtl/aurora_flow_1.v
	sed -i 's/@@@instance@@@/1/g' ./rtl/aurora_flow_1.v

./rtl/aurora_flow_define.v:
	echo "" > $@
	if [ $(USE_FRAMING) = 1 ]; then \
		echo "\`define USE_FRAMING" >> $@; \
	fi
	if [ $(DRAIN_AXI_ON_RESET) = 1 ]; then \
		echo "\`define DRAIN_AXI_ON_RESET" >> $@; \
	fi
	echo "\`define HAS_TKEEP $(HAS_TKEEP)" >> $@
	echo "\`define HAS_TLAST $(HAS_TKEEP)" >> $@
	echo "\`define FIFO_WIDTH $(FIFO_WIDTH)" >> $@
	if [ $(SKIP_DATAWIDTH_CONVERTER = 1) ]; then \
		echo "\`define SKIP_DATAWIDTH_CONVERTER" >> $@; \
	fi
	echo "\`define RX_FIFO_DEPTH $(RX_FIFO_DEPTH)" >> $@
	echo "\`define RX_FIFO_PROG_FULL $(RX_FIFO_PROG_FULL)" >> $@
	echo "\`define RX_FIFO_PROG_EMPTY $(RX_FIFO_PROG_EMPTY)" >> $@
	echo "\`define RX_EQ_MODE \"$(RX_EQ_MODE)\"" >> $@
	echo "\`define INS_LOSS_NYQ $(INS_LOSS_NYQ)" >> $@

aurora_flow_0.xo: $(RTL_SRC_0) ./tcl/pack_kernel.tcl
	rm -rf aurora_flow_0_project
	mkdir aurora_flow_0_project
	cd aurora_flow_0_project && vivado -mode batch -source ../tcl/pack_kernel.tcl -tclargs $(PART) 0

aurora_flow_1.xo: $(RTL_SRC_1) ./tcl/pack_kernel.tcl
	rm -rf aurora_flow_1_project
	mkdir aurora_flow_1_project
	cd aurora_flow_1_project && vivado -mode batch -source ../tcl/pack_kernel.tcl -tclargs $(PART) 1

# build example bitstream
recv_$(TARGET).xo: ./hls/recv.cpp
	v++ $(HLSCFLAGS) --temp_dir _x_recv --kernel recv --output $@ $^

send_$(TARGET).xo: ./hls/send.cpp
	v++ $(HLSCFLAGS) --temp_dir _x_send --kernel send --output $@ $^
	
send_recv_$(TARGET).xo: ./hls/send_recv.cpp
	v++ $(HLSCFLAGS) --temp_dir _x_send_recv --kernel send_recv --output $@ $^
	
aurora_flow_test_hw.xclbin: aurora send_$(TARGET).xo recv_$(TARGET).xo aurora_flow_test_$(TARGET).cfg
	v++ $(LINKFLAGS) --temp_dir _x_aurora_flow_test_$(TARGET) --config aurora_flow_test_$(TARGET).cfg --output $@ aurora_flow_0.xo aurora_flow_1.xo recv_$(TARGET).xo send_$(TARGET).xo

aurora_flow_ring_hw.xclbin: aurora send_recv_$(TARGET).xo aurora_flow_ring_$(TARGET).cfg
	v++ $(LINKFLAGS) --temp_dir _x_aurora_flow_ring_$(TARGET) --config aurora_flow_ring_$(TARGET).cfg --output $@ aurora_flow_0.xo aurora_flow_1.xo send_recv_$(TARGET).xo

aurora_flow_test_sw_emu_loopback.xclbin: send_$(TARGET).xo recv_$(TARGET).xo aurora_flow_test_$(TARGET)_loopback.cfg
	v++ $(LINKFLAGS) --temp_dir _x_aurora_flow_$(TARGET) --config aurora_flow_test_$(TARGET)_loopback.cfg --output $@ recv_$(TARGET).xo send_$(TARGET).xo

xclbin : aurora_flow_test_$(TARGET).xclbin

xclbin_emu: aurora_flow_test_$(TARGET)_loopback.xclbin

# host build for example
CXXFLAGS += -std=c++17 -Wall -g
CXXFLAGS += -I$(XILINX_XRT)/include -I./cxxopts/include
CXXFLAGS += -fopenmp
LDFLAGS := -L$(XILINX_XRT)/lib
LDFLAGS += $(LDFLAGS) -lxrt_coreutil -luuid

host_aurora_flow_test: ./host/host_aurora_flow_test.cpp ./host/Aurora.hpp ./host/Results.hpp ./host/Configuration.hpp ./host/Kernel.hpp
	$(CXX) -o host_aurora_flow_test $< $(CXXFLAGS) $(LDFLAGS)

host_aurora_flow_ring: ./host/host_aurora_flow_ring.cpp ./host/Aurora.hpp ./host/Results.hpp ./host/Configuration.hpp ./host/Kernel.hpp
	$(MPICXX) -o host_aurora_flow_ring $< $(CXXFLAGS) $(LDFLAGS)


host: host_aurora_flow_test host_aurora_flow_ring

# verilog testbenches

.PHONY: monitor_tb run_monitor_tb run_monitor_tb_gui

xsim.dir/work/aurora_flow_monitor.sdb: ./rtl/aurora_flow_monitor.v
	xvlog ./rtl/aurora_flow_monitor.v -d XSIM -d USE_FRAMING

xsim.dir/work/aurora_flow_monitor_tb.sdb: ./rtl/aurora_flow_monitor_tb.v
	xvlog ./rtl/aurora_flow_monitor_tb.v -d XSIM -d USE_FRAMING

xsim.dir/monitor_tb/xsimk: xsim.dir/work/aurora_flow_monitor.sdb xsim.dir/work/aurora_flow_monitor_tb.sdb
	xelab -debug typical aurora_flow_monitor_tb -s monitor_tb -d USE_FRAMING

monitor_tb: xsim.dir/monitor_tb/xsimk

run_monitor_tb: monitor_tb
	xsim --tclbatch tcl/run_monitor_tb.tcl monitor_tb --wdb monitor_tb.wdb

run_monitor_tb_gui: monitor_tb
	xsim --gui monitor_tb

.PHONY: nfc_tb run_nfc_tb run_nfc_tb_gui

xsim.dir/work/aurora_flow_nfc.sdb: ./rtl/aurora_flow_nfc.v
	xvlog ./rtl/aurora_flow_nfc.v -d XSIM

xsim.dir/work/aurora_flow_nfc_tb.sdb: ./rtl/aurora_flow_nfc_tb.v
	xvlog ./rtl/aurora_flow_nfc_tb.v -d XSIM

xsim.dir/nfc_tb/xsimk: xsim.dir/work/aurora_flow_nfc.sdb xsim.dir/work/aurora_flow_nfc_tb.sdb
	xelab -debug typical aurora_flow_nfc_tb -s nfc_tb

nfc_tb: xsim.dir/nfc_tb/xsimk

run_nfc_tb: nfc_tb
	xsim --tclbatch tcl/run_nfc_tb.tcl nfc_tb --wdb nfc_tb.wdb

run_nfc_tb_gui: nfc_tb
	xsim --gui nfc_tb

.PHONY: configuration_tb run_configuration_tb run_configuration_tb_gui

xsim.dir/work/aurora_flow_configuration.sdb: ./rtl/aurora_flow_configuration.v ./rtl/aurora_flow_define.v
	xvlog ./rtl/aurora_flow_configuration.v

xsim.dir/work/aurora_flow_configuration_tb.sdb: ./rtl/aurora_flow_configuration_tb.v
	xvlog ./rtl/aurora_flow_configuration_tb.v

xsim.dir/configuration_tb/xsimk: xsim.dir/work/aurora_flow_configuration.sdb xsim.dir/work/aurora_flow_configuration_tb.sdb
	xelab -debug typical aurora_flow_configuration_tb -s configuration_tb

configuration_tb: xsim.dir/configuration_tb/xsimk

run_configuration_tb: configuration_tb
	xsim --tclbatch tcl/run_configuration_tb.tcl configuration_tb --wdb configuration_tb.wdb

run_configuration_tb_gui: configuration_tb
	xsim --gui configuration_tb

# run test
test: host aurora_flow_test_sw_emu.xclbin
	XCL_EMULATION_MODE=sw_emu ./host_aurora_flow_test -p aurora_flow_test_sw_emu.xclbin

clean:
	git clean -Xdf
