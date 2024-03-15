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

#include <iostream>
#include <thread>

#include "auroraemu.hpp"
#include "hlslib/xilinx/Stream.h"
#include "kernels.h"

int main() {
    // create AXI input and output axi streams for the aurora cores
    hlslib::Stream<data_stream_t> in1("in1"), out1("out1"), in2("in2"),
        out2("out2");
    // Create an aurora switch
    auto s = AuroraEmuSwitch("127.0.0.1", 20000);
    // create emulated aurora cores
    // connect cores to switch and set own identifier and identifier of
    // remote core
    auto a1 = AuroraEmuCore("127.0.0.1", 20000, "a1", "a2", in1, out1);
    auto a2 = AuroraEmuCore("127.0.0.1", 20000, "a2", "a1", in2, out2);

    // create some input data
    float data_in[64];
    float data_out[64];
    for (int i = 0; i < 64; i++) {
        data_in[i] = i;
        data_out[i] = 0;
    }

    // Start the vadd kernel on the remote FPGA
    std::thread remote_kernel(remote_vadd, data_in, 64, std::ref(out2),
                              std::ref(in2));
    // start the collector kernel locally
    collector(data_in, data_out, 64, out1, in1);
    remote_kernel.join();

    // validate result and print absolute error
    float error = 0.0;
    for (int i = 0; i < 64; i++) {
        error += std::abs(data_in[i] * 2 - data_out[i]);
    }
    std::cout << "Absolute error " << error << std::endl;
}