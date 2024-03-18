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
project(AuroraEmuLibTest)

add_subdirectory(${CMAKE_SOURCE_DIR}/.. ${CMAKE_BINARY_DIR}/auroraemu)

include(FetchContent)

# ------------------------------------------------------------------------------
# A unit testing suite for C++
FetchContent_Declare(
  extern_googletest

  DOWNLOAD_EXTRACT_TIMESTAMP Yes
  URL      https://github.com/google/googletest/archive/refs/tags/v1.14.0.tar.gz
  URL_HASH SHA256=8ad598c73ad796e0d8280b082cebd82a630d73e73cd3c70057938a6501bba5d7)

FetchContent_GetProperties(extern_googletest)
if(NOT extern_googletest_POPULATED)
  message(STATUS "Fetching mandatory build dependency GoogleTest")
  FetchContent_Populate(extern_googletest)
  add_subdirectory(
    ${extern_googletest_SOURCE_DIR} 
    ${extern_googletest_BINARY_DIR} 
    EXCLUDE_FROM_ALL)
endif()

set(SOURCE_FILES ${CMAKE_SOURCE_DIR}/test.cpp)
add_executable(aurora_emu_test ${SOURCE_FILES})

target_link_libraries(aurora_emu_test PUBLIC gtest gmock auroraemu)