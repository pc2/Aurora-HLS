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

    config.print();

    std::vector<std::vector<char>> data = generate_data(config.max_num_bytes, config.num_instances);

    // create kernel objects
    std::vector<IssueKernel> issue_kernels(config.num_instances);
    std::vector<DumpKernel> dump_kernels(config.num_instances);
    for (uint32_t i = 0; i < config.num_instances; i++) {
        issue_kernels[i] = IssueKernel(i, devices[i / 2], xclbin_uuids[i / 2], config, data[i]);
        dump_kernels[i] = DumpKernel(i, devices[i / 2], xclbin_uuids[i / 2], config);
    }

    Results results(config, auroras, emulation, device_bdfs);

    for (uint32_t r = 0; r < config.repetitions; r++) {
        try {
            for (uint32_t i = 0; i < config.num_instances; i++) {
                issue_kernels[i].prepare_repetition(r);
                dump_kernels[i].prepare_repetition(r);
            }

            if (config.test_nfc) {
                std::cout << "Testing NFC: waiting 10 seconds before starting the dump kernels" << std::endl;
                for (uint32_t i = 0; i < config.num_instances; i++) {
                    auroras[i].print_fifo_status();
                    issue_kernels[i].start(); 
                }

                std::this_thread::sleep_for(std::chrono::seconds(10));
                for (uint32_t i = 0; i < config.num_instances; i++) {
                    std::cout << "Receives on instance " << i << ": " << auroras[i].get_nfc_latency_count() << std::endl;
                    auroras[i].print_fifo_status();
                }
            }
            
            for (uint32_t i = 0; i < config.num_instances; i++) {
                dump_kernels[i].start();
            }

            double start_time = get_wtime();

            if (!config.test_nfc) {
                for (uint32_t i = 0; i < config.num_instances; i++) {
                    issue_kernels[i].start();
                }
            }

            for (uint32_t i = 0; i < config.num_instances; i++) {
                if (dump_kernels[i].timeout()) {
                    std::cout << "Dump " << i << " timeout" << std::endl;
                    results.failed_transmissions[i][r] = 1;
                } else {
                    results.failed_transmissions[i][r] = 0;
                }
            }
            for (uint32_t i = 0; i < config.num_instances; i++) {
                if (issue_kernels[i].timeout()) {
                    std::cout << "Issue " << i << " timeout" << std::endl;
                    results.failed_transmissions[i][r] = 2;
                }
            }

            double end_time = get_wtime();

            for (uint32_t i = 0; i < config.num_instances; i++) {
                results.transmission_times[i][r] = end_time - start_time;
            }
            for (uint32_t i = 0; i < config.num_instances; i++) {
                dump_kernels[i].write_back();
            }
            for (uint32_t i = 0; i < config.num_instances; i++) {
                if (config.test_mode < 3) {
                    uint32_t issue_rank = i;
                    if (config.test_mode == 1) {
                        // pair
                        issue_rank = (i % 2) == 0 ? i + 1 : i - 1;
                    } else if (config.test_mode == 2) {
                        // ring
                        issue_rank = (i % 2) == 0 ? (i + config.num_instances - 1) % config.num_instances : (i + 1) % config.num_instances;
                    }
                    results.errors[i][r] = dump_kernels[i].compare_data(data[issue_rank].data(), r);
                } else {
                    // no validation
                    results.errors[i][r] = 0;
                }
            }
        } catch (const std::runtime_error &e) {
            std::cout << "caught runtime error at repetition " << r << ": " << e.what() << std::endl;
            results.failed_transmissions[0][r] = 3;
        } catch (const std::exception &e) {
            std::cout << "caught unexpected error at repetition " << r << ": " << e.what() << std::endl;
            results.failed_transmissions[0][r] = 4;
        } catch (...) {
            std::cout << "caught non-std::logic_error at repetition " << r << std::endl;
            results.failed_transmissions[0][r] = 5;
        }
        for (uint32_t i = 0; i < config.num_instances; i++) {
            results.update_counter(i, r);
        }
    }

    uint32_t total_failed_transmissions = results.total_failed_transmissions();

    if (total_failed_transmissions) {
        std::cout << total_failed_transmissions << " failed transmissions" << std::endl;
    } else {
        if (config.test_nfc) {
            std::cout << "NFC test passed" << std::endl;
        } else {
            uint32_t total_byte_errors = results.total_byte_errors();
            if (total_byte_errors) {
                std::cout << total_byte_errors << " bytes with errors" << std::endl;
            }

            uint32_t total_frame_errors = results.total_frame_errors();
            if (total_frame_errors) {
                std::cout << total_frame_errors << " frames with errors" << std::endl;
            }

        }
    }
    results.print_results();
    results.print_errors();
    results.write();

    return results.has_errors();
}

