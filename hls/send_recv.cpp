/*
 * Copyright 2023-2025 Gerrit Pape (papeg@mail.upb.de)
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

#include <hls_stream.h>
#include <ap_int.h>
#include <ap_axi_sdata.h>

#ifndef DATA_WIDTH_BYTES
#define DATA_WIDTH_BYTES 64
#endif

#define DATA_WIDTH (DATA_WIDTH_BYTES * 8)

extern "C"
{
    void send_recv(
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_input,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_output,
        unsigned int byte_size,
        unsigned int iterations
    ) {
        int chunks = byte_size / DATA_WIDTH_BYTES;
    send_recv_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        send_recv_chunks:
            for (unsigned int i = 0; i < chunks; i++) {
                #pragma HLS PIPELINE II = 1
                data_output.write(data_input.read());
            }
        }
    }
}
