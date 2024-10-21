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

class Configuration
{
public:
    const char *optstring = "m:o:b:p:i:r:f:nalt:ws";
    // Defaults
    float mega_bytes = 256;
    uint32_t device_id_offset = 0;
    uint32_t override_bytes_num = 0;
    std::string xclbin_file = "aurora_hls_test_hw.xclbin";
    uint32_t repetitions = 1;
    uint32_t iterations = 1;
    uint32_t frame_size = 1;
    bool test_nfc = false;
    bool use_ack = false;
    bool latency_measuring = false;
    uint32_t timeout_ms = 10000; // 10 seconds
    bool wait = false;
    bool semaphore = false;
    // default for now
    bool randomize_data = true;

    uint32_t max_num_bytes = 0;
    std::vector<uint32_t> message_sizes;
    std::vector<uint32_t> iterations_per_message;

    Configuration(int argc, char **argv)
    {
        int opt;

        while ((opt = getopt(argc, argv, optstring)) != -1) {
            if ((opt == 'm') && optarg) {
                mega_bytes = (uint32_t)(std::stod(std::string(optarg)));
            } else if ((opt == 'o') && optarg) {
                device_id_offset = (uint32_t)(std::stoi(std::string(optarg)));
            } else if ((opt == 'b') && optarg) {
                override_bytes_num = (uint32_t)(std::stoi(std::string(optarg)));
            } else if ((opt == 'p') && optarg) {
                xclbin_file = std::string(optarg);
            } else if (opt == 'r' && optarg) {
                repetitions = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'i' && optarg) {
                iterations = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'f' && optarg) {
                frame_size = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'n') {
                test_nfc = true;
            } else if (opt == 'a') {
                use_ack = true;
            } else if (opt == 'l') {
                use_ack = true;
                latency_measuring = true;
            } else if (opt == 't' && optarg) {
                timeout_ms = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'w') {
                wait = true;
            } else if (opt == 's') {
                semaphore = true; 
            }
        }

        if (floor(mega_bytes) == 0 || floor(mega_bytes) != mega_bytes) {
            std::cerr << "Error: argument m must be integer and greater than zero";
            exit(1);
        }

        if (xclbin_file == "") {
            std::cerr << "Error: no bitstream file passed" << std::endl;
            exit(1);
        }

        if (test_nfc) {
            // add initial wait to timeout
            timeout_ms += 10000;
        }

        uint32_t num_bytes = mega_bytes * 1024 * 1024;

        if (override_bytes_num > 0) {
            num_bytes = override_bytes_num; 
            mega_bytes = num_bytes / 1024.0 / 1024.0;
        }

        if ((num_bytes % 64) != 0) {
            std::cout << "Error: number of bytes must be multiple of the channel width (64)" << std::endl;
            exit(1);
        }
        
        if (latency_measuring) {
            // check for power of two
            if (((num_bytes & (num_bytes - 1)) != 0)) {
                std::cout << "Error: number of bytes must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
            if (((frame_size & (frame_size - 1)) != 0)) {
                std::cout << "Error: frame size must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
            // removing all message sizes smaller than channel width and frame size
            repetitions = log2(num_bytes) - 5;
            if (frame_size > 0) {
                repetitions -= log2(frame_size);
            }
        }
        message_sizes.resize(repetitions);
        iterations_per_message.resize(repetitions);
        max_num_bytes = num_bytes;
        if (latency_measuring) {
            double max_throughput = 12500000000.0;
            double expected_latency = iterations * (num_bytes / max_throughput);
            for (uint32_t i = repetitions; i > 0; i--) {
                message_sizes[i - 1] = num_bytes;
                iterations_per_message[i - 1] = iterations;
                num_bytes >>= 1;
                // estimate number of iterations for next repetition
                double estimated_latency = iterations * (num_bytes / max_throughput);
                while (estimated_latency < expected_latency) {
                    iterations++;
                    estimated_latency += 1e-6 + num_bytes / max_throughput;
                }
            }
        } else {
            for (uint32_t i = 0; i < repetitions; i++) {
                message_sizes[i] = num_bytes;
                iterations_per_message[i] = iterations;
            }
        }
    } 

    void print()
    {
        std::cout << std::endl;
        std::cout << "------------------------ aurora test ------------------------" << std::endl;
        std::cout << "Transfer size: " << mega_bytes << " MB" << std::endl;
        std::cout << "Number of bytes: " << max_num_bytes << std::endl; 
        std::cout << "Selected bitstream: " << xclbin_file << std::endl;
        if (frame_size > 0) {
            std::cout << "Frame size: " << frame_size << std::endl;
        }
        if (randomize_data) {
            std::cout << "Random data" << std::endl; 
        } else {
            std::cout << "Ascending data" << std::endl; 
        }
        if (test_nfc) {
            std::cout << "Testing NFC interface" << std::endl;
        }
        if (latency_measuring) {
            std::cout << "Measuring latency with the following configuration:" << std::endl;
            for (uint32_t i = 0; i < repetitions; i++) {
                std::cout << "Repetition " << i << " - " << message_sizes[i] << " bytes - " << iterations_per_message[i] << " iterations" << std::endl;
            }
        } else {
            if (use_ack) {
                std::cout << "Using ack" << std::endl;
            }
            std::cout << iterations << " iterations" << std::endl;
        }
        std::cout << repetitions << " repetitions" << std::endl;
        std::cout << "Issue/Dump timeout: " << timeout_ms << " ms" << std::endl;
    }

};

class Results
{
public:
    Configuration config;
    Aurora aurora;

    std::vector<double> local_transmission_times;
    std::vector<uint32_t> local_failed_transmissions;
    std::vector<uint32_t> local_status_not_ok_count;
    std::vector<uint32_t> local_fifo_rx_overflow_count;
    std::vector<uint32_t> local_fifo_tx_overflow_count;
    std::vector<uint32_t> local_nfc_full_trigger_count;
    std::vector<uint32_t> local_nfc_empty_trigger_count;
    std::vector<uint32_t> local_errors;
    std::vector<uint32_t> local_frames_received;
    std::vector<uint32_t> local_frames_with_errors;
    std::string local_bdf;

    std::vector<double> total_transmission_times;
    std::vector<uint32_t> total_failed_transmissions;
    std::vector<uint32_t> total_status_not_ok_count;
    std::vector<uint32_t> total_fifo_rx_overflow_count;
    std::vector<uint32_t> total_fifo_tx_overflow_count;
    std::vector<uint32_t> total_nfc_full_trigger_count;
    std::vector<uint32_t> total_nfc_empty_trigger_count;
    std::vector<uint32_t> total_errors;
    std::vector<uint32_t> total_frames_received;
    std::vector<uint32_t> total_frames_with_errors;
    std::vector<char> total_bdf_raw;

    std::vector<std::string> total_bdf;
    const int BDF_SIZE = 12; 

    uint32_t start_status_not_ok_count;
    uint32_t start_fifo_rx_overflow_count, start_fifo_tx_overflow_count;
    uint32_t start_frames_received, start_frames_with_errors;
    uint32_t start_nfc_full_trigger_count, start_nfc_empty_trigger_count;

    bool emulation;
    int world_size;

    Results(Configuration &config, Aurora &aurora, bool emulation, xrt::device &device, int32_t world_size) : config(config), aurora(aurora), emulation(emulation), world_size(world_size)
    {
        local_transmission_times.resize(config.repetitions);
        local_failed_transmissions.resize(config.repetitions);
        local_status_not_ok_count.resize(config.repetitions);
        local_fifo_rx_overflow_count.resize(config.repetitions);
        local_fifo_tx_overflow_count.resize(config.repetitions);
        local_nfc_full_trigger_count.resize(config.repetitions);
        local_nfc_empty_trigger_count.resize(config.repetitions);
        local_errors.resize(config.repetitions);
        local_frames_received.resize(config.repetitions);
        local_frames_with_errors.resize(config.repetitions);

        if (!emulation) {

            start_status_not_ok_count = aurora.get_status_not_ok_count();
            start_fifo_rx_overflow_count = aurora.get_fifo_rx_overflow_count();
            start_fifo_tx_overflow_count = aurora.get_fifo_tx_overflow_count();
            start_nfc_full_trigger_count = aurora.get_nfc_full_trigger_count();
            start_nfc_empty_trigger_count = aurora.get_nfc_empty_trigger_count();

            if (aurora.has_framing()) {
                start_frames_received = aurora.get_frames_received();
                start_frames_with_errors = aurora.get_frames_with_errors();
            }
        }

        local_bdf = device.get_info<xrt::info::device::bdf>();
    }

    void set_diff(uint32_t *start, uint32_t *dest, uint32_t value) {
        *dest = value - *start;
        *start = value;
    }

    void update_counter(uint32_t repetition)
    {
        if (!emulation) {
            set_diff(&start_status_not_ok_count, &local_status_not_ok_count[repetition], aurora.get_status_not_ok_count());

            set_diff(&start_fifo_rx_overflow_count, &local_fifo_rx_overflow_count[repetition], aurora.get_fifo_rx_overflow_count());
            set_diff(&start_fifo_tx_overflow_count, &local_fifo_tx_overflow_count[repetition], aurora.get_fifo_tx_overflow_count());

            set_diff(&start_nfc_full_trigger_count, &local_nfc_full_trigger_count[repetition], aurora.get_nfc_full_trigger_count());
            set_diff(&start_nfc_empty_trigger_count, &local_nfc_empty_trigger_count[repetition], aurora.get_nfc_empty_trigger_count());

            if (aurora.has_framing()) {
                set_diff(&start_frames_received, &local_frames_received[repetition], aurora.get_frames_received());
                set_diff(&start_frames_with_errors, &local_frames_with_errors[repetition], aurora.get_frames_with_errors());
            }
        }
   }

    void gather()
    {
        total_transmission_times.resize(config.repetitions * world_size);
        MPI_Gather(local_transmission_times.data(), config.repetitions, MPI_DOUBLE, total_transmission_times.data(), config.repetitions, MPI_DOUBLE, 0, MPI_COMM_WORLD);

        total_failed_transmissions.resize(config.repetitions * world_size);
        MPI_Gather(local_failed_transmissions.data(), config.repetitions, MPI_UNSIGNED, total_failed_transmissions.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_status_not_ok_count.resize(config.repetitions * world_size);
        MPI_Gather(local_status_not_ok_count.data(), config.repetitions, MPI_UNSIGNED, total_status_not_ok_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_fifo_rx_overflow_count.resize(config.repetitions * world_size);
        MPI_Gather(local_fifo_rx_overflow_count.data(), config.repetitions, MPI_UNSIGNED, total_fifo_rx_overflow_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_fifo_tx_overflow_count.resize(config.repetitions * world_size);
        MPI_Gather(local_fifo_tx_overflow_count.data(), config.repetitions, MPI_UNSIGNED, total_fifo_tx_overflow_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_nfc_full_trigger_count.resize(config.repetitions * world_size);
        MPI_Gather(local_nfc_full_trigger_count.data(), config.repetitions, MPI_UNSIGNED, total_nfc_full_trigger_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_nfc_empty_trigger_count.resize(config.repetitions * world_size);
        MPI_Gather(local_nfc_empty_trigger_count.data(), config.repetitions, MPI_UNSIGNED, total_nfc_empty_trigger_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_errors.resize(config.repetitions * world_size);
        MPI_Gather(local_errors.data(), config.repetitions, MPI_UNSIGNED, total_errors.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_frames_received.resize(config.repetitions * world_size);
        MPI_Gather(local_frames_received.data(), config.repetitions, MPI_UNSIGNED, total_frames_received.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_frames_with_errors.resize(config.repetitions * world_size);
        MPI_Gather(local_frames_with_errors.data(), config.repetitions, MPI_UNSIGNED, total_frames_with_errors.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_bdf_raw.resize(BDF_SIZE * world_size);
        MPI_Gather(local_bdf.data(), BDF_SIZE, MPI_CHAR, total_bdf_raw.data(), BDF_SIZE, MPI_CHAR, 0, MPI_COMM_WORLD);

        total_bdf.resize(world_size);
        for (int i = 0; i < world_size; i++) {
            total_bdf[i] = std::string(total_bdf_raw.data() + i * BDF_SIZE, BDF_SIZE);
        }
    }

    // The following functions should be called only from rank 0 after the gather

    uint32_t failed_transmissions()
    {
        uint32_t count = 0;
        for (const auto errorcode: total_failed_transmissions) {
            if (errorcode) {
                count++;
            }
        }
        return count;
    }

    uint32_t byte_errors()
    {
        uint32_t count = 0;
        for (const auto errors: total_errors) {
            count += errors;
        }
        return count;
    }

    uint32_t frame_errors()
    {
        uint32_t count = 0;
        for (const auto errors: total_frames_with_errors) {
            count += errors;
        }
        return count;
    }

    uint32_t fifo_rx_overflows()
    {
        uint32_t count = 0;
        for (const auto overflows: total_fifo_rx_overflow_count) {
            count += overflows;
        }
        return count;
    }

    uint32_t nfc_errors()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < total_nfc_full_trigger_count.size(); i++) {
            count += (total_nfc_full_trigger_count[i] - total_nfc_empty_trigger_count[i]);
        }
        return count;
    }

    uint32_t status_errors()
    {
        uint32_t count = 0;
        for (const auto status: total_status_not_ok_count) {
            count += status;
        }
        return count;
    }

    bool has_errors()
    {
        return failed_transmissions() > 0
            || byte_errors() > 0
            || frame_errors() > 0
            || fifo_rx_overflows() > 0
            || nfc_errors() > 0;
    }

    void print()
    {
        std::cout << std::setw(34) << "Latency (s)"
                  << std::setw(36) << "Throughput (Gbit/s)"
                  << std::setw(18) << "Errors"
                  << std::endl
                  << std::setw(10) << "Bytes"
                  << std::setw(12) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << std::setw(12) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << std::setw(6) << "Full"
                  << std::setw(12) << "Bytes"
                  << std::setw(12) << "Frames"
                  << std::setw(12) << "Status"
                  << std::setw(12) << "FIFO RX"
                  << std::setw(12) << "FIFO TX"
                  << std::setw(12) << "NFC On"
                  << std::setw(12) << "NFC Off"
                  << std::endl
                  << std::setw(174) << std::setfill('-') << "-"
                  << std::endl << std::setfill(' ');

        for (uint32_t r = 0; r < config.repetitions; r++) {
            double latency_min = std::numeric_limits<double>::infinity();
            double latency_max = 0.0;
            double latency_sum = 0.0;
            const double gigabits_per_iteration = 8 * config.message_sizes[r] / 1000000000.0;

            uint32_t failed_transmissions_sum = 0;
            uint32_t byte_errors_sum = 0;
            uint32_t frame_errors_sum = 0;
            uint32_t status_errors_sum = 0;
            uint32_t fifo_rx_errors_sum = 0;
            uint32_t fifo_tx_errors_sum = 0;
            uint32_t nfc_full_trigger_sum = 0;
            uint32_t nfc_empty_trigger_sum = 0;
            for (int32_t i = 0; i < world_size; i++) {
                double latency = total_transmission_times[i * config.repetitions + r] / config.iterations_per_message[r];
                latency_sum += latency;
                if (latency < latency_min) {
                    latency_min = latency;
                }
                if (latency > latency_max) {
                    latency_max = latency;
                }

                if (total_failed_transmissions[i * config.repetitions + r] > 0) {
                    failed_transmissions_sum++;
                }
                byte_errors_sum += total_errors[i * config.repetitions + r];
                frame_errors_sum += total_frames_with_errors[i * config.repetitions + r];
                status_errors_sum += total_status_not_ok_count[i * config.repetitions + r];
                fifo_rx_errors_sum += total_fifo_rx_overflow_count[i * config.repetitions + r];
                fifo_tx_errors_sum += total_fifo_tx_overflow_count[i * config.repetitions + r];
                nfc_full_trigger_sum += total_nfc_full_trigger_count[i * config.repetitions + r];
                nfc_empty_trigger_sum += total_nfc_empty_trigger_count[i * config.repetitions + r];
            }
            double latency_avg = latency_sum / world_size;
            std::cout << std::setw(10) << config.message_sizes[r]
                      << std::setw(12) << latency_min
                      << std::setw(12) << latency_avg
                      << std::setw(12) << latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_avg
                      << std::setw(12) << gigabits_per_iteration / latency_min
                      << std::setw(6) << failed_transmissions_sum
                      << std::setw(12) << byte_errors_sum
                      << std::setw(12) << frame_errors_sum
                      << std::setw(12) << status_errors_sum
                      << std::setw(12) << fifo_rx_errors_sum
                      << std::setw(12) << fifo_tx_errors_sum
                      << std::setw(12) << nfc_full_trigger_sum
                      << std::setw(12) << nfc_empty_trigger_sum
                      << std::endl;
        }
    }

    std::string get_commit_id()
    {
        std::string commit_id;
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen("git describe --always --tags --dirty", "r"), pclose);
        if (pipe) {
            char buf[128];
            while (fgets(buf, 128, pipe.get()) != nullptr) {
                commit_id += buf;
            }
        }
        if (!commit_id.empty() && commit_id.back() == '\n') {
            commit_id.pop_back();
        }
        return commit_id;
    }

    void write()
    {
        char* hostname;
        hostname = new char[100];
        if (world_size < 7) {
            gethostname(hostname, 100);
        } else {
            sprintf(hostname, "NA");
        }

        if (config.semaphore) {
            while (rename("results.csv", "results.csv.lock") != 0) {}
        }

        char *job_id = std::getenv("SLURM_JOB_ID");
        std::string job_id_str(job_id == NULL ? "none" : job_id);

        std::ofstream of;
        of.open(config.semaphore ? "results.csv.lock" : "results.csv", std::ios_base::app);
        for (uint32_t r = 0; r < config.repetitions; r++) {
            for (int core = 0; core < world_size; core++) {
                of << hostname << ","
                   << job_id_str << ","
                   << get_commit_id() << ","
                   << xrt_build_version << ","
                   << total_bdf[core] << ","
                   << core << ","
                   << r << ","
                   << config.frame_size << ","
                   << config.message_sizes[r] << ","
                   << config.iterations_per_message[r] << ","
                   << config.test_nfc << ","
                   << total_transmission_times[core * config.repetitions + r] << ","
                   << total_failed_transmissions[core * config.repetitions + r] << ","
                   << total_status_not_ok_count[core * config.repetitions + r] << ","
                   << total_fifo_rx_overflow_count[core * config.repetitions + r] << ","
                   << total_fifo_tx_overflow_count[core * config.repetitions + r] << ","
                   << total_nfc_full_trigger_count[core * config.repetitions + r] << ","
                   << total_nfc_empty_trigger_count[core * config.repetitions + r] << ","
                   << total_errors[core * config.repetitions + r] << ","
                   << total_frames_received[core * config.repetitions + r] << ","
                   << total_frames_with_errors[core * config.repetitions + r]
                   << std::endl;
            }
        }
        of.close();

        if (config.semaphore) {
            rename("results.csv.lock", "results.csv");
        }
    }
};

class IssueKernel
{
public:
    IssueKernel(uint32_t instance, xrt::device &device, xrt::uuid &xclbin_uuid, Configuration &config) : instance(instance), config(config)
    {
        char name[100];
        snprintf(name, 100, "issue:{issue_%u}", instance);
        kernel = xrt::kernel(device, xclbin_uuid, name);


        data_bo = xrt::bo(device, config.max_num_bytes, xrt::bo::flags::normal, kernel.group_id(1));

        data.resize(config.max_num_bytes);

        char *slurm_job_id = std::getenv("SLURM_JOB_ID");
        unsigned int seed;
        if (slurm_job_id == NULL)
            seed = time(NULL);
        else {
            seed = (unsigned int)std::stoi(slurm_job_id);
        }
        srand(seed);
        for (uint32_t i = 0; i < config.max_num_bytes; i++) {
            data[i] = (config.randomize_data ? rand() : i) % 256;
        }
        data_bo.write(data.data());
        data_bo.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  }

    void prepare_repetition(uint32_t repetition)
    {
        run = xrt::run(kernel);

        run.set_arg(1, data_bo);
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(3, config.frame_size);
        run.set_arg(4, config.iterations_per_message[repetition]);
        run.set_arg(5, config.use_ack);
    }

    void start()
    {
        run.start();
    }

    bool timeout()
    {
        return run.wait(std::chrono::milliseconds(config.timeout_ms)) == ERT_CMD_STATE_TIMEOUT;
    }

    std::vector<char> data;
private:
    xrt::bo data_bo;
    xrt::kernel kernel;
    xrt::run run;
    uint32_t instance;
    Configuration &config;
};

class DumpKernel
{
public:

    DumpKernel(uint32_t instance, xrt::device &device, xrt::uuid &xclbin_uuid, Configuration &config) : instance(instance), config(config)
    {
        char name[100];
        snprintf(name, 100, "dump:{dump_%u}", instance);
        kernel = xrt::kernel(device, xclbin_uuid, name);


        data_bo = xrt::bo(device, config.max_num_bytes, xrt::bo::flags::normal, kernel.group_id(1));

        data.resize(config.max_num_bytes);

    }

    void prepare_repetition(uint32_t repetition)
    {
        run = xrt::run(kernel);

        run.set_arg(1, data_bo);
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(3, config.iterations_per_message[repetition]);
        run.set_arg(4, config.use_ack);
    }

    void start()
    {
        run.start();
    }

    bool timeout()
    {
        return run.wait(std::chrono::milliseconds(config.timeout_ms)) == ERT_CMD_STATE_TIMEOUT;
    }

    void write_back()
    {
        data_bo.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
        data_bo.read(data.data());
    }

    uint32_t compare_data(char *ref, uint32_t repetition)
    {
        uint32_t err_num = 0;
        for (uint32_t i = 0; i < config.message_sizes[repetition]; i++) {
            if (data[i] != ref[i]) {
                if (err_num < 16) {
                    printf("dump[%d] = %02x, issue[%d] = %02x\n", i, (uint8_t)data[i], i, (uint8_t)ref[i]);
                }
                err_num++;
            }
        }
        if (err_num) {
            std::cout << "Data verification FAIL" << std::endl;
            std::cout << "for Dump Kernel " << instance << std::endl;
            std::cout << "in repetition " << repetition << std::endl;
            std::cout << "Total mismatched bytes: " << err_num << std::endl;
            std::cout << "Ratio: " << (double)err_num/(double) config.message_sizes[repetition] << std::endl;
        }
        return err_num;
    }

    std::vector<char> data;

private:
    xrt::bo data_bo;
    xrt::kernel kernel;
    xrt::run run;
    uint32_t instance;
    Configuration &config;
};

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
        if (!aurora.has_framing()) {
            config.frame_size = 0; 
        }
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
                aurora.print_fifo_status();
                issue.start(); 

                std::this_thread::sleep_for(std::chrono::seconds(10));
                if (aurora.has_framing())
                {
                    std::cout << "Frames received before starting dump kernel: " << aurora.get_frames_received() << std::endl;
                }
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
        results.print();
        results.write();
    }

    MPI_Finalize();
    return results.has_errors();
}

