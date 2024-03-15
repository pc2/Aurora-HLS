/*
 * Copyright 2024 Marius Meyer
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef SYNTHESIS
#include "hlslib/xilinx/Stream.h"
#define STREAM hlslib::Stream
#else
#include "hls_streams.h"
#define STREAM hls::stream
#endif

typedef union ap_uint_to_floats {
    ap_uint_to_floats(){};
    ~ap_uint_to_floats(){};
    float data[16];
    ap_uint<512> stream_data;
} ap_uint_to_floats_t;
