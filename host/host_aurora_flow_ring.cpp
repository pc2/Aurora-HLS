/*
 * Copyright 2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

#include "Aurora.hpp"
#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include "version.h"
#include <fstream>
#include <unistd.h>
#include <vector>
#include <thread>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <mpi.h>

#include "Configuration.hpp"
#include "Results.hpp"
#include "Kernel.hpp"

// can be used for chipscoping
void wait_for_enter()
{
    std::cout << "waiting for enter.." << std::endl;
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

std::vector<std::vector<char>> generate_data(uint32_t num_bytes, uint32_t size)
{
    char *slurm_job_id = std::getenv("SLURM_JOB_ID");
    std::vector<std::vector<char>> data;
    data.resize(size);
    for (uint32_t r = 0; r < size; r++) {
        unsigned int seed = (slurm_job_id == NULL) ? r : (r + ((unsigned int)std::stoi(slurm_job_id)));
        srand(seed);
        data[r].resize(num_bytes);
        for (uint32_t b = 0; b < num_bytes; b++) {
            data[r][b] = rand() % 256;
        }
    }
    return data;
}

void check_core_status_global(Aurora &aurora_0, Aurora &aurora_1, size_t timeout_ms, int rank, int size)
{
    bool local_core_ok[2];

    // barrier so timeout is working for all configurations 
    MPI_Barrier(MPI_COMM_WORLD);
    local_core_ok[0] = aurora_0.core_status_ok(3000);
    local_core_ok[1] = aurora_1.core_status_ok(3000);

    bool core_ok[size * 2];
    MPI_Gather(local_core_ok, 2, MPI_CXX_BOOL, core_ok, 2, MPI_CXX_BOOL, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        int errors = 0;       
        for (int i = 0; i < (2 * size); i++) {
            if (!core_ok[i]) {
                std::cout << "problem with core " << i % 2 << " on rank " << i / 2 << std::endl;
                errors += 1;
            }
        }
        if (errors) {
            MPI_Abort(MPI_COMM_WORLD, errors);
        }
    }
}

std::string bdf_map(uint32_t device_id, bool emulation)
{
    if (device_id == 0) {
        return "0000:a1:00.1";
    } else if (device_id == 1) {
        return "0000:81:00.1";
    } else if (device_id == 2) {
        return "0000:01:00.1";
    } else {
        throw std::invalid_argument("Invalid device id");
    }
}

int main(int argc, char *argv[])
{
    Configuration config(argc, argv);
 
    MPI_Init(&argc, &argv);

    int size, rank;
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    bool emulation = (std::getenv("XCL_EMULATION_MODE") != nullptr);

    if (emulation) {
        config.finish_setup(64, false, emulation);
    }
    config.test_mode = 2;

    uint32_t device_id;
    std::string device_bdf;
    xrt::device device;
    xrt::uuid xclbin_uuid;

    device_id = emulation ? 0 : (rank % 3);

    device_bdf = bdf_map(device_id, emulation);

    std::cout << "Programming device " << device_bdf << std::endl;
    device = xrt::device(device_bdf);

    if (rank == 0) {
        xclbin_uuid = device.load_xclbin("aurora_flow_test_hw.xclbin");
    } else {
        xclbin_uuid = device.load_xclbin("aurora_flow_ring_hw.xclbin");
    }

    if (config.wait) {
        wait_for_enter();
    }
    std::vector<Aurora> aurora(2);
    aurora[0] = Aurora(0, device, xclbin_uuid);
    aurora[1] = Aurora(1, device, xclbin_uuid);

    check_core_status_global(aurora[0], aurora[1], 3000, rank, size);

    std::cout << "All links are ready" << std::endl;

    config.finish_setup(aurora[0].fifo_width, aurora[0].has_framing(), emulation);

    config.print();

    std::cout << "Aurora core has framing " << (aurora[0].has_framing() ? "enabled" : "disabled")
              << " and input width of " << aurora[0].fifo_width << " bytes" << std::endl;

    std::vector<std::vector<char>> data = generate_data(config.max_num_bytes, 2);

    // create kernel objects
    std::vector<SendKernel> send_kernels(2);
    std::vector<RecvKernel> recv_kernels(2);
    std::vector<SendRecvKernel> send_recv_kernels(2);

    if (rank == 0) {
        for (uint32_t i = 0; i < 2; i++) {
            send_kernels[i] = SendKernel(i, device, xclbin_uuid, config, data[i]);
            recv_kernels[i] = RecvKernel(i, device, xclbin_uuid, config);
        }
    } else {
        for (uint32_t i = 0; i < 2; i++) {
            send_recv_kernels[i] = SendRecvKernel(i, device, xclbin_uuid, config);
        }
    }

    //Results results(config, auroras, emulation, device_bdfs);

    for (uint32_t r = 0; r < config.repetitions; r++) {
        if (rank == 0) {
            std::cout << "Repetition " << r << " with " << config.message_sizes[r] << " bytes" << std::endl;
        }
        try {
            if (rank == 0) {
                send_kernels[1].prepare_repetition(r);
                recv_kernels[0].prepare_repetition(r);
                recv_kernels[0].start();
            } else {
                send_recv_kernels[0].prepare_repetition(r);
                send_recv_kernels[0].start();
            }

            MPI_Barrier(MPI_COMM_WORLD);
            double start_time = get_wtime();
            if (rank == 0) {
                uint32_t i_send = 1;
                uint32_t i_recv = 0;
                send_kernels[i_send].start();

                if (recv_kernels[i_recv].timeout()) {
                    std::cout << "Recv " << i_recv << " timeout" << std::endl;
                }

                if (send_kernels[i_send].timeout()) {
                    std::cout << "Send " << i_send << " timeout" << std::endl;
                }

                double end_time = get_wtime();

                recv_kernels[i_recv].write_back();

                uint32_t errors = recv_kernels[i_recv].compare_data(data[i_send].data(), r);
                if (errors) {
                    std::cout << errors << " byte errors" << std::endl;
                }
                double latency = (end_time - start_time) / config.iterations_per_message[r];
                double gigabits = config.message_sizes[r] * 8 / 1000000000.0;

                std::cout << "Throughput: " << gigabits / latency << std::endl;
                std::cout << "Latency (us): " << latency * 1000000.0 << std::endl;
            }
        } catch (const std::runtime_error &e) {
            std::cout << "caught runtime error: " << e.what() << std::endl;
        } catch (const std::exception &e) {
            std::cout << "caught unexpected error: " << e.what() << std::endl;
        } catch (...) {
            std::cout << "caught non-std::logic_error " << std::endl;
        }
    }

    MPI_Finalize();

    return EXIT_SUCCESS;
}

