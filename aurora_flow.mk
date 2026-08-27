#
# Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# AuroraFlow Make integration fragment.
#
# Include this in your application Makefile:
#
#   AURORA_FLOW_DIR := /path/to/AuroraFlow
#   include $(AURORA_FLOW_DIR)/aurora_flow.mk
#
# Exported variables:
#   AURORA_FLOW_XOS_HW      - .xo paths for hw kernels (both instances)
#   AURORA_FLOW_XOS_HW_EMU  - .xo paths for hw_emu kernels (both instances)
#   AURORA_FLOW_XO_SW_EMU   - .xo path for sw_emu kernel
#   AURORA_FLOW_DPI_SRC     - path to DPI-C source (needed for hw_emu xclbin via --vivado.prop)
#   AURORA_FLOW_INCLUDE     - -I flag for host compilation (AuroraFlow.hpp)
#   AURORA_FLOW_HEADER      - full path to AuroraFlow.hpp (use as a Make prerequisite)
#
# Exported targets (delegate to library Makefile, forwarding all AURORA_FLOW_* variables):
#   aurora_flow_hw          - build hw kernels
#   aurora_flow_hw_emu      - build hw_emu kernels
#   aurora_flow_sw_emu      - build sw_emu kernel
#

ifndef AURORA_FLOW_DIR
  $(error AURORA_FLOW_DIR must be set before including aurora_flow.mk)
endif

AURORA_FLOW_BUILD_DIR ?= $(AURORA_FLOW_DIR)/build
HW_INTERFACE_CLOCK_ID ?= 0
HW_EMU_CLOCKS ?= 2
HW_EMU_INTERFACE_CLOCK_ID ?= 0

# Paths to kernel artifacts (built by the library Makefile)
AURORA_FLOW_XOS_HW     := $(AURORA_FLOW_BUILD_DIR)/aurora_flow_hw_0.xo \
                          $(AURORA_FLOW_BUILD_DIR)/aurora_flow_hw_1.xo
AURORA_FLOW_XOS_HW_EMU := $(AURORA_FLOW_BUILD_DIR)/aurora_flow_hw_emu_0.xo \
                          $(AURORA_FLOW_BUILD_DIR)/aurora_flow_hw_emu_1.xo
AURORA_FLOW_XO_SW_EMU  := $(AURORA_FLOW_BUILD_DIR)/aurora_flow_sw_emu.xo

# DPI-C source required when linking an hw_emu xclbin that includes the GT stub
AURORA_FLOW_DPI_SRC := $(AURORA_FLOW_DIR)/rtl/aurora_flow_dpi.c

# Host-side API include path and header file (header is exposed so consumers
# can list it as a prerequisite for their host build rule)
AURORA_FLOW_INCLUDE := -I$(AURORA_FLOW_DIR)/include
AURORA_FLOW_HEADER  := $(AURORA_FLOW_DIR)/include/AuroraFlow.hpp

# Forward relevant variables to the library Makefile so consumer overrides
# (USE_FRAMING, FIFO_WIDTH, PLATFORM, PART, ...) propagate.
AURORA_FLOW_MAKE_ARGS := BUILD_DIR=$(AURORA_FLOW_BUILD_DIR)
ifdef PLATFORM
  AURORA_FLOW_MAKE_ARGS += PLATFORM=$(PLATFORM)
endif
ifdef PART
  AURORA_FLOW_MAKE_ARGS += PART=$(PART)
endif
ifdef FIFO_WIDTH
  AURORA_FLOW_MAKE_ARGS += FIFO_WIDTH=$(FIFO_WIDTH)
endif
ifdef USE_FRAMING
  AURORA_FLOW_MAKE_ARGS += USE_FRAMING=$(USE_FRAMING)
endif
ifdef INS_LOSS_NYQ
  AURORA_FLOW_MAKE_ARGS += INS_LOSS_NYQ=$(INS_LOSS_NYQ)
endif
ifdef RX_EQ_MODE
  AURORA_FLOW_MAKE_ARGS += RX_EQ_MODE=$(RX_EQ_MODE)
endif
ifdef RX_FIFO_SIZE
  AURORA_FLOW_MAKE_ARGS += RX_FIFO_SIZE=$(RX_FIFO_SIZE)
endif
ifdef TX_FIFO_SIZE
  AURORA_FLOW_MAKE_ARGS += TX_FIFO_SIZE=$(TX_FIFO_SIZE)
endif
ifdef DRAIN_AXI_ON_RESET
  AURORA_FLOW_MAKE_ARGS += DRAIN_AXI_ON_RESET=$(DRAIN_AXI_ON_RESET)
endif
ifdef AURORA_VERSION
  AURORA_FLOW_MAKE_ARGS += AURORA_VERSION=$(AURORA_VERSION)
endif
ifdef HW_EMU_CLOCKS
  AURORA_FLOW_MAKE_ARGS += HW_EMU_CLOCKS=$(HW_EMU_CLOCKS)
endif
ifdef HW_INTERFACE_CLOCK_ID
  AURORA_FLOW_MAKE_ARGS += HW_INTERFACE_CLOCK_ID=$(HW_INTERFACE_CLOCK_ID)
endif
ifdef HW_EMU_INTERFACE_CLOCK_ID
  AURORA_FLOW_MAKE_ARGS += HW_EMU_INTERFACE_CLOCK_ID=$(HW_EMU_INTERFACE_CLOCK_ID)
endif

.PHONY: aurora_flow_hw aurora_flow_hw_emu aurora_flow_sw_emu

aurora_flow_hw:
	$(MAKE) -C $(AURORA_FLOW_DIR) aurora_hw $(AURORA_FLOW_MAKE_ARGS)
$(AURORA_FLOW_XOS_HW): aurora_flow_hw ;

aurora_flow_hw_emu:
	$(MAKE) -C $(AURORA_FLOW_DIR) aurora_hw_emu $(AURORA_FLOW_MAKE_ARGS)
$(AURORA_FLOW_XOS_HW_EMU): aurora_flow_hw_emu ;

aurora_flow_sw_emu:
	$(MAKE) -C $(AURORA_FLOW_DIR) aurora_sw_emu $(AURORA_FLOW_MAKE_ARGS)
$(AURORA_FLOW_XO_SW_EMU): aurora_flow_sw_emu ;
