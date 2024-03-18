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

#include "kernels.h"

void collector(float* data_in, float* data_out, size_t data_size,
               STREAM<data_stream_t>& from_remote,
               STREAM<data_stream_t>& to_remote) {
    for (size_t i = 0; i < data_size; i += 16) {
#pragma HLS pipeline II = 1
        // get data from local memory buffer
        ap_uint_to_floats_t remote_conv;
        for (size_t ii = 0; ii < 16; ii++) {
            remote_conv.data[ii] = data_in[i + ii];
        }
        // send data to remote via aurora
        data_stream_t out;
        out.data = remote_conv.stream_data;
        to_remote.write(out);
        // get remote data from aurora core
        remote_conv.stream_data = from_remote.read().data;
        for (int ii = 0; ii < 16; ii++) {
            data_out[i + ii] = remote_conv.data[ii];
        }
    }
}
