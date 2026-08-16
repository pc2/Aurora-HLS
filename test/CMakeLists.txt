#
# Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Alternative build for the AuroraFlow test/benchmark application.
# Consumes the library via find_package(AuroraFlow).
#
# Mirrors the targets of the Makefile:
#   host                 - builds host_aurora_flow_test
#   xclbin_hw            - links aurora_flow_test_hw.xclbin
#   xclbin_hw_emu        - links aurora_flow_test_hw_emu.xclbin
#   xclbin_sw_emu        - links aurora_flow_test_sw_emu.xclbin
#   emconfig             - generates emconfig.json
#

cmake_minimum_required(VERSION 3.16)
project(aurora_flow_test LANGUAGES CXX)

# ---------------------------------------------------------------------------
# Find AuroraFlow library
# ---------------------------------------------------------------------------

get_filename_component(AURORA_FLOW_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH "${AURORA_FLOW_DIR}/cmake")

# Tell the library to put its kernels in the same build dir as the test app,
# so a single `rm -rf <build_dir>` cleans everything.
set(AURORA_FLOW_BUILD_DIR "${CMAKE_BINARY_DIR}" CACHE PATH "AuroraFlow kernel build directory" FORCE)

set(AURORA_FLOW_PLATFORM   "xilinx_u280_gen3x16_xdma_1_202211_1" CACHE STRING "v++ platform")
set(AURORA_FLOW_FIFO_WIDTH "64" CACHE STRING "AuroraFlow FIFO width (32 or 64)")
set(AURORA_FLOW_USE_FRAMING "0" CACHE STRING "Enable Aurora framing (0 or 1)")
set(AURORA_FLOW_TARGET_CLOCK_HZ "300000000" CACHE STRING
    "AuroraFlow AXI clock target in Hz")

find_package(AuroraFlow REQUIRED)

# ---------------------------------------------------------------------------
# XRT
# ---------------------------------------------------------------------------

if(NOT DEFINED ENV{XILINX_XRT})
    message(FATAL_ERROR "XILINX_XRT environment variable is not set. Source the Xilinx XRT setup.sh first.")
endif()
set(XILINX_XRT "$ENV{XILINX_XRT}")

# ---------------------------------------------------------------------------
# MPI
# ---------------------------------------------------------------------------

find_package(MPI REQUIRED COMPONENTS CXX)

# ---------------------------------------------------------------------------
# Host binary
# ---------------------------------------------------------------------------

add_executable(host_aurora_flow_test host/host_aurora_flow_test.cpp)
target_compile_features(host_aurora_flow_test PRIVATE cxx_std_17)
target_compile_options(host_aurora_flow_test PRIVATE -Wall -g -fopenmp)
target_link_options(host_aurora_flow_test PRIVATE -fopenmp)
target_include_directories(host_aurora_flow_test PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/host"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${XILINX_XRT}/include"
)
target_link_directories(host_aurora_flow_test PRIVATE "${XILINX_XRT}/lib")
target_link_libraries(host_aurora_flow_test PRIVATE
    AuroraFlow::host
    MPI::MPI_CXX
    xrt_coreutil
    uuid
)

# Convenience phony
add_custom_target(host DEPENDS host_aurora_flow_test)

# ---------------------------------------------------------------------------
# Kernel builds (delegate to library Makefile via FindAuroraFlow helpers)
# ---------------------------------------------------------------------------

aurora_flow_build_hw()
aurora_flow_build_hw_emu()
aurora_flow_build_sw_emu()

# ---------------------------------------------------------------------------
# v++ configuration
# ---------------------------------------------------------------------------

find_program(VPP_EXECUTABLE v++ REQUIRED)
find_program(EMCONFIGUTIL_EXECUTABLE emconfigutil)

set(VPP_COMMON_FLAGS
    --platform ${AURORA_FLOW_PLATFORM}
    --save-temps
    --debug
)
set(VPP_HLS_FLAGS ${VPP_COMMON_FLAGS} -DDATA_WIDTH_BYTES=${AURORA_FLOW_FIFO_WIDTH})
set(VPP_LINK_FLAGS --link --optimize 3 ${VPP_COMMON_FLAGS})

set(AURORA_CLOCK_CONFIG
    "${CMAKE_BINARY_DIR}/aurora_flow_clock_${AURORA_FLOW_TARGET_CLOCK_HZ}.cfg")
file(GENERATE OUTPUT "${AURORA_CLOCK_CONFIG}" CONTENT
"[clock]\nfreqHz=${AURORA_FLOW_TARGET_CLOCK_HZ}:aurora_flow_0.ap_clk,aurora_flow_1.ap_clk\n")

# ---------------------------------------------------------------------------
# Application HLS kernels (send, recv) per v++ target
# ---------------------------------------------------------------------------

