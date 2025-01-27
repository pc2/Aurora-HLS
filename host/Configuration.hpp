#pragma once

#include <unistd.h>
#include <cstdint>
#include <string>
#include <vector>
#include <cmath>
#include <iostream>
#include <iomanip>

#include <cxxopts.hpp>

class Configuration
{
public:
    uint32_t device_id;
    uint32_t num_instances = 6;
    std::string xclbin_path;
    uint32_t repetitions;
    uint32_t iterations;
    uint32_t max_frame_size;
    uint32_t max_num_bytes;
    uint32_t test_mode;
    bool check_status;
    bool nfc_test;
    bool latency_test;
    bool semaphore;
    uint32_t timeout_ms;
    bool wait;

    std::vector<uint32_t> instances;
    std::vector<uint32_t> message_sizes;
    std::vector<uint32_t> frame_sizes;
    std::vector<uint32_t> iterations_per_message;
    std::vector<std::vector<char>> data;

    Configuration(int argc, char **argv)
    {
        cxxopts::Options options("host_aurora_flow_test", "Test program for AuroraFlow");

        options.add_options()
            ("d,device_id", "Device ID according to linkscript", cxxopts::value<uint32_t>()->default_value("0"))
            ("p,xclbin_path", "Path to xclbin file", cxxopts::value<std::string>()->default_value("aurora_flow_test_hw.xclbin"))
            ("r,repetitions", "Repetitions. Will be discarded, when used with -l", cxxopts::value<uint32_t>()->default_value("1"))
            ("i,iterations", "Iterations in one repetition. Will be scaled up, when used with -l", cxxopts::value<uint32_t>()->default_value("1"))
            ("f,frame_size", "Maximum frame size. In multiple of the input width", cxxopts::value<uint32_t>()->default_value("128"))
            ("b,num_bytes", "Maximum number of bytes transferred per iteration. Must be a multiple of the input width", cxxopts::value<uint32_t>()->default_value("1048576"))
            ("m,test_mode", "Topology. 0 for loopback, 1 for pair and 2 for ring", cxxopts::value<uint32_t>()->default_value("0"))
            ("c,check_status", "Check if the link is up and exit", cxxopts::value<bool>()->default_value("false"))
            ("n,nfc_test", "NFC Test. Recv Kernel will be started 3 seconds later then the Send kernel.", cxxopts::value<bool>()->default_value("false"))
            ("l,latency_test", "Creates one repetition for every message size, up to the maximum", cxxopts::value<bool>()->default_value("false"))
            ("s,semaphore", "Locks the results file. Needed for parallel evaluation", cxxopts::value<bool>()->default_value("false"))
            ("t,timeout_ms", "Timeout in ms", cxxopts::value<uint32_t>()->default_value("10000"))
            ("w,wait", "Wait for enter after loading bitstream. Needed for chipscope", cxxopts::value<bool>()->default_value("false"))
            ("h,help", "Print usage");

        auto result = options.parse(argc, argv);

        if (result.count("help")) {
            std::cout << options.help() << std::endl;     
            exit(EXIT_SUCCESS);
        }

        device_id = result["device_id"].as<uint32_t>();
        
        if (result.count("device_id") > 0) {
            num_instances = 2;
        }

        xclbin_path = result["xclbin_path"].as<std::string>();
        repetitions = result["repetitions"].as<uint32_t>();
        iterations = result["iterations"].as<uint32_t>();
        max_frame_size = result["frame_size"].as<uint32_t>();
        max_num_bytes = result["num_bytes"].as<uint32_t>();
        test_mode = result["test_mode"].as<uint32_t>();
        check_status = result["check_status"].as<bool>();
        nfc_test = result["nfc_test"].as<bool>();
        latency_test = result["latency_test"].as<bool>();
        semaphore = result["semaphore"].as<bool>();
        timeout_ms = result["timeout_ms"].as<uint32_t>();
        wait = result["wait"].as<bool>();

        if (xclbin_path == "") {
            std::cerr << "Error: no bitstream file passed" << std::endl;
            exit(EXIT_FAILURE);
        }

        if (test_mode == 2 && num_instances == 2) {
            std::cout << "ring test mode is incompatible with single device selection" << std::endl;
            exit(EXIT_FAILURE);
        }

        if (nfc_test) {
            // add initial wait to timeout
            timeout_ms += 10000;
        }

    }

    Configuration() {}

    void finish_setup(uint32_t fifo_width, bool has_framing, bool emulation) {
        if ((max_num_bytes % fifo_width ) != 0) {
            std::cout << "Error: number of bytes must be multiple of the fifo width " << fifo_width << std::endl;
            exit(EXIT_FAILURE);
        }

        if (emulation) {
            if (test_mode == 0) {
                xclbin_path = "aurora_flow_test_sw_emu_loopback.xclbin";
            } else {
                std::cout << "Error: unsupported test mode for emulation" << std::endl;
                exit(EXIT_FAILURE);
            }
        }
        
        instances.resize(num_instances);
        for (uint32_t i = 0; i < num_instances; i++) {
            uint32_t i_inst = i + (2 * device_id);
            instances[i] = emulation ? i_inst : i_inst % 2;
        }

        if (!has_framing) {
            max_frame_size = 0;
        }

        if (latency_test) {
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
        if (latency_test) {
            repetitions = log2(max_num_bytes) + 1 - log2(fifo_width);
        }
        message_sizes.resize(repetitions);
        frame_sizes.resize(repetitions);
        iterations_per_message.resize(repetitions);
        if (latency_test) {
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
        std::cout << "Selected bitstream: " << xclbin_path << std::endl;
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
        if (nfc_test) {
            std::cout << "Testing NFC interface" << std::endl;
        }
        if (latency_test) {
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

