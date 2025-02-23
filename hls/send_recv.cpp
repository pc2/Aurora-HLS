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
#include <hls_task.h>
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
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_input_stream
    ) {
    read_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        read_chunks:
            for (unsigned int i = 0; i < chunks; i++) {
            #pragma HLS PIPELINE II = 1
                data_input_stream.write(data_input[i]);
            }
        }
    }

    void write_data(
        unsigned int iterations,
        unsigned int chunks,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_output_stream,
        ap_uint<DATA_WIDTH> *data_output
    ) {
    write_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        write_chunks:
            for (int i = 0; i < chunks; i++) {
            #pragma HLS PIPELINE II = 1
                data_output[i] = data_output_stream.read();
            }
        }
    }

    void send_data(
        unsigned int chunks,
        unsigned int frame_size,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_input_stream,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &ring_output
    ) {
    send_chunks:
        for (unsigned int i = 0; i < chunks; i++) {
        #pragma HLS PIPELINE II = 1
            ap_axiu<DATA_WIDTH, 0, 0, 0> temp;
            temp.data = data_input_stream.read();
            if (frame_size != 0) {
                temp.last = (((i + 1) % frame_size) == 0) || ((i + 1) == chunks);
                temp.keep = -1;
            }
            ring_output.write(temp);
        }
    }

    void recv_data(
        unsigned int chunks,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_output_stream,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &ring_input
    ) {
    recv_chunks:
        for (int i = 0; i < chunks; i++) {
#pragma HLS PIPELINE II = 1
            data_output_stream.write(ring_input.read().data);
        }
    }

    void send_recv(
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &ring_input,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &ring_output,
        ap_uint<DATA_WIDTH> *data_input,
        ap_uint<DATA_WIDTH> *data_output,
        unsigned int iterations,
        unsigned int byte_size,
        unsigned int frame_size
    ) {
#pragma HLS dataflow
        int chunks = byte_size / DATA_WIDTH_BYTES;
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> data_input_stream;
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> data_output_stream;

        read_data(iterations, chunks, data_input, data_input_stream);

    send_recv_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
#pragma HLS pipeline off
            send_data(chunks, frame_size, data_input_stream, ring_output);
            recv_data(chunks, data_output_stream, ring_input);
        }
        write_data(iterations, chunks, data_output_stream, data_output);
    }
}
