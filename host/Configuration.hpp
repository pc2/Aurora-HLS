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

        max_num_bytes = mega_bytes * 1024 * 1024;

        if (override_bytes_num > 0) {
            max_num_bytes = override_bytes_num; 
            mega_bytes = max_num_bytes / 1024.0 / 1024.0;
        }
    }

    void finish_setup(uint32_t fifo_width, bool has_framing, bool emulation) {
        if ((max_num_bytes % fifo_width ) != 0) {
            std::cout << "Error: number of bytes must be multiple of the fifo width " << fifo_width << std::endl;
            exit(1);
        }
        if (!has_framing) {
            frame_size = 0;
        }
        
        if (latency_measuring) {
            // check for power of two
            if (((max_num_bytes & (max_num_bytes - 1)) != 0)) {
                std::cout << "Error: number of bytes must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
            if (has_framing && ((frame_size & (frame_size - 1)) != 0)) {
                std::cout << "Error: frame size must be a power of two for measuring the latency" << std::endl;
                exit(1);
            }
            // removing all message sizes smaller than channel width and frame size
            repetitions = log2(max_num_bytes) + 1 - log2(fifo_width);
            if (frame_size > 0) {
                repetitions -= log2(frame_size);
            }
        }
        message_sizes.resize(repetitions);
        iterations_per_message.resize(repetitions);
        if (latency_measuring) {
            uint32_t num_bytes = max_num_bytes;
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
                message_sizes[i] = max_num_bytes;
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
            std::cout << std::setw(12) << "Repetition"
                      << std::setw(12) << "Bytes"
                      << std::setw(12) << "Iterations"
                      << std::endl
                      << std::setw(36) << std::setfill('-') << "-"
                      << std::endl << std::setfill(' ');

            for (uint32_t i = 0; i < repetitions; i++) {
                std::cout << std::setw(12) << i
                          << std::setw(12) << message_sizes[i]
                          << std::setw(12) << iterations_per_message[i]
                          << std::endl;
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

