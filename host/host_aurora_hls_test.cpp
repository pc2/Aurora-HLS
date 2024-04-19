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

#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include <iostream>
#include <iomanip>
#include <fstream>
#include <bitset>
#include <cmath>
#include <unistd.h>
#include <vector>
#include <thread>
#include <omp.h>
#include <mpi.h>
#include "Aurora.hpp"

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

        if (num_bytes < 64) {
            std::cout << "Error: number of bytes must be larger than the channel width (64)" << std::endl;
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
            for (uint32_t i = repetitions; i > 0; i--) {
                message_sizes[i - 1] = num_bytes;
                num_bytes >>= 1;
                iterations_per_message[i - 1] = iterations;
                iterations <<= 1;
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
    void write_results(uint32_t world_size, double *transmission_times)
    {
        char* hostname;
        hostname = new char[100];
        if (world_size < 7) {
            gethostname(hostname, 100);
        } else {
            sprintf(hostname, "NA");
        }

        if (semaphore) {
            while (rename("results.csv", "results.csv.lock") != 0) {}
        }

        std::ofstream of;
        of.open(semaphore ? "results.csv.lock" : "results.csv", std::ios_base::app);
        for (uint32_t i = 0; i < repetitions; i++) {
            for (uint32_t core = 0; core < world_size; core++) {
                of << hostname << "," << i << "," << core << "," << frame_size << "," << message_sizes[i] 
                    << "," << iterations_per_message[i] << "," << transmission_times[core * repetitions + i] << "," << use_ack << std::endl;
            }
        }
        of.close();

        if (semaphore) {
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

        run = xrt::run(kernel);

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

        run.set_arg(1, data_bo);
        run.set_arg(3, config.frame_size);
        run.set_arg(5, config.use_ack);
   }

    void prepare_repetition(uint32_t repetition)
    {
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(4, config.iterations_per_message[repetition]);
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

        run = xrt::run(kernel);

        data_bo = xrt::bo(device, config.max_num_bytes, xrt::bo::flags::normal, kernel.group_id(1));

        data.resize(config.max_num_bytes);

        run.set_arg(1, data_bo);
        run.set_arg(4, config.use_ack);

        if (config.test_nfc) {
            run.set_arg(5, config.test_nfc);
        }
    }

    void prepare_repetition(uint32_t repetition)
    {
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(3, config.iterations_per_message[repetition]);
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

    void compare_data(char *ref, uint32_t repetition)
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

    if (world_rank == 0) {
        config.print();
        std::cout << "with " << world_size << " instances" << std::endl;
    }
    xrt::device device = xrt::device(device_id);
    xrt::uuid xclbin_uuid = device.load_xclbin(config.xclbin_file);

    if (config.wait) {
        wait_for_enter();
    }

    // create kernel objects
    IssueKernel issue(instance, device, xclbin_uuid, config);
    DumpKernel dump(instance, device, xclbin_uuid, config);
    
    Aurora aurora;
    if (!emulation) {
        aurora = Aurora(instance, device, xclbin_uuid);
        int errors = aurora.check_core_status_global(config.timeout_ms, world_rank, world_size);
        if (errors)
        {
            MPI_Abort(MPI_COMM_WORLD, errors);
        }
        if (!aurora.has_framing()) {
            config.frame_size = 0; 
        }
    }

    double local_transmission_times[config.repetitions];
    for (uint32_t r = 0; r < config.repetitions; r++) {
        issue.prepare_repetition(r);
        dump.prepare_repetition(r);

        if (config.test_nfc) {
            if (world_rank == 0) {
                std::cout << "Testing NFC: waiting 10 seconds before starting the dump kernels" << std::endl;
            }
            issue.start(); 

            std::this_thread::sleep_for(std::chrono::seconds(10));
            aurora.print_fifo_status();
            std::cout << "Frames received before starting dump kernel: " << aurora.get_frames_received() << std::endl;
        }
        MPI_Barrier(MPI_COMM_WORLD);        

        double start_time, finish_time;
        bool rx_success;
        
        dump.start();

        MPI_Barrier(MPI_COMM_WORLD);
        start_time = get_wtime();

        if (!config.test_nfc) {
            issue.start();
        }

        if (dump.timeout()) {
            if (!emulation) {
                aurora.print_core_status("dump timeout");
            }
            rx_success = false;
        } else {
            finish_time = get_wtime();
            rx_success = true;
        }

        if (issue.timeout()) {
            std::cout << "Issue timeout. Something is terribly wrong!" << std::endl;
        }

        if (rx_success) {
            local_transmission_times[r] = finish_time - start_time;

            dump.write_back();
        
            dump.compare_data(issue.data.data(), r);
        }
    }
    double total_transmission_times[config.repetitions * world_size];
    MPI_Gather(local_transmission_times, config.repetitions, MPI_DOUBLE, total_transmission_times, config.repetitions, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    if (config.test_nfc) {
        std::cout << "NFC test passed" << std::endl;
    } else {
        double total_transmission_times[config.repetitions * world_size];
        MPI_Gather(local_transmission_times, config.repetitions, MPI_DOUBLE, total_transmission_times, config.repetitions, MPI_DOUBLE, 0, MPI_COMM_WORLD);
        if (world_rank == 0) {
            uint32_t failed_transmissions = 0;
            double average_transmission_time = 0.0;
            double average_throughput = 0.0;
            double transmission_time_sum = 0.0;
            for (uint32_t i = 0; i < config.repetitions * world_size; i++) {
                if (total_transmission_times[i] != 0.0) {
                    transmission_time_sum += total_transmission_times[i];
                } else {
                    failed_transmissions += 1;
                }
            }
            if (failed_transmissions) {
                std::cout << failed_transmissions << " failed transmissions" << std::endl;
            } else {
                average_transmission_time = transmission_time_sum / world_size;
                double total_gigabits = 0.0;
                for (uint32_t r = 0; r < config.repetitions; r++) {
                    double gigabits_per_iteration = 8 * config.message_sizes[r] / 1000000000.0;
                    total_gigabits += gigabits_per_iteration * config.iterations_per_message[r];
                }
                average_throughput = total_gigabits / average_transmission_time;
                std::cout << "All correct, average throughput: " << average_throughput << " Gbit/s" << std::endl;
            }
            config.write_results(world_size, total_transmission_times);
        }
    }

    printf("Total frames received: %d\n", aurora.get_frames_received());
    printf("Frames with errors: %d\n", aurora.get_frames_with_errors());

    MPI_Finalize();
}
