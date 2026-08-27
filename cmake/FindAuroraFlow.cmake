#
# Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# FindAuroraFlow.cmake -- CMake integration for the AuroraFlow FPGA library.
#
# Usage:
#
#   set(AURORA_FLOW_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../AuroraFlow")
#   list(APPEND CMAKE_MODULE_PATH "${AURORA_FLOW_DIR}/cmake")
#   find_package(AuroraFlow REQUIRED)
#
#   target_link_libraries(my_host PRIVATE AuroraFlow::host)
#   aurora_flow_build_hw()       # adds custom target producing $(AURORA_FLOW_XOS_HW)
#   aurora_flow_build_hw_emu()
#   aurora_flow_build_sw_emu()
#
# Provides:
#   AuroraFlow::host           - INTERFACE target exposing the host-side header
#   AURORA_FLOW_XOS_HW         - list of hw .xo paths
#   AURORA_FLOW_XOS_HW_EMU     - list of hw_emu .xo paths
#   AURORA_FLOW_XO_SW_EMU      - sw_emu .xo path
#   AURORA_FLOW_DPI_SRC        - DPI-C source path (pass to v++ --vivado.prop for hw_emu)
#
# Notes:
#   Vivado and v++ are not driven natively by CMake. The aurora_flow_build_*
#   functions wrap add_custom_command invocations of the library Makefile.
#

if(NOT DEFINED AURORA_FLOW_DIR)
    # Fall back to the directory containing this file
    get_filename_component(AURORA_FLOW_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
endif()

set(AURORA_FLOW_BUILD_DIR "${AURORA_FLOW_DIR}/build"
    CACHE PATH "AuroraFlow kernel build directory")

find_path(AURORA_FLOW_INCLUDE_DIR
    NAMES AuroraFlow.hpp
    PATHS "${AURORA_FLOW_DIR}/include"
    NO_DEFAULT_PATH
)

set(AURORA_FLOW_XOS_HW
    "${AURORA_FLOW_BUILD_DIR}/aurora_flow_hw_0.xo"
    "${AURORA_FLOW_BUILD_DIR}/aurora_flow_hw_1.xo"
)
set(AURORA_FLOW_XOS_HW_EMU
    "${AURORA_FLOW_BUILD_DIR}/aurora_flow_hw_emu_0.xo"
    "${AURORA_FLOW_BUILD_DIR}/aurora_flow_hw_emu_1.xo"
)
set(AURORA_FLOW_XO_SW_EMU "${AURORA_FLOW_BUILD_DIR}/aurora_flow_sw_emu.xo")
set(AURORA_FLOW_DPI_SRC   "${AURORA_FLOW_DIR}/rtl/aurora_flow_dpi.c")

# Header-only host API target
if(NOT TARGET AuroraFlow::host)
    add_library(AuroraFlow::host INTERFACE IMPORTED)
    set_target_properties(AuroraFlow::host PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${AURORA_FLOW_INCLUDE_DIR}"
    )
    # The consumer is responsible for linking against XRT (XILINX_XRT)
    # since CMake does not ship a FindXRT module with the library.
endif()

# Forward AURORA_FLOW_<VAR> into <VAR>=value on the Makefile invocation.
set(_AURORA_FLOW_MAKE_ARGS BUILD_DIR=${AURORA_FLOW_BUILD_DIR})
foreach(var PLATFORM PART FIFO_WIDTH USE_FRAMING INS_LOSS_NYQ RX_EQ_MODE
            RX_FIFO_SIZE TX_FIFO_SIZE DRAIN_AXI_ON_RESET)
    if(DEFINED AURORA_FLOW_${var})
        list(APPEND _AURORA_FLOW_MAKE_ARGS "${var}=${AURORA_FLOW_${var}}")
    endif()
endforeach()
if(DEFINED AURORA_FLOW_VERSION)
    list(APPEND _AURORA_FLOW_MAKE_ARGS "AURORA_VERSION=${AURORA_FLOW_VERSION}")
endif()

function(aurora_flow_build_hw)
    add_custom_command(
        OUTPUT ${AURORA_FLOW_XOS_HW}
        COMMAND $(MAKE) -C ${AURORA_FLOW_DIR} aurora_hw ${_AURORA_FLOW_MAKE_ARGS}
        COMMENT "Building AuroraFlow hw kernels"
        VERBATIM
    )
    if(NOT TARGET aurora_flow_hw_kernels)
        add_custom_target(aurora_flow_hw_kernels DEPENDS ${AURORA_FLOW_XOS_HW})
    endif()
endfunction()

function(aurora_flow_build_hw_emu)
    add_custom_command(
        OUTPUT ${AURORA_FLOW_XOS_HW_EMU}
        COMMAND $(MAKE) -C ${AURORA_FLOW_DIR} aurora_hw_emu ${_AURORA_FLOW_MAKE_ARGS}
        COMMENT "Building AuroraFlow hw_emu kernels"
        VERBATIM
    )
    if(NOT TARGET aurora_flow_hw_emu_kernels)
        add_custom_target(aurora_flow_hw_emu_kernels DEPENDS ${AURORA_FLOW_XOS_HW_EMU})
    endif()
endfunction()

function(aurora_flow_build_sw_emu)
    add_custom_command(
        OUTPUT ${AURORA_FLOW_XO_SW_EMU}
        COMMAND $(MAKE) -C ${AURORA_FLOW_DIR} aurora_sw_emu ${_AURORA_FLOW_MAKE_ARGS}
        COMMENT "Building AuroraFlow sw_emu kernel"
        VERBATIM
    )
    if(NOT TARGET aurora_flow_sw_emu_kernel)
        add_custom_target(aurora_flow_sw_emu_kernel DEPENDS ${AURORA_FLOW_XO_SW_EMU})
    endif()
endfunction()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(AuroraFlow
    REQUIRED_VARS AURORA_FLOW_INCLUDE_DIR AURORA_FLOW_DIR
)
