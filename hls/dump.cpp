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
    void dump_data(
        unsigned int iterations,
        unsigned int chunks,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_input,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream,
        unsigned int ack_mode,
        hls::stream<ap_axiu<1, 0, 0, 0>>& loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>>& pair_ack_stream
    ) {
    dump_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        dump_chunks:
            for (int i = 0; i < chunks; i++) {
#pragma HLS PIPELINE II = 1
                data_stream.write(data_input.read().data);
            }
            ap_axiu<1, 0, 0, 0> ack;
            if (ack_mode == 0) {
                loopback_ack_stream.write(ack);
            } else if (ack_mode == 1) {
                pair_ack_stream.write(ack); 
            }
        }
    }

    void write_data(
        unsigned int iterations,
        unsigned int chunks,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream,
        ap_uint<DATA_WIDTH> *data_output
    ) {
    write_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        write_chunks:
            for (int i = 0; i < chunks; i++) {
#pragma HLS PIPELINE II = 1
                data_output[i] = data_stream.read();
            }
        }
    }

    void dump(
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_input,
        ap_uint<DATA_WIDTH> *data_output,
        unsigned int byte_size,
        unsigned int iterations,
        unsigned int ack_mode,
        hls::stream<ap_axiu<1, 0, 0, 0>> &loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>> &pair_ack_stream
    ) {
#pragma HLS dataflow
        int chunks = byte_size / DATA_WIDTH_BYTES;
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> data_stream;

        dump_data(iterations, chunks, data_input, data_stream, ack_mode, loopback_ack_stream, pair_ack_stream);
        write_data(iterations, chunks, data_stream, data_output);
    }
}


