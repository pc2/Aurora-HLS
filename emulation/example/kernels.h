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

#include <ap_axi_sdata.h>
#include <ap_int.h>

#include "common_streams.h"

typedef ap_axiu<512, 0, 0, 0> data_stream_t;

void remote_vadd(float* data, size_t data_size,
                 STREAM<data_stream_t>& from_remote,
                 STREAM<data_stream_t>& to_remote);

void collector(float* data_in, float* data_out, size_t data_size,
               STREAM<data_stream_t>& from_remote,
               STREAM<data_stream_t>& to_remote);
