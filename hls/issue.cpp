/*
 * Copyright 2022 Xilinx, Inc.
 *           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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
    void issue(hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>>& data_output,
                    ap_uint<DATA_WIDTH> *data_input,
                    unsigned int byte_size,
                    unsigned int frame_size,
                    unsigned int iterations,
                    bool ack_enable,
                    hls::stream<ap_axiu<1, 0, 0, 0>>& ack_stream)
    {
        int chunks = (byte_size / DATA_WIDTH_BYTES) + ((byte_size % DATA_WIDTH_BYTES) != 0);
        for (unsigned int n = 0; n < iterations; n++) {
            for (int i = 0; i < chunks; i++) {
                #pragma HLS PIPELINE II = 1
                ap_axiu<DATA_WIDTH, 0, 0, 0> temp;
                temp.data = data_input[i];
                if (frame_size != 0) {
                    temp.last = (((i + 1) % frame_size) == 0) || ((i + 1) == chunks);
                    temp.keep = -1;
                }
                data_output.write(temp);
            }
            if (ack_enable) {
                ap_axiu<1, 0, 0, 0> ack = ack_stream.read();
            }
        }    
    }
}