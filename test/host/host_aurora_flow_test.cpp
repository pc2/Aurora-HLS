/*
 * Copyright 2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
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

#include "AuroraFlow.hpp"
#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include "version.h"
#include <fstream>
#include <unistd.h>
#include <vector>
#include <thread>
#include <iostream>
#include <filesystem>
#include <mpi.h>
#include <sysexits.h>

#include "Configuration.hpp"
#include "Results.hpp"
#include "Kernel.hpp"

// can be used for chipscoping
void wait_for_enter()
{
    std::cout << "waiting for enter.." << std::endl;
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

std::vector<std::vector<char>> generate_data(uint32_t num_bytes, uint32_t world_size)
{
    char *slurm_job_id = std::getenv("SLURM_JOB_ID");
    std::vector<std::vector<char>> data;
    data.resize(world_size);
    for (uint32_t r = 0; r < world_size; r++) {
        unsigned int seed = (slurm_job_id == NULL) ? r : (r + ((unsigned int)std::stoi(slurm_job_id)));
        srand(seed);
        data[r].resize(num_bytes);
        for (uint32_t b = 0; b < num_bytes; b++) {
            data[r][b] = rand() % 256;
        }
    }
    return data;
}

uint32_t mode_map(uint32_t instance, uint32_t num_instances, uint32_t mode)
{
    if (mode == 0) {
        return instance;
    } else if (mode == 1) {
        return (instance % 2) == 0 ? instance + 1 : instance - 1;
    } else if (mode == 2) {
        return (instance % 2) == 0 ? ((instance + num_instances - 1) % num_instances) : ((instance + 1) % num_instances);
    } else {
        throw std::invalid_argument("Invalid test mode");
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
    MPI_Init(&argc, &argv);
    int rank = 0, world_size = 1;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    char hostname[MPI_MAX_PROCESSOR_NAME];
    int hostname_length = 0;
    MPI_Get_processor_name(hostname, &hostname_length);
    const std::string log_prefix = "[" + std::string(hostname, hostname_length)
        + ", rank " + std::to_string(rank) + "] ";

    Configuration config(argc, argv);
    config.rank = rank;
    config.world_size = world_size;

    std::cout << log_prefix << "Starting AuroraFlow test with " << world_size << " ranks" << std::endl;

    const char *emu_env = std::getenv("XCL_EMULATION_MODE");
    if (emu_env) {
        config.execution_mode = (std::string(emu_env) == "hw_emu") ? ExecutionMode::hw_emu : ExecutionMode::sw_emu;
        config.num_instances = 2;
    }
    bool emulation = (config.execution_mode != ExecutionMode::hw);

    std::vector<uint32_t> device_ids(config.num_instances / 2);
    std::vector<std::string> device_bdfs(config.num_instances / 2);
    std::vector<xrt::device> devices(config.num_instances / 2);
    std::vector<xrt::uuid> xclbin_uuids(config.num_instances / 2);

    for (uint32_t i = 0; i < config.num_instances / 2 ; i++)  {
        // TODO check emulation behavior
        device_ids[i] = emulation ? 0 : (i + config.device_id);

        device_bdfs[i] = bdf_map(device_ids[i], emulation);

        if (emulation) {
            devices[i] = xrt::device(0);
        } else {
            std::cout << log_prefix << "Programming device " << device_bdfs[i] << std::endl;
            devices[i] = xrt::device(device_bdfs[i]);
        }

        xclbin_uuids[i] = devices[i].load_xclbin(config.xclbin_path);
    }

    MPI_Barrier(MPI_COMM_WORLD);

    if (config.wait) {
        wait_for_enter();
    }
    std::vector<AuroraFlow> auroras(config.num_instances);

    std::vector<bool> statuses(config.num_instances);
    for (uint32_t i = 0; i < config.num_instances; i++) {
        auroras[i] = AuroraFlow(i % 2, devices[i / 2], xclbin_uuids[i / 2]);
        statuses[i] = auroras[i].core_status_ok(3000);
        if (!statuses[i]) {
            std::cout << log_prefix << "Link is not ready on core " << i % 2
                << " on device " << device_bdfs[i / 2]
                << " with id " << device_ids[i / 2] << std::endl;
            if (!emulation) auroras[i].print_core_status();
        }
    }
    for (bool ok: statuses) {
        if (!ok) {
            exit(emulation ? EXIT_FAILURE : EX_TEMPFAIL);
        }
    }

    std::cout << log_prefix << "All links are ready" << std::endl;

    if (config.check_status) {
        exit(EXIT_SUCCESS);
    }

    for (uint32_t i = 1; i < config.num_instances; i++) {
        if (auroras[i].fifo_width != auroras[0].fifo_width
                || auroras[i].has_tkeep != auroras[0].has_tkeep
                || auroras[i].has_tlast != auroras[0].has_tlast) {
            std::cerr << log_prefix << "Error: AuroraFlow instances have incompatible stream configurations" << std::endl;
            exit(EXIT_FAILURE);
        }
    }

    config.finish_setup(auroras[0].fifo_width, auroras[0].has_framing());

    config.print();
    std::cout << log_prefix << "AuroraFlow core has framing " << (auroras[0].has_framing() ? "enabled" : "disabled")
              << " and input width of " << auroras[0].fifo_width << " bytes" << std::endl;

    std::vector<std::vector<char>> data = generate_data(config.max_num_bytes, config.num_instances);

    // create kernel objects
    std::vector<SendKernel> send_kernels(config.num_instances);
    std::vector<RecvKernel> recv_kernels(config.num_instances);
    for (uint32_t i = 0; i < config.num_instances; i++) {
        send_kernels[i] = SendKernel(i % 2, devices[i / 2], xclbin_uuids[i / 2], config, data[i]);
        recv_kernels[i] = RecvKernel(i % 2, devices[i / 2], xclbin_uuids[i / 2], config);
    }

    Results results(config, auroras, device_bdfs);

    MPI_Barrier(MPI_COMM_WORLD);

    for (uint32_t r = 0; r < config.repetitions; r++) {
        std::cout << log_prefix << "Repetition " << r << " with " << config.message_sizes[r] << " bytes" << std::endl;
        if (config.test_mode == 3) {
            try {
                for (auto &send : send_kernels) send.prepare_repetition(r);
                for (auto &recv : recv_kernels) recv.prepare_repetition(r);
                for (auto &recv : recv_kernels) recv.start();
                MPI_Barrier(MPI_COMM_WORLD);

                const auto start = std::chrono::steady_clock::now();
                for (auto &send : send_kernels) send.start();
                for (uint32_t i = 0; i < config.num_instances; ++i) {
                    if (recv_kernels[i].timeout())
                        throw std::runtime_error("Receive timeout on port " + std::to_string(i));
                }
                for (uint32_t i = 0; i < config.num_instances; ++i) {
                    if (send_kernels[i].timeout())
                        throw std::runtime_error("Send timeout on port " + std::to_string(i));
                }
                const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
                for (uint32_t i = 0; i < config.num_instances; ++i) {
                    results.transmission_times[i][r] = elapsed;
                    results.update_counter(i, r);
                    if (config.frame_sizes[r] != 0)
                        results.frames_with_errors[i][r] += recv_kernels[i].read_framing_errors();
                }
            } catch (const std::exception &error) {
                std::cerr << log_prefix << "Concurrent transfer failed: " << error.what() << std::endl;
                MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
                std::exit(EXIT_FAILURE);
            }
            continue;
        }
        for (uint32_t i = 0; i < config.num_instances; i++) {
            uint32_t i_recv = mode_map(i, config.num_instances, config.test_mode);
            SendKernel &send = send_kernels[i];
            RecvKernel &recv = recv_kernels[i_recv];
            AuroraFlow &recv_aurora = auroras[i_recv];
            std::cout << log_prefix << "Sending from " << i << " to " << i_recv << std::endl;
            try {
                send.prepare_repetition(r);
                recv.prepare_repetition(r);
                if (config.nfc_test) {
                    std::cout << log_prefix << "Testing NFC: waiting 3 seconds before starting the recv kernel" << std::endl;
                    if (!emulation) {
                        recv_aurora.print_fifo_status();
                    }
                    send.start(); 

                    std::this_thread::sleep_for(std::chrono::seconds(3));

                    if (!emulation) {
                        recv_aurora.print_fifo_status();
                    }
                }

                recv.start();

                double start_time = get_wtime();

                if (!config.nfc_test) {
                    send.start();
                }

                if (recv.timeout()) {
                    std::cout << log_prefix << "Recv timeout on port " << i_recv << std::endl;
                    results.failed_transmissions[i][r] = 1;
                } else {
                    results.failed_transmissions[i][r] = 0;
                }

                if (send.timeout()) {
                    std::cout << log_prefix << "Send timeout on port " << i << std::endl;
                    results.failed_transmissions[i][r] = 2;
                }

                double end_time = get_wtime();

                if (!emulation && config.nfc_test) {
                    std::cout << log_prefix << "Maximum number of In-Flight-Transmissions: " << recv_aurora.get_nfc_latency_count() << std::endl;
                }

                results.transmission_times[i][r] = end_time - start_time;

                recv.write_back();

                if (config.frame_sizes[r] != 0 && results.failed_transmissions[i][r] == 0) {
                    results.frames_with_errors[i][r] = recv.read_framing_errors();
                    if (results.frames_with_errors[i][r]) {
                        std::cout << log_prefix << results.frames_with_errors[i][r]
                                  << " AXI-Stream framing errors" << std::endl;
                    }
                }

                results.errors[i][r] = recv.compare_data(data[i].data(), r);
                if (results.errors[i][r]) {
                    std::cout << log_prefix << results.errors[i][r] << " byte errors" << std::endl;
                }
            } catch (const std::runtime_error &e) {
                std::cout << log_prefix << "caught runtime error: " << e.what() << std::endl;
                results.failed_transmissions[i][r] = 3;
            } catch (const std::exception &e) {
                std::cout << log_prefix << "caught unexpected error: " << e.what() << std::endl;
                results.failed_transmissions[i][r] = 4;
            } catch (...) {
                std::cout << log_prefix << "caught non-std::logic_error " << std::endl;
                results.failed_transmissions[i][r] = 5;
            }
            if (recv_aurora.has_framing()) {
                if (results.frames_with_errors[i][r]) {
                    std::cout << log_prefix << results.frames_with_errors[i][r] << " frame errors" << std::endl;
                }
            }
        }

        for (uint32_t i = 0; i < config.num_instances; i++) {
            results.update_counter(i, r);
        }
    }

    uint32_t total_failed_transmissions = results.total_failed_transmissions();

    if (total_failed_transmissions) {
        std::cout << log_prefix << total_failed_transmissions << " failed transmissions" << std::endl;
    } else {
        if (config.nfc_test) {
            std::cout << log_prefix << "NFC test passed" << std::endl;
        } else {
            uint32_t total_byte_errors = results.total_byte_errors();
            if (total_byte_errors) {
                std::cout << log_prefix << total_byte_errors << " bytes with errors in total" << std::endl;
            }

            uint32_t total_frame_errors = results.total_frame_errors();
            if (total_frame_errors) {
                std::cout << log_prefix << total_frame_errors << " frames with errors in total" << std::endl;
            }

        }
    }
    results.print_results();
    results.print_errors();
    results.write();

    const int exit_status = results.has_errors();

    if (emulation) {
        // Shut down emulation while all rank peers are still alive.
        std::cout << log_prefix << "Waiting for all ranks before emulator shutdown" << std::endl;
        MPI_Barrier(MPI_COMM_WORLD);
        std::cout << log_prefix << "Stopping emulator links" << std::endl;
        recv_kernels.clear();
        send_kernels.clear();

        for (AuroraFlow &aurora : auroras) aurora.request_shutdown();
        std::cout << log_prefix << "Waiting for emulator links to stop" << std::endl;
        for (AuroraFlow &aurora : auroras) aurora.wait_for_shutdown();
        auroras.clear();
        std::cout << log_prefix << "Emulator links stopped" << std::endl;
    }

    if (emulation) std::cout << log_prefix << "Finalizing MPI" << std::endl;
    MPI_Finalize();
    if (emulation) std::cout << log_prefix << "MPI finalized" << std::endl;
    return exit_status;
}
