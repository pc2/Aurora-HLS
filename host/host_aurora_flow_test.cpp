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

int main(int argc, char *argv[])
{
    Configuration config(argc, argv);
 
    bool emulation = (std::getenv("XCL_EMULATION_MODE") != nullptr);

    std::vector<uint32_t> device_ids(config.num_instances / 2);
    std::vector<std::string> device_bdfs(config.num_instances / 2);
    std::vector<xrt::device> devices(config.num_instances / 2);
    std::vector<xrt::uuid> xclbin_uuids(config.num_instances / 2);

    for (uint32_t i = 0; i < config.num_instances / 2 ; i++)  {
        // TODO check emulation behavior
        device_ids[i] = emulation ? 0 : (i + config.device_id);

        std::cout << "programming device " << device_ids[i] << std::endl;

        devices[i] = xrt::device(device_ids[i]);

        xclbin_uuids[i] = devices[i].load_xclbin(config.xclbin_file);

        device_bdfs[i] = devices[i].get_info<xrt::info::device::bdf>();

        std::cout << "programmed device " << device_bdfs[i] << std::endl;
    }

    if (config.wait) {
        wait_for_enter();
    }
    std::vector<Aurora> auroras(config.num_instances);

    if (emulation) {
        config.finish_setup(64, false, emulation);
    } else {
        std::vector<bool> statuses(config.num_instances);
        for (uint32_t i = 0; i < config.num_instances; i++) {
            auroras[i] = Aurora(i % 2, devices[i / 2], xclbin_uuids[i / 2]);
            statuses[i] = auroras[i].core_status_ok(3000);
            if (!statuses[i]) {
                std::cout << "problem with core " << i % 2 
                    << " on device " << device_bdfs[i / 2] 
                    << " with id " << device_ids[i / 2] << std::endl;
            }
        }
        for (bool ok: statuses) {
            if (!ok) exit(EXIT_FAILURE);
        }

        std::cout << "All links are ready" << std::endl;

        if (config.check_status) {
            exit(EXIT_SUCCESS);
        }

        config.finish_setup(auroras[0].fifo_width, auroras[0].has_framing(), emulation);
    }

    /*

    if (world_rank == 0) {
        config.print();
        std::cout << "with " << world_size << " instances" << std::endl;
    }

    std::vector<std::vector<char>> data = generate_data(config.max_num_bytes, world_size);

    // create kernel objects
    IssueKernel issue(world_rank, device, xclbin_uuid, config, data[world_rank]);
    DumpKernel dump(world_rank, device, xclbin_uuid, config);

    Results results(config, aurora, emulation, device, world_size);

    for (uint32_t r = 0; r < config.repetitions; r++) {
        try {
            issue.prepare_repetition(r);
            dump.prepare_repetition(r);

            if (config.test_nfc) {
                if (world_rank == 0) {
                    std::cout << "Testing NFC: waiting 10 seconds before starting the dump kernels" << std::endl;
                }
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
            if (config.test_mode < 3) {
                uint32_t issue_rank = world_rank;
                if (config.test_mode == 1) {
                    // pair
                    issue_rank = (world_rank % 2) == 0 ? world_rank + 1 : world_rank - 1;
                } else if (config.test_mode == 2) {
                    // ring
                    issue_rank = (world_rank % 2) == 0 ? ((uint32_t)world_rank + world_size - 1) % world_size : ((uint32_t)world_rank + 1) % world_size;
                }
                results.local_errors[r] = dump.compare_data(data[issue_rank].data(), r);
            } else {
                // no validation
                results.local_errors[r] = 0;
            }
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
    */
}

