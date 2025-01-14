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

#define STREAM_DEPTH 256

extern "C"
{
    void read_data(
        unsigned int iterations,
        unsigned int chunks,
        ap_uint<DATA_WIDTH> *data_input,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream
    ) {
    read_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        read_chunks:
            for (unsigned int i = 0; i < chunks; i++) {
                #pragma HLS PIPELINE II = 1
                data_stream.write(data_input[i]);
            }
        }
    }

    void issue_data(
        unsigned int iterations,
        unsigned int chunks,
        unsigned int frame_size,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_output,
        unsigned int ack_mode,
        hls::stream<ap_axiu<1, 0, 0, 0>> &loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>> &pair_ack_stream
    ) {
    issue_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        issue_chunks:
            for (unsigned int i = 0; i < chunks; i++) {
                #pragma HLS PIPELINE II = 1
                ap_axiu<DATA_WIDTH, 0, 0, 0> temp;
                temp.data = data_stream.read();
                if (frame_size != 0) {
                    temp.last = (((i + 1) % frame_size) == 0) || ((i + 1) == chunks);
                    temp.keep = -1;
                }
                data_output.write(temp);
            }
            if (ack_mode == 0) {
                ap_axiu<1, 0, 0, 0> ack = loopback_ack_stream.read();
            } else if (ack_mode == 1) {
                ap_axiu<1, 0, 0, 0> ack = pair_ack_stream.read();
            }
        }
    }

    void issue(
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>>& data_output,
        ap_uint<DATA_WIDTH> *data_input,
        unsigned int byte_size,
        unsigned int frame_size,
        unsigned int iterations,
        unsigned int ack_mode,
        hls::stream<ap_axiu<1, 0, 0, 0>>& loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>>& pair_ack_stream
    ) {
#pragma HLS dataflow
        unsigned int chunks = byte_size / DATA_WIDTH_BYTES;
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> data_stream;

        read_data(iterations, chunks, data_input, data_stream);
        issue_data(iterations, chunks, frame_size, data_stream, data_output, ack_mode, loopback_ack_stream, pair_ack_stream);
    }
}
