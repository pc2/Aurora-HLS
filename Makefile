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
aurora: aurora_hls_0.xo aurora_hls_1.xo

CXX=mpicxx

# change here to test different boards
PART := xcu280-fsvh2892-2L-e
PLATFORM ?= xilinx_u280_gen3x16_xdma_1_202211_1

TARGET := hw

# configuration parameters
INS_LOSS_NYQ := 8
RX_EQ_MODE := LPM
USE_FRAMING := 0
DRAIN_AXI_ON_RESET := 1

FIFO_WIDTH := 64
RX_FIFO_DEPTH := 512
RX_FIFO_PROG_FULL := 384
RX_FIFO_PROG_EMPTY := 128

ifeq ($(USE_FRAMING), 1)
	HAS_TKEEP := 1
	HAS_TLAST := 1
else
	HAS_TKEEP := 0
	HAS_TLAST := 0
endif

PROBE_NFC := 1

PROBE_CRC_COUNTER := 1

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
	vivado -mode batch -source $^ -tclargs $(PART) tx $(FIFO_WIDTH) 128 96 32 $(HAS_TKEEP) $(HAS_TLAST)

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

./ip_creation/ila_crc_counter/ila_crc_counter.xci: ./tcl/create_ila_crc_counter_ip.tcl
	mkdir -p ip_creation
	rm -rf ip_creation/ila_crc_counter
	vivado -mode batch -source $^ -tclargs $(PART)

# synth flags
COMMFLAGS := --platform $(PLATFORM) --target $(TARGET) --save-temps --debug
HLSCFLAGS := --compile $(COMMFLAGS)
LINKFLAGS := --link --optimize 3 $(COMMFLAGS)

# collect the RTL source code
RTL_SRC := ./rtl/aurora_hls_control_s_axi.v
RTL_SRC += ./rtl/aurora_hls_io.v
RTL_SRC += ./rtl/aurora_hls_nfc.v
RTL_SRC += ./rtl/aurora_hls_define.v
RTL_SRC += ./rtl/aurora_hls_configuration.v
RTL_SRC += ./rtl/aurora_hls_crc_counter.v
RTL_SRC += ./rtl/aurora_hls_reset.v
RTL_SRC += ./ip_creation/aurora_64b66b_0/aurora_64b66b_0.xci 
RTL_SRC += ./ip_creation/axis_data_fifo_rx/axis_data_fifo_rx.xci
RTL_SRC += ./ip_creation/axis_data_fifo_tx/axis_data_fifo_tx.xci
RTL_SRC += ./ip_creation/axis_dwidth_converter_rx/axis_dwidth_converter_rx.xci
RTL_SRC += ./ip_creation/axis_dwidth_converter_tx/axis_dwidth_converter_tx.xci

ifeq ($(PROBE_NFC), 1)
	RTL_SRC += ./ip_creation/ila_nfc/ila_nfc.xci
endif
ifeq ($(PROBE_CRC_COUNTER), 1)
	RTL_SRC += ./ip_creation/ila_crc_counter/ila_crc_counter.xci
endif

RTL_SRC_0 := $(RTL_SRC) ./rtl/aurora_hls_0.v ./xdc/aurora_64b66b_0.xdc
RTL_SRC_1 := $(RTL_SRC) ./rtl/aurora_hls_1.v ./xdc/aurora_64b66b_1.xdc

# some verilog templating
./rtl/aurora_hls_0.v: ./rtl/aurora_hls.v.template.v
	cp ./rtl/aurora_hls.v.template.v ./rtl/aurora_hls_0.v
	sed -i 's/@@@instance@@@/0/g' ./rtl/aurora_hls_0.v

./rtl/aurora_hls_1.v: ./rtl/aurora_hls.v.template.v
	cp ./rtl/aurora_hls.v.template.v ./rtl/aurora_hls_1.v
	sed -i 's/@@@instance@@@/1/g' ./rtl/aurora_hls_1.v

./rtl/aurora_hls_define.v:
	echo "" > $@
	if [ $(USE_FRAMING) = 1 ]; then \
		echo "\`define USE_FRAMING" >> $@; \
	fi
	if [ $(PROBE_NFC) = 1 ]; then \
		echo "\`define PROBE_NFC" >> $@; \
	fi
	if [ $(PROBE_CRC_COUNTER) = 1 ]; then \
		echo "\`define PROBE_CRC_COUNTER" >> $@; \
	fi
	if [ $(DRAIN_AXI_ON_RESET) = 1 ]; then \
		echo "\`define DRAIN_AXI_ON_RESET" >> $@; \
	fi
	echo "\`define HAS_TKEEP $(HAS_TKEEP)" >> $@
	echo "\`define HAS_TLAST $(HAS_TKEEP)" >> $@
	echo "\`define FIFO_WIDTH $(FIFO_WIDTH)" >> $@
	echo "\`define RX_FIFO_DEPTH $(RX_FIFO_DEPTH)" >> $@
	echo "\`define RX_FIFO_PROG_FULL $(RX_FIFO_PROG_FULL)" >> $@
	echo "\`define RX_FIFO_PROG_EMPTY $(RX_FIFO_PROG_EMPTY)" >> $@
	echo "\`define RX_EQ_MODE \"$(RX_EQ_MODE)\"" >> $@
	echo "\`define INS_LOSS_NYQ $(INS_LOSS_NYQ)" >> $@

