/*
 * Copyright 2023-2025 Gerrit Pape (gerrit.pape@uni-paderborn.de)
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

#ifndef USE_FRAMING
#define USE_FRAMING 0
#endif

#define DATA_WIDTH (DATA_WIDTH_BYTES * 8)

#define STREAM_DEPTH 256

extern "C"
{
    void recv_data(
        unsigned int iterations,
        unsigned int chunks,
        unsigned int byte_size,
        unsigned int frame_size,
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_input,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream,
        hls::stream<ap_uint<32>, 1> &framing_error_stream,
        unsigned int ack_mode,
        hls::stream<ap_axiu<1, 0, 0, 0>>& loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>>& pair_ack_stream
    ) {
        ap_uint<32> framing_errors = 0;
    recv_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        recv_chunks:
            for (unsigned int i = 0; i < chunks; i++) {
#pragma HLS PIPELINE II = 1
                ap_axiu<DATA_WIDTH, 0, 0, 0> pkt = data_input.read();
#if USE_FRAMING
                if (frame_size != 0) {
                    unsigned int valid_bytes = ((i + 1) == chunks)
                        ? byte_size - (i * DATA_WIDTH_BYTES)
                        : DATA_WIDTH_BYTES;
                    ap_uint<DATA_WIDTH_BYTES> expected_keep = -1;
                    if (valid_bytes != DATA_WIDTH_BYTES) {
                        expected_keep = (ap_uint<DATA_WIDTH_BYTES>(1) << valid_bytes) - 1;
                    }
                    bool expected_last = (((i + 1) % frame_size) == 0) || ((i + 1) == chunks);
                    if (pkt.keep != expected_keep || pkt.last != expected_last) {
                        framing_errors++;
                    }
                }
#else
                (void)byte_size;
                (void)frame_size;
#endif
                data_stream.write(pkt.data);
            }
            ap_axiu<1, 0, 0, 0> ack;
            if (ack_mode == 0) {
                loopback_ack_stream.write(ack);
            } else if (ack_mode == 1) {
                pair_ack_stream.write(ack); 
            }
        }
        framing_error_stream.write(framing_errors);
    }

    void write_data(
        unsigned int iterations,
        unsigned int chunks,
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> &data_stream,
        ap_uint<DATA_WIDTH> *data_output,
        hls::stream<ap_uint<32>, 1> &framing_error_stream,
        volatile unsigned int *framing_errors
    ) {
    write_iterations:
        for (unsigned int n = 0; n < iterations; n++) {
        write_chunks:
            for (int i = 0; i < chunks; i++) {
#pragma HLS PIPELINE II = 1
                data_output[i] = data_stream.read();
            }
        }
        *framing_errors = framing_error_stream.read();
    }

    void recv(
        hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> &data_input,
        ap_uint<DATA_WIDTH> *data_output,
        unsigned int byte_size,
        unsigned int frame_size,
        unsigned int iterations,
        unsigned int ack_mode,
        volatile unsigned int *framing_errors,
        hls::stream<ap_axiu<1, 0, 0, 0>> &loopback_ack_stream,
        hls::stream<ap_axiu<1, 0, 0, 0>> &pair_ack_stream
    ) {
#pragma HLS INTERFACE m_axi port=data_output bundle=gmem_data
#pragma HLS INTERFACE m_axi port=framing_errors bundle=gmem_errors
#pragma HLS dataflow
        unsigned int chunks = (byte_size + DATA_WIDTH_BYTES - 1) / DATA_WIDTH_BYTES;
        hls::stream<ap_uint<DATA_WIDTH>, STREAM_DEPTH> data_stream;
        hls::stream<ap_uint<32>, 1> framing_error_stream;

        recv_data(iterations, chunks, byte_size, frame_size, data_input, data_stream,
                  framing_error_stream, ack_mode, loopback_ack_stream, pair_ack_stream);
        write_data(iterations, chunks, data_stream, data_output,
                   framing_error_stream, framing_errors);
    }
}
