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
project(AuroraEmuLib)

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
  set(extern_hlslib_SOURCE_DIR ${extern_hlslib_SOURCE_DIR})
    add_subdirectory(
    ${extern_hlslib_SOURCE_DIR} 
    ${extern_hlslib_BINARY_DIR} 
    EXCLUDE_FROM_ALL)
endif()

FetchContent_Declare(
  extern_cppzmq

  # unfortunately they do not use releases, so the latest commit was used
  GIT_REPOSITORY      https://github.com/zeromq/cppzmq.git
  GIT_TAG             v4.10.0)

FetchContent_GetProperties(extern_hlslib)
if(NOT extern_cppzmq_POPULATED)
  message(STATUS "Fetching mandatory build dependency cppzmq")
  FetchContent_Populate(extern_cppzmq)
  set(extern_cpp_zmq_SOURCE_DIR ${extern_cppzmq_SOURCE_DIR})
endif()

## use this to globally use C++11 with in our project
set(CMAKE_CXX_STANDARD 11)

add_library(auroraemu INTERFACE)

## add the include directory to our compile directives
target_include_directories(auroraemu INTERFACE ${extern_cppzmq_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/include)
## at the 0mq library to our link directive
target_link_libraries(auroraemu INTERFACE zmq hlslib)