# add_hls_kernel(<kernel_name> <source> <target>)
#   kernel_name: send | recv
#   source:      relative path (hls/send.cpp or hls/recv.cpp)
#   target:      hw | hw_emu | sw_emu
function(add_hls_kernel kernel_name source target_mode)
    set(out "${CMAKE_BINARY_DIR}/${kernel_name}_${target_mode}.xo")
    add_custom_command(
        OUTPUT ${out}
        COMMAND ${VPP_EXECUTABLE} --compile ${VPP_HLS_FLAGS} --target ${target_mode}
                --temp_dir ${CMAKE_BINARY_DIR}/_x_${kernel_name}_${target_mode}
                --kernel ${kernel_name} --output ${out}
                ${CMAKE_CURRENT_SOURCE_DIR}/${source}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${source}
        COMMENT "v++ compile ${kernel_name} (${target_mode})"
        VERBATIM
    )
    add_custom_target(${kernel_name}_${target_mode}_xo DEPENDS ${out})
    set(${kernel_name}_${target_mode}_xo_path ${out} PARENT_SCOPE)
endfunction()

foreach(mode hw hw_emu sw_emu)
    add_hls_kernel(send hls/send.cpp ${mode})
    add_hls_kernel(recv hls/recv.cpp ${mode})
endforeach()

# ---------------------------------------------------------------------------
# Linked xclbins
# ---------------------------------------------------------------------------

# hw
set(HW_XCLBIN "${CMAKE_BINARY_DIR}/aurora_flow_test_hw.xclbin")
add_custom_command(
    OUTPUT ${HW_XCLBIN}
    COMMAND ${VPP_EXECUTABLE} ${VPP_LINK_FLAGS} --target hw
            --temp_dir ${CMAKE_BINARY_DIR}/_x_aurora_flow_test_hw
            --config ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_hw.cfg
            --config ${AURORA_CLOCK_CONFIG}
            --output ${HW_XCLBIN}
            ${AURORA_FLOW_XOS_HW}
            ${send_hw_xo_path} ${recv_hw_xo_path}
    DEPENDS aurora_flow_hw_kernels send_hw_xo recv_hw_xo
            ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_hw.cfg
            ${AURORA_CLOCK_CONFIG}
    COMMENT "v++ link aurora_flow_test_hw.xclbin"
    VERBATIM
)
add_custom_target(xclbin_hw DEPENDS ${HW_XCLBIN})

# hw_emu (needs DPI-C source via --vivado.prop)
set(HW_EMU_XCLBIN "${CMAKE_BINARY_DIR}/aurora_flow_test_hw_emu.xclbin")
add_custom_command(
    OUTPUT ${HW_EMU_XCLBIN}
    COMMAND ${VPP_EXECUTABLE} ${VPP_LINK_FLAGS} --target hw_emu
            --temp_dir ${CMAKE_BINARY_DIR}/_x_aurora_flow_test_hw_emu
            --config ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_hw_emu.cfg
            --config ${AURORA_CLOCK_CONFIG}
            --vivado.prop "fileset.sim_1.{xsim.compile.xsc.more_options}={${AURORA_FLOW_DPI_SRC}}"
            --output ${HW_EMU_XCLBIN}
            ${AURORA_FLOW_XOS_HW_EMU}
            ${send_hw_emu_xo_path} ${recv_hw_emu_xo_path}
    DEPENDS aurora_flow_hw_emu_kernels send_hw_emu_xo recv_hw_emu_xo
            ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_hw_emu.cfg
            ${AURORA_CLOCK_CONFIG}
            ${AURORA_FLOW_DPI_SRC}
    COMMENT "v++ link aurora_flow_test_hw_emu.xclbin"
    VERBATIM
)
add_custom_target(xclbin_hw_emu DEPENDS ${HW_EMU_XCLBIN})

# sw_emu
set(SW_EMU_XCLBIN "${CMAKE_BINARY_DIR}/aurora_flow_test_sw_emu.xclbin")
add_custom_command(
    OUTPUT ${SW_EMU_XCLBIN}
    COMMAND ${VPP_EXECUTABLE} ${VPP_LINK_FLAGS} --target sw_emu
            --temp_dir ${CMAKE_BINARY_DIR}/_x_aurora_flow_test_sw_emu
            --config ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_sw_emu.cfg
            --output ${SW_EMU_XCLBIN}
            ${AURORA_FLOW_XO_SW_EMU}
            ${send_sw_emu_xo_path} ${recv_sw_emu_xo_path}
    DEPENDS aurora_flow_sw_emu_kernel send_sw_emu_xo recv_sw_emu_xo
            ${CMAKE_CURRENT_SOURCE_DIR}/cfg/aurora_flow_test_sw_emu.cfg
    COMMENT "v++ link aurora_flow_test_sw_emu.xclbin"
    VERBATIM
)
add_custom_target(xclbin_sw_emu DEPENDS ${SW_EMU_XCLBIN})

# ---------------------------------------------------------------------------
# emconfig.json (needed by XRT for emulation targets)
# ---------------------------------------------------------------------------

if(EMCONFIGUTIL_EXECUTABLE)
    set(EMCONFIG_JSON "${CMAKE_BINARY_DIR}/emconfig.json")
    add_custom_command(
        OUTPUT ${EMCONFIG_JSON}
        COMMAND ${EMCONFIGUTIL_EXECUTABLE} --platform ${AURORA_FLOW_PLATFORM} --od ${CMAKE_BINARY_DIR}
        COMMENT "Generating emconfig.json"
        VERBATIM
    )
    add_custom_target(emconfig DEPENDS ${EMCONFIG_JSON})
endif()
