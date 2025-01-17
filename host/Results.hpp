class Results
{
public:
    Configuration config;
    std::vector<Aurora> auroras;
    std::vector<std::string> device_bdfs;

    std::vector<uint32_t> aurora_config;
    std::vector<std::vector<double>> transmission_times;
    std::vector<std::vector<uint32_t>> failed_transmissions;
    std::vector<std::vector<uint32_t>> errors;
    std::vector<std::vector<uint32_t>> fifo_rx_overflow_count;
    std::vector<std::vector<uint32_t>> fifo_tx_overflow_count;
    std::vector<std::vector<uint32_t>> nfc_full_trigger_count;
    std::vector<std::vector<uint32_t>> nfc_empty_trigger_count;
    std::vector<std::vector<uint32_t>> nfc_latency_count;
    std::vector<std::vector<uint32_t>> tx_count;
    std::vector<std::vector<uint32_t>> rx_count;
    std::vector<std::vector<uint32_t>> gt_not_ready_0_count;
    std::vector<std::vector<uint32_t>> gt_not_ready_1_count;
    std::vector<std::vector<uint32_t>> gt_not_ready_2_count;
    std::vector<std::vector<uint32_t>> gt_not_ready_3_count;
    std::vector<std::vector<uint32_t>> line_down_0_count;
    std::vector<std::vector<uint32_t>> line_down_1_count;
    std::vector<std::vector<uint32_t>> line_down_2_count;
    std::vector<std::vector<uint32_t>> line_down_3_count;
    std::vector<std::vector<uint32_t>> pll_not_locked_count;
    std::vector<std::vector<uint32_t>> mmcm_not_locked_count;
    std::vector<std::vector<uint32_t>> hard_err_count;
    std::vector<std::vector<uint32_t>> soft_err_count;
    std::vector<std::vector<uint32_t>> channel_down_count;
    std::vector<std::vector<uint32_t>> frames_received;
    std::vector<std::vector<uint32_t>> frames_with_errors;

    bool emulation;

    Results(Configuration &config, std::vector<Aurora> auroras, bool emulation, std::vector<std::string> device_bdfs) : config(config), auroras(auroras), device_bdfs(device_bdfs), emulation(emulation)
    {
        transmission_times.resize(config.num_instances);
        failed_transmissions.resize(config.num_instances);

        fifo_rx_overflow_count.resize(config.num_instances);
        fifo_tx_overflow_count.resize(config.num_instances);
        nfc_full_trigger_count.resize(config.num_instances);
        nfc_empty_trigger_count.resize(config.num_instances);
        nfc_latency_count.resize(config.num_instances);
        errors.resize(config.num_instances);
        frames_received.resize(config.num_instances);
        frames_with_errors.resize(config.num_instances);
        tx_count.resize(config.num_instances);
        rx_count.resize(config.num_instances);
        
        gt_not_ready_0_count.resize(config.num_instances);
        gt_not_ready_1_count.resize(config.num_instances);
        gt_not_ready_2_count.resize(config.num_instances);
        gt_not_ready_3_count.resize(config.num_instances);

        line_down_0_count.resize(config.num_instances);
        line_down_1_count.resize(config.num_instances);
        line_down_2_count.resize(config.num_instances);
        line_down_3_count.resize(config.num_instances);

        pll_not_locked_count.resize(config.num_instances);
        mmcm_not_locked_count.resize(config.num_instances);
        hard_err_count.resize(config.num_instances);
        soft_err_count.resize(config.num_instances);

        channel_down_count.resize(config.num_instances);
        for (uint32_t i = 0; i < config.num_instances; i++) {
            transmission_times[i].resize(config.repetitions);
            failed_transmissions[i].resize(config.repetitions);

            fifo_rx_overflow_count[i].resize(config.repetitions);
            fifo_tx_overflow_count[i].resize(config.repetitions);
            nfc_full_trigger_count[i].resize(config.repetitions);
            nfc_empty_trigger_count[i].resize(config.repetitions);
            nfc_latency_count[i].resize(config.repetitions);
            errors[i].resize(config.repetitions);
            frames_received[i].resize(config.repetitions);
            frames_with_errors[i].resize(config.repetitions);
            tx_count[i].resize(config.repetitions);
            rx_count[i].resize(config.repetitions);
            
            gt_not_ready_0_count[i].resize(config.repetitions);
            gt_not_ready_1_count[i].resize(config.repetitions);
            gt_not_ready_2_count[i].resize(config.repetitions);
            gt_not_ready_3_count[i].resize(config.repetitions);

            line_down_0_count[i].resize(config.repetitions);
            line_down_1_count[i].resize(config.repetitions);
            line_down_2_count[i].resize(config.repetitions);
            line_down_3_count[i].resize(config.repetitions);

            pll_not_locked_count[i].resize(config.repetitions);
            mmcm_not_locked_count[i].resize(config.repetitions);
            hard_err_count[i].resize(config.repetitions);
            soft_err_count[i].resize(config.repetitions);

            channel_down_count[i].resize(config.repetitions);
       }
       if (!emulation) {
            aurora_config.resize(config.num_instances); 
            for (uint32_t i = 0; i < config.num_instances; i++) {
                aurora_config[i] = auroras[i].get_configuration();
                auroras[i].reset_counter();
            }
        }
    }

    void update_counter(uint32_t instance, uint32_t repetition)
    {
        if (!emulation) {
            fifo_rx_overflow_count[instance][repetition] = auroras[instance].get_fifo_rx_overflow_count();
            fifo_tx_overflow_count[instance][repetition] = auroras[instance].get_fifo_tx_overflow_count();
            nfc_full_trigger_count[instance][repetition] = auroras[instance].get_nfc_full_trigger_count();
            nfc_empty_trigger_count[instance][repetition] = auroras[instance].get_nfc_empty_trigger_count();
            nfc_latency_count[instance][repetition] = auroras[instance].get_nfc_latency_count();

            tx_count[instance][repetition] = auroras[instance].get_tx_count();
            rx_count[instance][repetition] = auroras[instance].get_rx_count();

            gt_not_ready_0_count[instance][repetition] = auroras[instance].get_gt_not_ready_0_count();
            gt_not_ready_1_count[instance][repetition] = auroras[instance].get_gt_not_ready_1_count();
            gt_not_ready_2_count[instance][repetition] = auroras[instance].get_gt_not_ready_2_count();
            gt_not_ready_3_count[instance][repetition] = auroras[instance].get_gt_not_ready_3_count();

            line_down_0_count[instance][repetition] = auroras[instance].get_line_down_0_count();
            line_down_1_count[instance][repetition] = auroras[instance].get_line_down_1_count();
            line_down_2_count[instance][repetition] = auroras[instance].get_line_down_2_count();
            line_down_3_count[instance][repetition] = auroras[instance].get_line_down_3_count();

            pll_not_locked_count[instance][repetition] = auroras[instance].get_pll_not_locked_count();
            mmcm_not_locked_count[instance][repetition] = auroras[instance].get_mmcm_not_locked_count();
            hard_err_count[instance][repetition] = auroras[instance].get_hard_err_count();
            soft_err_count[instance][repetition] = auroras[instance].get_soft_err_count();

            channel_down_count[instance][repetition] = auroras[instance].get_channel_down_count();

            if (auroras[instance].has_framing()) {
                frames_received[instance][repetition] = auroras[instance].get_frames_received();
                frames_with_errors[instance][repetition] = auroras[instance].get_frames_with_errors();
            }

            for (uint32_t i = 0; i < config.num_instances; i++) {
                auroras[instance].reset_counter();
            }
        }
   }

    uint32_t total_failed_transmissions()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < config.num_instances; i++) {
            for (uint32_t r = 0; r < config.repetitions; r++) {
                if (failed_transmissions[i][r]) {
                    count++;
                }
            }
        }
        return count;
    }

    uint32_t total_byte_errors()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < config.num_instances; i++) {
            for (uint32_t r = 0; r < config.repetitions; r++) {
                count += errors[i][r];
            }
        }
        return count;
    }

    uint32_t total_frame_errors()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < config.num_instances; i++) {
            for (uint32_t r = 0; r < config.repetitions; r++) {
                count += frames_with_errors[i][r];
            }
        }
        return count;
    }

    uint32_t total_fifo_rx_overflows()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < config.num_instances; i++) {
            for (uint32_t r = 0; r < config.repetitions; r++) {
                count += fifo_rx_overflow_count[i][r];
            }
        }
        return count;
    }

    uint32_t total_nfc_errors()
    {
        uint32_t count = 0;
        for (uint32_t i = 0; i < config.num_instances; i++) {
            for (uint32_t r = 0; r < config.repetitions; r++) {
                count += (nfc_full_trigger_count[i][r] - nfc_empty_trigger_count[i][r]);
            }
        }
        return count;
    }

    bool has_errors()
    {
        return total_failed_transmissions() > 0
            || total_byte_errors() > 0
            || total_frame_errors() > 0
            || total_fifo_rx_overflows() > 0
            || total_nfc_errors() > 0;
    }

    void print_results()
    {
        std::cout << std::setw(36) << "Config" << std::setw(25) << "|"
                  << std::setw(24) << "Latency (s)" << std::setw(12) << "|"
                  << std::setw(27) << "Throughput (Gbit/s)" << std::setw(9) << "|"
                  << std::setw(27) << "Counts per iteration" << std::setw(9) << "|"
                  << std::setw(24) << "Flow Control"
                  << std::endl
                  << std::setw(12) << "Repetition"
                  << std::setw(12) << "Ranks"
                  << std::setw(12) << "Iterations"
                  << std::setw(12) << "Frame Size"
                  << std::setw(12) << "Bytes"
                  << "|" << std::setw(11) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << "|" << std::setw(11) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << "|" << std::setw(11) << "TX"
                  << std::setw(12) << "RX"
                  << std::setw(12) << "Frames"
                  << "|" << std::setw(11) << "Triggered"
                  << std::setw(12) << "Latency"
                  << std::setw(12) << "TX Stalls"
                  << std::endl
                  << std::setw(204) << std::setfill('-') << "-"
                  << std::endl << std::setfill(' ');

        for (uint32_t r = 0; r < config.repetitions; r++) {
            double latency_min = std::numeric_limits<double>::infinity();
            double latency_max = 0.0;
            double latency_sum = 0.0;
            const double gigabits_per_iteration = 8 * config.message_sizes[r] / 1000000000.0;

            uint64_t tx_count_sum = 0;
            uint64_t rx_count_sum = 0;
            uint64_t frame_count_sum = 0;
            uint64_t nfc_full_triggered_sum = 0;
            uint64_t nfc_max_latency = 0;
            uint64_t fifo_tx_stalls_sum = 0;
            for (uint32_t i = 0; i < config.num_instances; i++) {
                double latency = transmission_times[i][r] / config.iterations_per_message[r];
                latency_sum += latency;
                if (latency < latency_min) {
                    latency_min = latency;
                }
                if (latency > latency_max) {
                    latency_max = latency;
                }

                tx_count_sum += tx_count[i][r];
                rx_count_sum += rx_count[i][r];
                frame_count_sum += frames_received[i][r];
                nfc_full_triggered_sum += nfc_full_trigger_count[i][r];
                if (nfc_latency_count[i][r] > nfc_max_latency) {
                    nfc_max_latency = nfc_latency_count[i][r]; 
                }
                fifo_tx_stalls_sum += fifo_tx_overflow_count[i][r];
            }
            double latency_avg = latency_sum / config.num_instances;
            std::cout << std::setw(12) << r
                      << std::setw(12) << config.num_instances
                      << std::setw(12) << config.iterations_per_message[r]
                      << std::setw(12) << config.frame_sizes[r]
                      << std::setw(12) << config.message_sizes[r]
                      << std::setw(12) << latency_min
                      << std::setw(12) << latency_avg
                      << std::setw(12) << latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_avg
                      << std::setw(12) << gigabits_per_iteration / latency_min
                      << std::setw(12) << tx_count_sum / config.iterations_per_message[r] / config.num_instances
                      << std::setw(12) << rx_count_sum / config.iterations_per_message[r] / config.num_instances
                      << std::setw(12) << frame_count_sum / config.iterations_per_message[r] / config.num_instances
                      << std::setw(12) << nfc_full_triggered_sum
                      << std::setw(12) << nfc_max_latency
                      << std::setw(12) << fifo_tx_stalls_sum
                      << std::endl;
        }
    }

    void print_errors()
    {
        std::cout << std::endl 
                  << std::setw(12) << "Repetition"
                  << std::setw(12) << "Bytes"
                  << std::setw(12) << "Failed"
                  << std::setw(12) << "Bytes"
                  << std::setw(12) << "Frames"
                  << std::setw(12) << "FIFO RX"
                  << std::setw(12) << "NFC"
                  << std::setw(12) << "GT 0"
                  << std::setw(12) << "GT 1"
                  << std::setw(12) << "GT 2"
                  << std::setw(12) << "GT 3"
                  << std::setw(12) << "Line 0"
                  << std::setw(12) << "Line 1"
                  << std::setw(12) << "Line 2"
                  << std::setw(12) << "Line 3"
                  << std::setw(12) << "PLL"
                  << std::setw(12) << "MMCM"
                  << std::setw(12) << "Hard err"
                  << std::setw(12) << "Soft err"
                  << std::setw(12) << "Channel"
                  << std::endl
                  << std::setw(240) << std::setfill('-') << "-"
                  << std::endl << std::setfill(' ');

        for (uint32_t r = 0; r < config.repetitions; r++) {
            uint32_t failed_transmissions_sum = 0;
            uint32_t byte_errors_sum = 0;
            uint32_t frame_errors_sum = 0;
            uint32_t status_errors_sum = 0;
            uint32_t fifo_rx_errors_sum = 0;
            uint32_t nfc_full_trigger_sum = 0;
            uint32_t nfc_empty_trigger_sum = 0;
            uint32_t gt_not_ready_0_sum = 0;
            uint32_t gt_not_ready_1_sum = 0;
            uint32_t gt_not_ready_2_sum = 0;
            uint32_t gt_not_ready_3_sum = 0;
            uint32_t line_down_0_sum = 0;
            uint32_t line_down_1_sum = 0;
            uint32_t line_down_2_sum = 0;
            uint32_t line_down_3_sum = 0;
            uint32_t pll_not_locked_sum = 0;
            uint32_t mmcm_not_locked_sum = 0;
            uint32_t hard_err_sum = 0;
            uint32_t soft_err_sum = 0;
            uint32_t channel_down_sum = 0;
            for (uint32_t i = 0; i < config.num_instances; i++) {
                if (failed_transmissions[i][r] > 0) {
                    failed_transmissions_sum++;
                }
                byte_errors_sum += errors[i][r];
                frame_errors_sum += frames_with_errors[i][r];
                fifo_rx_errors_sum += fifo_rx_overflow_count[i][r];
                nfc_full_trigger_sum += nfc_full_trigger_count[i][r];
                nfc_empty_trigger_sum += nfc_empty_trigger_count[i][r];
                gt_not_ready_0_sum += gt_not_ready_0_count[i][r];
                gt_not_ready_1_sum += gt_not_ready_1_count[i][r];
                gt_not_ready_2_sum += gt_not_ready_2_count[i][r];
                gt_not_ready_3_sum += gt_not_ready_3_count[i][r];
                line_down_0_sum += line_down_0_count[i][r];
                line_down_1_sum += line_down_1_count[i][r];
                line_down_2_sum += line_down_2_count[i][r];
                line_down_3_sum += line_down_3_count[i][r];
                pll_not_locked_sum += pll_not_locked_count[i][r];
                mmcm_not_locked_sum += pll_not_locked_count[i][r];
                hard_err_sum += hard_err_count[i][r];
                soft_err_sum += soft_err_count[i][r];
                channel_down_sum += channel_down_count[i][r];
            }
            std::cout << std::setw(12) << r
                      << std::setw(12) << failed_transmissions_sum
                      << std::setw(12) << byte_errors_sum
                      << std::setw(12) << frame_errors_sum
                      << std::setw(12) << status_errors_sum
                      << std::setw(12) << fifo_rx_errors_sum
                      << std::setw(12) << nfc_full_trigger_sum - nfc_empty_trigger_sum
                      << std::setw(12) << gt_not_ready_0_sum
                      << std::setw(12) << gt_not_ready_1_sum
                      << std::setw(12) << gt_not_ready_2_sum
                      << std::setw(12) << gt_not_ready_3_sum
                      << std::setw(12) << line_down_0_sum
                      << std::setw(12) << line_down_1_sum
                      << std::setw(12) << line_down_2_sum
                      << std::setw(12) << line_down_3_sum
                      << std::setw(12) << pll_not_locked_sum
                      << std::setw(12) << mmcm_not_locked_sum
                      << std::setw(12) << hard_err_sum
                      << std::setw(12) << soft_err_sum
                      << std::setw(12) << channel_down_sum
                      << std::endl;
        }
    }

    std::string get_commit_id()
    {
        std::string commit_id;
        FILE *pipe = popen("git describe --always --tags --dirty 2> /dev/null", "r");
        if (pipe) {
            char buf[128];
            while (fgets(buf, 128, pipe) != nullptr) {
                commit_id += buf;
            }
            if (pclose(pipe) != 0) {
                return "none";
            }
        } else {
            return "none";
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
        if (config.num_instances < 7) {
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
            for (uint32_t i = 0; i < config.num_instances; i++) {
                of << hostname << ","
                   << job_id_str << ","
                   << get_commit_id() << ","
                   << xrt_build_version << ","
                   << device_bdfs[i / 2] << ","
                   << i << ","
                   << aurora_config[i] << ","
                   << r << ","
                   << config.test_mode << ","
                   << config.frame_sizes[r] << ","
                   << config.message_sizes[r] << ","
                   << config.iterations_per_message[r] << ","
                   << config.test_nfc << ","
                   << transmission_times[i][r] << ","
                   << rx_count[i][r] << ","
                   << tx_count[i][r] << ","
                   << failed_transmissions[i][r] << ","
                   << fifo_rx_overflow_count[i][r] << ","
                   << fifo_tx_overflow_count[i][r] << ","
                   << nfc_full_trigger_count[i][r] << ","
                   << nfc_empty_trigger_count[i][r] << ","
                   << nfc_latency_count[i][r] << ","
                   << errors[i][r] << ","
                   << gt_not_ready_0_count[i][r] << ","
                   << gt_not_ready_1_count[i][r] << ","
                   << gt_not_ready_2_count[i][r] << ","
                   << gt_not_ready_3_count[i][r] << ","
                   << line_down_0_count[i][r] << ","
                   << line_down_1_count[i][r] << ","
                   << line_down_2_count[i][r] << ","
                   << line_down_3_count[i][r] << ","
                   << pll_not_locked_count[i][r] << ","
                   << mmcm_not_locked_count[i][r] << ","
                   << hard_err_count[i][r] << ","
                   << soft_err_count[i][r] << ","
                   << channel_down_count[i][r] << ","
                   << frames_received[i][r] << ","
                   << frames_with_errors[i][r]
                   << std::endl;
            }
        }
        of.close();

        if (config.semaphore) {
            rename("results.csv.lock", "results.csv");
        }
    }
};
