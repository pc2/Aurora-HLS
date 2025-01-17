#pragma once

#include <unistd.h>
#include <cstdint>
#include <string>
#include <vector>
#include <cmath>
#include <iostream>
#include <iomanip>

class Configuration
{
public:
    const char *optstring = "m:d:b:p:i:r:f:nalt:wsc";
    // Defaults
    uint32_t device_id = 0;
    uint32_t num_instances = 6;
    std::string xclbin_file = "aurora_flow_test_hw.xclbin";
    uint32_t repetitions = 1;
    uint32_t iterations = 1;
    bool test_nfc = false;
    uint32_t test_mode = 0;
    bool latency_measuring = false;
    uint32_t timeout_ms = 10000; // 10 seconds
    bool wait = false;
    bool semaphore = false;
    bool check_status = false;

    uint32_t max_frame_size = 128;
    uint32_t max_num_bytes = 1048576;

    std::vector<uint32_t> instances;
    std::vector<uint32_t> message_sizes;
    std::vector<uint32_t> frame_sizes;
    std::vector<uint32_t> iterations_per_message;
    std::vector<std::vector<char>> data;

    Configuration(int argc, char **argv)
    {
        int opt;

        while ((opt = getopt(argc, argv, optstring)) != -1) {
            if ((opt == 'm') && optarg) {
                test_mode = (uint32_t)(std::stoi(std::string(optarg))); 
            } else if ((opt == 'd') && optarg) {
                device_id = (uint32_t)(std::stoi(std::string(optarg)));
                num_instances = 2;
            } else if ((opt == 'b') && optarg) {
                max_num_bytes = (uint32_t)(std::stoi(std::string(optarg)));
            } else if ((opt == 'p') && optarg) {
                xclbin_file = std::string(optarg);
            } else if (opt == 'r' && optarg) {
                repetitions = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'i' && optarg) {
                iterations = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'f' && optarg) {
                max_frame_size = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'n') {
                test_nfc = true;
            } else if (opt == 'l') {
                latency_measuring = true;
            } else if (opt == 't' && optarg) {
                timeout_ms = (uint32_t)(std::stoi(std::string(optarg)));
            } else if (opt == 'w') {
                wait = true;
            } else if (opt == 's') {
                semaphore = true; 
            } else if (opt == 'c') {
                check_status = true;
            }
        }

        if (xclbin_file == "") {
            std::cerr << "Error: no bitstream file passed" << std::endl;
            exit(EXIT_FAILURE);
        }

        if (test_mode == 2 && num_instances == 2) {
            std::cout << "ring test mode is incompatible with single device selection" << std::endl;
            exit(EXIT_FAILURE);
        }

        if (test_nfc) {
            // add initial wait to timeout
            timeout_ms += 10000;
        }

        instances.resize(num_instances);
        for (uint32_t i = 0; i < num_instances; i++) {
            instances[i] = i + (2 * device_id);
        }
    }

    Configuration() {}

    void finish_setup(uint32_t fifo_width, bool has_framing, bool emulation) {
        if ((max_num_bytes % fifo_width ) != 0) {
            std::cout << "Error: number of bytes must be multiple of the fifo width " << fifo_width << std::endl;
            exit(1);
        }
        if (!has_framing) {
            max_frame_size = 0;
        }
        
        if (latency_measuring) {
            // check for power of two
            if (((max_num_bytes & (max_num_bytes - 1)) != 0)) {
                std::cout << "Error: number of bytes must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
            if (has_framing && ((max_frame_size & (max_frame_size - 1)) != 0)) {
                std::cout << "Error: frame size must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
        }
        // removing all message sizes smaller than channel width
        if (latency_measuring) {
            repetitions = log2(max_num_bytes) + 1 - log2(fifo_width);
        }
        message_sizes.resize(repetitions);
        frame_sizes.resize(repetitions);
        iterations_per_message.resize(repetitions);
        if (latency_measuring) {
            uint32_t num_bytes = max_num_bytes;
            const uint32_t max_frame_size_bytes = max_frame_size * fifo_width;
            double max_throughput = 12500000000.0;
            double expected_latency = iterations * (num_bytes / max_throughput);
            for (uint32_t i = repetitions; i > 0; i--) {
                message_sizes[i - 1] = num_bytes;
                iterations_per_message[i - 1] = iterations;
                frame_sizes[i - 1] = max_frame_size_bytes <= num_bytes ? max_frame_size : (num_bytes / fifo_width);
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
                message_sizes[i] = max_num_bytes;
                frame_sizes[i] = max_frame_size;
                iterations_per_message[i] = iterations;
            }
        }
    }

    void print()
    {
        std::cout << "------------------------ AuroraFlow Test ------------------------" << std::endl;
        std::cout << "Selected bitstream: " << xclbin_file << std::endl;
        if (check_status) {
            std::cout << "Checking link status" << std::endl;
            return;
        }
        std::cout << "Max. number of transferred bytes: " << max_num_bytes << std::endl; 
        if (test_mode == 0) {
            std::cout << "Loopback mode with ack" << std::endl;
        } else if (test_mode == 1) {
            std::cout << "Pair mode with ack" << std::endl; 
        } else if (test_mode == 2) {
            std::cout << "Ring mode without ack" << std::endl; 
        } else {
            std::cout << "Unsupported mode without verification" << std::endl; 
        }
        if (max_frame_size > 0) {
            std::cout << "Max. frame size: " << max_frame_size << std::endl;
        }
        if (test_nfc) {
            std::cout << "Testing NFC interface" << std::endl;
        }
        if (latency_measuring) {
            std::cout << "Measuring latency with the following configuration:" << std::endl;
            std::cout << std::setw(12) << "Repetition"
                      << std::setw(12) << "Bytes"
                      << std::setw(12) << "Iterations"
                      << std::setw(12) << "Frame Size"
                      << std::endl
                      << std::setw(48) << std::setfill('-') << "-"
                      << std::endl << std::setfill(' ');

            for (uint32_t i = 0; i < repetitions; i++) {
                std::cout << std::setw(12) << i
                          << std::setw(12) << message_sizes[i]
                          << std::setw(12) << iterations_per_message[i]
                          << std::setw(12) << frame_sizes[i]
                          << std::endl;
            }
        } else {
            std::cout << repetitions << " repetitions" << std::endl;
            std::cout << iterations << " iterations" << std::endl;
        }
        std::cout << "Issue/Dump timeout: " << timeout_ms << " ms" << std::endl;
        std::cout << num_instances << " instances" << std::endl;
        if (semaphore) {
            std::cout << "Locking results.csv for parallel writing" << std::endl;
        }
    }

};

