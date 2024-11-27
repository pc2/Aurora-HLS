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
#include <mpi.h>
#include <iostream>
#include <filesystem>
#include <fstream>

#include "Configuration.hpp"
#include "Results.hpp"
#include "Kernel.hpp"

void wait_for_enter()
{
    std::cout << "waiting for enter.." << std::endl;
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

void check_core_status_global(Aurora &aurora, size_t timeout_ms, int world_rank, int world_size)
{
    bool local_core_ok;

    // barrier so timeout is working for all configurations 
    MPI_Barrier(MPI_COMM_WORLD);
    local_core_ok = aurora.core_status_ok(3000);

    bool core_ok[world_size];
    MPI_Gather(&local_core_ok, 1, MPI_CXX_BOOL, core_ok, 1, MPI_CXX_BOOL, 0, MPI_COMM_WORLD);

    if (world_rank == 0) {
        int errors = 0;       
        for (int i = 0; i < world_size; i++) {
            if (!core_ok[i]) {
                std::cout << "problem with core " << i % 2 << " on rank " << i << std::endl;
                errors += 1;
            }
        }
        if (errors) {
            MPI_Abort(MPI_COMM_WORLD, errors);
        }
    }
}

int main(int argc, char *argv[])
{
    Configuration config(argc, argv);
 
    MPI_Init(&argc, &argv);

    int world_size , world_rank;
    MPI_Comm_size(MPI_COMM_WORLD , &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD , &world_rank);

    MPI_Comm node_comm;
    MPI_Comm_split_type(MPI_COMM_WORLD, OMPI_COMM_TYPE_NODE, 0, MPI_INFO_NULL, &node_comm);

    int node_rank, node_size;
    MPI_Comm_rank(node_comm, &node_rank);
    MPI_Comm_size(node_comm, &node_size);

    bool emulation = (std::getenv("XCL_EMULATION_MODE") != nullptr);

    uint32_t device_id = emulation ? 0 : (((node_rank / 2) + config.device_id_offset) % 3);

    uint32_t instance = node_rank % 2;

    xrt::device device = xrt::device(device_id);
    xrt::uuid xclbin_uuid = device.load_xclbin(config.xclbin_file);

    if (config.wait) {
        wait_for_enter();
    }

    Aurora aurora;
    if (!emulation) {
        aurora = Aurora(instance, device, xclbin_uuid);
        check_core_status_global(aurora, config.timeout_ms, world_rank, world_size);
        config.finish_setup(aurora.fifo_width, aurora.has_framing(), emulation);
    } else {
        config.finish_setup(64, false, emulation);
    }

    if (world_rank == 0) {
        config.print();
        std::cout << "with " << world_size << " instances" << std::endl;
    }

    // create kernel objects
    IssueKernel issue(instance, device, xclbin_uuid, config);
    DumpKernel dump(instance, device, xclbin_uuid, config);

    Results results(config, aurora, emulation, device, world_size);

    for (uint32_t r = 0; r < config.repetitions; r++) {
        try {
            issue.prepare_repetition(r);
            dump.prepare_repetition(r);

            if (config.test_nfc) {
                if (world_rank == 0) {
                    std::cout << "Testing NFC: waiting 10 seconds before starting the dump kernels" << std::endl;
                }
                aurora.reset_counter();
                aurora.print_fifo_status();
                MPI_Barrier(MPI_COMM_WORLD);        
                issue.start(); 

                std::this_thread::sleep_for(std::chrono::seconds(10));
                std::cout << "Receives before starting dump kernel: " << aurora.get_nfc_latency_count() << std::endl;
                aurora.print_fifo_status();
            }
            MPI_Barrier(MPI_COMM_WORLD);        
            
            dump.start();

            MPI_Barrier(MPI_COMM_WORLD);
            double start_time = get_wtime();

            if (!config.test_nfc) {
                issue.start();
            }

            if (dump.timeout()) {
                std::cout << "Dump timeout" << std::endl;
                results.local_failed_transmissions[r] = 1;
            } else {
                results.local_failed_transmissions[r] = 0;
            }
            if (issue.timeout()) {
                std::cout << "Issue timeout" << std::endl;
                results.local_failed_transmissions[r] = 2;
            }

            results.local_transmission_times[r] = get_wtime() - start_time;
            dump.write_back();
            results.local_errors[r] = dump.compare_data(issue.data.data(), r);
        } catch (const std::runtime_error &e) {
            std::cout << "caught runtime error at repetition " << r << ": " << e.what() << std::endl;
            results.local_failed_transmissions[r] = 3;
        } catch (const std::exception &e) {
            std::cout << "caught unexpected error at repetition " << r << ": " << e.what() << std::endl;
            results.local_failed_transmissions[r] = 4;
        } catch (...) {
            std::cout << "caught non-std::logic_error at repetition " << r << std::endl;
            results.local_failed_transmissions[r] = 5;
        }
        results.update_counter(r);
    }

    results.gather();

    if (world_rank == 0) {
        uint32_t failed_transmissions = results.failed_transmissions();
        if (failed_transmissions) {
            std::cout << failed_transmissions << " failed transmissions" << std::endl;
        } else {
            if (config.test_nfc) {
                std::cout << "NFC test passed" << std::endl;
            } else {
                uint32_t byte_errors = results.byte_errors();
                if (byte_errors) {
                    std::cout << byte_errors << " bytes with errors" << std::endl;
                }

                uint32_t frame_errors = results.frame_errors();
                if (frame_errors) {
                    std::cout << frame_errors << " frames with errors" << std::endl;
                }

            }
        }
        results.print_results();
        results.print_errors();
        results.write();
    }

    MPI_Finalize();
    return results.has_errors();
}