aurora_hls_0.xo: $(RTL_SRC_0) ./tcl/pack_kernel.tcl
	rm -rf aurora_hls_0_project
	mkdir aurora_hls_0_project
	cd aurora_hls_0_project && vivado -mode batch -source ../tcl/pack_kernel.tcl -tclargs $(PART) 0

aurora_hls_1.xo: $(RTL_SRC_1) ./tcl/pack_kernel.tcl
	rm -rf aurora_hls_1_project
	mkdir aurora_hls_1_project
	cd aurora_hls_1_project && vivado -mode batch -source ../tcl/pack_kernel.tcl -tclargs $(PART) 1

# build example bitstream
dump_$(TARGET).xo: ./hls/dump.cpp
	v++ $(HLSCFLAGS) --temp_dir _x_dump --kernel dump --output $@ $^

issue_$(TARGET).xo: ./hls/issue.cpp
	v++ $(HLSCFLAGS) --temp_dir _x_issue --kernel issue --output $@ $^
	
aurora_hls_test_hw.xclbin: aurora issue_$(TARGET).xo dump_$(TARGET).xo aurora_hls_test_$(TARGET).cfg
	v++ $(LINKFLAGS) --temp_dir _x_aurora_hls_$(TARGET) --config aurora_hls_test_$(TARGET).cfg --output $@ aurora_hls_0.xo aurora_hls_1.xo dump_$(TARGET).xo issue_$(TARGET).xo

aurora_hls_test_sw_emu.xclbin: issue_$(TARGET).xo dump_$(TARGET).xo aurora_hls_test_$(TARGET).cfg
	v++ $(LINKFLAGS) --temp_dir _x_aurora_hls_$(TARGET) --config aurora_hls_test_$(TARGET).cfg --output $@ dump_$(TARGET).xo issue_$(TARGET).xo

xclbin: aurora_hls_test_hw.xclbin

# host build for example
CXXFLAGS += -std=c++17 -Wall -g
CXXFLAGS += -I$(XILINX_XRT)/include
CXXFLAGS += -fopenmp
LDFLAGS := -L$(XILINX_XRT)/lib
LDFLAGS += $(LDFLAGS) -lxrt_coreutil

host_aurora_hls_test: ./host/host_aurora_hls_test.cpp ./host/Aurora.hpp
	$(CXX) -o host_aurora_hls_test $< $(CXXFLAGS) $(LDFLAGS)

host: host_aurora_hls_test

# verilog testbenches
xsim.dir/work/aurora_hls_nfc.sdb: ./rtl/aurora_hls_nfc.v
	xvlog ./rtl/aurora_hls_nfc.v -d XSIM

xsim.dir/work/aurora_hls_nfc_tb.sdb: ./rtl/aurora_hls_nfc_tb.v
	xvlog ./rtl/aurora_hls_nfc_tb.v -d XSIM

xsim.dir/nfc_tb/xsimk: xsim.dir/work/aurora_hls_nfc.sdb xsim.dir/work/aurora_hls_nfc_tb.sdb
	xelab -debug typical aurora_hls_nfc_tb -s nfc_tb

nfc_tb: xsim.dir/nfc_tb/xsimk

run_nfc_tb: nfc_tb
	xsim -g --tclbatch tcl/run_nfc_tb.tcl nfc_tb

xsim.dir/work/aurora_hls_configuration.sdb: ./rtl/aurora_hls_configuration.v
	xvlog ./rtl/aurora_hls_configuration.v

xsim.dir/work/aurora_hls_configuration_tb.sdb: ./rtl/aurora_hls_configuration_tb.v
	xvlog ./rtl/aurora_hls_configuration_tb.v

xsim.dir/configuration_tb/xsimk: xsim.dir/work/aurora_hls_configuration.sdb xsim.dir/work/aurora_hls_configuration_tb.sdb
	xelab -debug typical aurora_hls_configuration_tb -s configuration_tb

configuration_tb: xsim.dir/configuration_tb/xsimk

run_configuration_tb: configuration_tb
	xsim -g --tclbatch tcl/run_configuration_tb.tcl configuration_tb

xsim.dir/work/aurora_hls_crc_counter.sdb: ./rtl/aurora_hls_crc_counter.v
	xvlog ./rtl/aurora_hls_crc_counter.v

xsim.dir/work/aurora_hls_crc_counter_tb.sdb: ./rtl/aurora_hls_crc_counter_tb.v
	xvlog ./rtl/aurora_hls_crc_counter_tb.v

xsim.dir/crc_counter_tb/xsimk: xsim.dir/work/aurora_hls_crc_counter.sdb xsim.dir/work/aurora_hls_crc_counter_tb.sdb
	xelab -debug typical aurora_hls_crc_counter_tb -s crc_counter_tb

crc_counter_tb: xsim.dir/crc_counter_tb/xsimk

run_crc_counter_tb: crc_counter_tb
	xsim -g --tclbatch tcl/run_crc_counter_tb.tcl crc_counter_tb

# run test
test: host aurora_hls_test_sw_emu.xclbin
	XCL_EMULATION_MODE=sw_emu ./host_aurora_hls_test -p aurora_hls_test_sw_emu.xclbin

clean:
	git clean -Xdf
