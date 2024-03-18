# 
#  Copyright 2024 Marius Meyer
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# 
cmake_minimum_required(VERSION 3.11 FATAL_ERROR)
project(AuroraEmuLib VERSION 0.1)

include(FetchContent)

# ------------------------------------------------------------------------------
# A library that provides helper classes for the development of HLS codes.
# This benchmark suite uses only the CMake files to find the Intel and Vitis installations
FetchContent_Declare(
  extern_hlslib

  # unfortunately they do not use releases, so the latest commit was used
  GIT_REPOSITORY      https://github.com/definelicht/hlslib.git
  GIT_TAG             master)

FetchContent_GetProperties(extern_hlslib)
if(NOT extern_hlslib_POPULATED)
  message(STATUS "Fetching mandatory build dependency hlslib")
  FetchContent_Populate(extern_hlslib)
    add_subdirectory(
    ${extern_hlslib_SOURCE_DIR} 
    ${extern_hlslib_BINARY_DIR} 
    EXCLUDE_FROM_ALL)
endif()

FetchContent_Declare(
  extern_cppzmq

  GIT_REPOSITORY      https://github.com/zeromq/cppzmq.git
  GIT_TAG             v4.10.0)

FetchContent_GetProperties(extern_hlslib)
if(NOT extern_cppzmq_POPULATED)
  message(STATUS "Fetching mandatory build dependency cppzmq")
  FetchContent_Populate(extern_cppzmq)
endif()


if (NOT Vitis_FOUND)
FetchContent_Declare(
  extern_hlsheaders

  # unfortunately they do not use releases, so the latest commit was used
  GIT_REPOSITORY      https://github.com/quetric/hls_sim_headers.git
  GIT_TAG             main)

FetchContent_GetProperties(extern_hlsheaders)
if(NOT extern_hlsheaders_POPULATED)
  message(STATUS "Fetching mandatory build dependency HLS headers")
  FetchContent_Populate(extern_hlsheaders)
  set(extern_hlsheaders_SOURCE_DIR ${extern_hlsheaders_SOURCE_DIR}/include)
endif()
endif()

# load in pkg-config support
find_package(PkgConfig)
# use pkg-config to get hints for 0mq locations
pkg_check_modules(PC_ZeroMQ QUIET zmq)

# use the hint from above to find where 'zmq.h' is located
find_path(ZeroMQ_INCLUDE_DIR
        NAMES zmq.h
        PATHS ${PC_ZeroMQ_INCLUDE_DIRS}
        )

# use the hint from above to find the location of libzmq
find_library(ZeroMQ_LIBRARY
  NAMES zmq
  PATHS ${PC_ZeroMQ_LIBRARY_DIRS}
)

# use this to globally use C++11 with in our project
set(CMAKE_CXX_STANDARD 11)

add_library(auroraemu INTERFACE)

target_include_directories(auroraemu INTERFACE ${ZeroMQ_INCLUDE_DIR} ${extern_hlsheaders_SOURCE_DIR} ${extern_cppzmq_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(auroraemu INTERFACE ${ZeroMQ_LIBRARY} hlslib)