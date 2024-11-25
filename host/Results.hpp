class Results
{
public:
    Configuration config;
    Aurora aurora;

    std::string local_bdf;
    uint32_t local_aurora_config;
    std::vector<double> local_transmission_times;
    std::vector<uint32_t> local_failed_transmissions;
    std::vector<uint32_t> local_errors;
    std::vector<uint32_t> local_fifo_rx_overflow_count;
    std::vector<uint32_t> local_fifo_tx_overflow_count;
    std::vector<uint32_t> local_nfc_full_trigger_count;
    std::vector<uint32_t> local_nfc_empty_trigger_count;
    std::vector<uint32_t> local_tx_count;
    std::vector<uint32_t> local_rx_count;
    std::vector<uint32_t> local_gt_not_ready_0_count;
    std::vector<uint32_t> local_gt_not_ready_1_count;
    std::vector<uint32_t> local_gt_not_ready_2_count;
    std::vector<uint32_t> local_gt_not_ready_3_count;
    std::vector<uint32_t> local_line_down_0_count;
    std::vector<uint32_t> local_line_down_1_count;
    std::vector<uint32_t> local_line_down_2_count;
    std::vector<uint32_t> local_line_down_3_count;
    std::vector<uint32_t> local_pll_not_locked_count;
    std::vector<uint32_t> local_mmcm_not_locked_count;
    std::vector<uint32_t> local_hard_err_count;
    std::vector<uint32_t> local_soft_err_count;
    std::vector<uint32_t> local_channel_down_count;
    std::vector<uint32_t> local_frames_received;
    std::vector<uint32_t> local_frames_with_errors;

    std::vector<char> total_bdf_raw;
    std::vector<std::string> total_bdf;
    const int BDF_SIZE = 12; 

    std::vector<uint32_t> total_aurora_config;
    std::vector<double> total_transmission_times;
    std::vector<uint32_t> total_failed_transmissions;
    std::vector<uint32_t> total_errors;
    std::vector<uint32_t> total_fifo_rx_overflow_count;
    std::vector<uint32_t> total_fifo_tx_overflow_count;
    std::vector<uint32_t> total_nfc_full_trigger_count;
    std::vector<uint32_t> total_nfc_empty_trigger_count;
    std::vector<uint32_t> total_tx_count;
    std::vector<uint32_t> total_rx_count;
    std::vector<uint32_t> total_gt_not_ready_0_count;
    std::vector<uint32_t> total_gt_not_ready_1_count;
    std::vector<uint32_t> total_gt_not_ready_2_count;
    std::vector<uint32_t> total_gt_not_ready_3_count;
    std::vector<uint32_t> total_line_down_0_count;
    std::vector<uint32_t> total_line_down_1_count;
    std::vector<uint32_t> total_line_down_2_count;
    std::vector<uint32_t> total_line_down_3_count;
    std::vector<uint32_t> total_pll_not_locked_count;
    std::vector<uint32_t> total_mmcm_not_locked_count;
    std::vector<uint32_t> total_hard_err_count;
    std::vector<uint32_t> total_soft_err_count;
    std::vector<uint32_t> total_channel_down_count;
    std::vector<uint32_t> total_frames_received;
    std::vector<uint32_t> total_frames_with_errors;

    bool emulation;
    int world_size;

    Results(Configuration &config, Aurora &aurora, bool emulation, xrt::device &device, int32_t world_size) : config(config), aurora(aurora), emulation(emulation), world_size(world_size)
    {
        local_transmission_times.resize(config.repetitions);
        local_failed_transmissions.resize(config.repetitions);
        local_fifo_rx_overflow_count.resize(config.repetitions);
        local_fifo_tx_overflow_count.resize(config.repetitions);
        local_nfc_full_trigger_count.resize(config.repetitions);
        local_nfc_empty_trigger_count.resize(config.repetitions);
        local_errors.resize(config.repetitions);
        local_frames_received.resize(config.repetitions);
        local_frames_with_errors.resize(config.repetitions);
        local_tx_count.resize(config.repetitions);
        local_rx_count.resize(config.repetitions);
        
        local_gt_not_ready_0_count.resize(config.repetitions);
        local_gt_not_ready_1_count.resize(config.repetitions);
        local_gt_not_ready_2_count.resize(config.repetitions);
        local_gt_not_ready_3_count.resize(config.repetitions);

        local_line_down_0_count.resize(config.repetitions);
        local_line_down_1_count.resize(config.repetitions);
        local_line_down_2_count.resize(config.repetitions);
        local_line_down_3_count.resize(config.repetitions);

        local_pll_not_locked_count.resize(config.repetitions);
        local_mmcm_not_locked_count.resize(config.repetitions);
        local_hard_err_count.resize(config.repetitions);
        local_soft_err_count.resize(config.repetitions);

        local_channel_down_count.resize(config.repetitions);

        local_bdf = device.get_info<xrt::info::device::bdf>();

        if (!emulation) {
            local_aurora_config = aurora.get_configuration();
        }
        aurora.reset_counter();
    }

    void update_counter(uint32_t repetition)
    {
        if (!emulation) {

            local_fifo_rx_overflow_count[repetition] = aurora.get_fifo_rx_overflow_count();
            local_fifo_tx_overflow_count[repetition] = aurora.get_fifo_tx_overflow_count();
            local_nfc_full_trigger_count[repetition] = aurora.get_nfc_full_trigger_count();
            local_nfc_empty_trigger_count[repetition] = aurora.get_nfc_empty_trigger_count();

            local_tx_count[repetition] = aurora.get_tx_count();
            local_rx_count[repetition] = aurora.get_rx_count();

            local_gt_not_ready_0_count[repetition] = aurora.get_gt_not_ready_0_count();
            local_gt_not_ready_1_count[repetition] = aurora.get_gt_not_ready_1_count();
            local_gt_not_ready_2_count[repetition] = aurora.get_gt_not_ready_2_count();
            local_gt_not_ready_3_count[repetition] = aurora.get_gt_not_ready_3_count();

            local_line_down_0_count[repetition] = aurora.get_line_down_0_count();
            local_line_down_1_count[repetition] = aurora.get_line_down_1_count();
            local_line_down_2_count[repetition] = aurora.get_line_down_2_count();
            local_line_down_3_count[repetition] = aurora.get_line_down_3_count();

            local_pll_not_locked_count[repetition] = aurora.get_pll_not_locked_count();
            local_mmcm_not_locked_count[repetition] = aurora.get_mmcm_not_locked_count();
            local_hard_err_count[repetition] = aurora.get_hard_err_count();
            local_soft_err_count[repetition] = aurora.get_soft_err_count();

            local_channel_down_count[repetition] = aurora.get_channel_down_count();

            if (aurora.has_framing()) {
                local_frames_received[repetition] = aurora.get_frames_received();
                local_frames_with_errors[repetition] = aurora.get_frames_with_errors();
            }

            aurora.reset_counter();
        }
   }

    void gather()
    {
        total_transmission_times.resize(config.repetitions * world_size);
        MPI_Gather(local_transmission_times.data(), config.repetitions, MPI_DOUBLE, total_transmission_times.data(), config.repetitions, MPI_DOUBLE, 0, MPI_COMM_WORLD);

        total_failed_transmissions.resize(config.repetitions * world_size);
        MPI_Gather(local_failed_transmissions.data(), config.repetitions, MPI_UNSIGNED, total_failed_transmissions.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

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

        total_tx_count.resize(config.repetitions * world_size);
        MPI_Gather(local_tx_count.data(), config.repetitions, MPI_UNSIGNED, total_tx_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_rx_count.resize(config.repetitions * world_size);
        MPI_Gather(local_rx_count.data(), config.repetitions, MPI_UNSIGNED, total_rx_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_gt_not_ready_0_count.resize(config.repetitions * world_size);
        MPI_Gather(local_gt_not_ready_0_count.data(), config.repetitions, MPI_UNSIGNED, total_gt_not_ready_0_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_gt_not_ready_1_count.resize(config.repetitions * world_size);
        MPI_Gather(local_gt_not_ready_1_count.data(), config.repetitions, MPI_UNSIGNED, total_gt_not_ready_1_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_gt_not_ready_2_count.resize(config.repetitions * world_size);
        MPI_Gather(local_gt_not_ready_2_count.data(), config.repetitions, MPI_UNSIGNED, total_gt_not_ready_2_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_gt_not_ready_3_count.resize(config.repetitions * world_size);
        MPI_Gather(local_gt_not_ready_3_count.data(), config.repetitions, MPI_UNSIGNED, total_gt_not_ready_3_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_line_down_0_count.resize(config.repetitions * world_size);
        MPI_Gather(local_line_down_0_count.data(), config.repetitions, MPI_UNSIGNED, total_line_down_0_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_line_down_1_count.resize(config.repetitions * world_size);
        MPI_Gather(local_line_down_1_count.data(), config.repetitions, MPI_UNSIGNED, total_line_down_1_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_line_down_2_count.resize(config.repetitions * world_size);
        MPI_Gather(local_line_down_2_count.data(), config.repetitions, MPI_UNSIGNED, total_line_down_2_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_line_down_3_count.resize(config.repetitions * world_size);
        MPI_Gather(local_line_down_3_count.data(), config.repetitions, MPI_UNSIGNED, total_line_down_3_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_pll_not_locked_count.resize(config.repetitions * world_size);
        MPI_Gather(local_pll_not_locked_count.data(), config.repetitions, MPI_UNSIGNED, total_pll_not_locked_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_mmcm_not_locked_count.resize(config.repetitions * world_size);
        MPI_Gather(local_mmcm_not_locked_count.data(), config.repetitions, MPI_UNSIGNED, total_mmcm_not_locked_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_hard_err_count.resize(config.repetitions * world_size);
        MPI_Gather(local_hard_err_count.data(), config.repetitions, MPI_UNSIGNED, total_hard_err_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_soft_err_count.resize(config.repetitions * world_size);
        MPI_Gather(local_soft_err_count.data(), config.repetitions, MPI_UNSIGNED, total_soft_err_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

        total_channel_down_count.resize(config.repetitions * world_size);
        MPI_Gather(local_channel_down_count.data(), config.repetitions, MPI_UNSIGNED, total_channel_down_count.data(), config.repetitions, MPI_UNSIGNED, 0, MPI_COMM_WORLD);

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

        total_aurora_config.resize(world_size);
        MPI_Gather(&local_aurora_config, 1, MPI_UNSIGNED, total_aurora_config.data(), 1, MPI_UNSIGNED, 0, MPI_COMM_WORLD);
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

    void print_results()
    {
        std::cout << std::setw(34) << "Latency (s)"
                  << std::setw(36) << "Throughput (Gbit/s)"
                  << std::endl
                  << std::setw(10) << "Bytes"
                  << std::setw(12) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << std::setw(12) << "Min."
                  << std::setw(12) << "Avg."
                  << std::setw(12) << "Max."
                  << std::setw(12) << "TX Count"
                  << std::setw(12) << "RX Count"
                  << std::setw(12) << "Frame Count"
                  << std::endl
                  << std::setw(118) << std::setfill('-') << "-"
                  << std::endl << std::setfill(' ');

        for (uint32_t r = 0; r < config.repetitions; r++) {
            double latency_min = std::numeric_limits<double>::infinity();
            double latency_max = 0.0;
            double latency_sum = 0.0;
            const double gigabits_per_iteration = 8 * config.message_sizes[r] / 1000000000.0;

            uint64_t tx_count_sum = 0;
            uint64_t rx_count_sum = 0;
            uint64_t frame_count_sum = 0;
            for (int32_t i = 0; i < world_size; i++) {
                double latency = total_transmission_times[i * config.repetitions + r] / config.iterations_per_message[r];
                latency_sum += latency;
                if (latency < latency_min) {
                    latency_min = latency;
                }
                if (latency > latency_max) {
                    latency_max = latency;
                }

                tx_count_sum += total_tx_count[i * config.repetitions + r];
                rx_count_sum += total_rx_count[i * config.repetitions + r];
                frame_count_sum += total_frames_received[i * config.repetitions + r];
            }
            double latency_avg = latency_sum / world_size;
            std::cout << std::setw(10) << config.message_sizes[r]
                      << std::setw(12) << latency_min
                      << std::setw(12) << latency_avg
                      << std::setw(12) << latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_max
                      << std::setw(12) << gigabits_per_iteration / latency_avg
                      << std::setw(12) << gigabits_per_iteration / latency_min
                      << std::setw(12) << tx_count_sum / config.iterations_per_message[r] / world_size
                      << std::setw(12) << rx_count_sum / config.iterations_per_message[r] / world_size
                      << std::setw(12) << frame_count_sum / config.iterations_per_message[r] / world_size
                      << std::endl;
        }
    }

    void print_errors()
    {
        std::cout << std::endl 
                  << std::setw(12) << "Bytes"
                  << std::setw(12) << "Failed"
                  << std::setw(12) << "Bytes"
                  << std::setw(12) << "Frames"
                  << std::setw(12) << "FIFO RX"
                  << std::setw(12) << "FIFO TX"
                  << std::setw(12) << "NFC On"
                  << std::setw(12) << "NFC Off"
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
                  << std::setw(252) << std::setfill('-') << "-"
                  << std::endl << std::setfill(' ');

        for (uint32_t r = 0; r < config.repetitions; r++) {
            uint32_t failed_transmissions_sum = 0;
            uint32_t byte_errors_sum = 0;
            uint32_t frame_errors_sum = 0;
            uint32_t status_errors_sum = 0;
            uint32_t fifo_rx_errors_sum = 0;
            uint32_t fifo_tx_errors_sum = 0;
            uint32_t nfc_full_trigger_sum = 0;
            uint32_t nfc_empty_trigger_sum = 0;
            uint32_t tx_count_sum = 0;
            uint32_t rx_count_sum = 0;
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
            for (int32_t i = 0; i < world_size; i++) {
                if (total_failed_transmissions[i * config.repetitions + r] > 0) {
                    failed_transmissions_sum++;
                }
                byte_errors_sum += total_errors[i * config.repetitions + r];
                frame_errors_sum += total_frames_with_errors[i * config.repetitions + r];
                fifo_rx_errors_sum += total_fifo_rx_overflow_count[i * config.repetitions + r];
                fifo_tx_errors_sum += total_fifo_tx_overflow_count[i * config.repetitions + r];
                nfc_full_trigger_sum += total_nfc_full_trigger_count[i * config.repetitions + r];
                nfc_empty_trigger_sum += total_nfc_empty_trigger_count[i * config.repetitions + r];
                tx_count_sum += total_tx_count[i * config.repetitions + r];
                rx_count_sum += total_rx_count[i * config.repetitions + r];
                gt_not_ready_0_sum += total_gt_not_ready_0_count[i * config.repetitions + r];
                gt_not_ready_1_sum += total_gt_not_ready_1_count[i * config.repetitions + r];
                gt_not_ready_2_sum += total_gt_not_ready_2_count[i * config.repetitions + r];
                gt_not_ready_3_sum += total_gt_not_ready_3_count[i * config.repetitions + r];
                line_down_0_sum += total_line_down_0_count[i * config.repetitions + r];
                line_down_1_sum += total_line_down_1_count[i * config.repetitions + r];
                line_down_2_sum += total_line_down_2_count[i * config.repetitions + r];
                line_down_3_sum += total_line_down_3_count[i * config.repetitions + r];
                pll_not_locked_sum += total_pll_not_locked_count[i * config.repetitions + r];
                mmcm_not_locked_sum += total_pll_not_locked_count[i * config.repetitions + r];
                hard_err_sum += total_hard_err_count[i * config.repetitions + r];
                soft_err_sum += total_soft_err_count[i * config.repetitions + r];
                channel_down_sum += total_channel_down_count[i * config.repetitions + r];

            }
            std::cout << std::setw(12) << failed_transmissions_sum
                      << std::setw(12) << byte_errors_sum
                      << std::setw(12) << frame_errors_sum
                      << std::setw(12) << status_errors_sum
                      << std::setw(12) << fifo_rx_errors_sum
                      << std::setw(12) << fifo_tx_errors_sum
                      << std::setw(12) << nfc_full_trigger_sum
                      << std::setw(12) << nfc_empty_trigger_sum
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
                   << total_aurora_config[core] << ","
                   << r << ","
                   << config.frame_size << ","
                   << config.message_sizes[r] << ","
                   << config.iterations_per_message[r] << ","
                   << config.test_nfc << ","
                   << total_transmission_times[core * config.repetitions + r] << ","
                   << total_rx_count[core * config.repetitions + r] << ","
                   << total_tx_count[core * config.repetitions + r] << ","
                   << total_failed_transmissions[core * config.repetitions + r] << ","
                   << total_fifo_rx_overflow_count[core * config.repetitions + r] << ","
                   << total_fifo_tx_overflow_count[core * config.repetitions + r] << ","
                   << total_nfc_full_trigger_count[core * config.repetitions + r] << ","
                   << total_nfc_empty_trigger_count[core * config.repetitions + r] << ","
                   << total_errors[core * config.repetitions + r] << ","
                   << total_gt_not_ready_0_count[core * config.repetitions + r] << ","
                   << total_gt_not_ready_1_count[core * config.repetitions + r] << ","
                   << total_gt_not_ready_2_count[core * config.repetitions + r] << ","
                   << total_gt_not_ready_3_count[core * config.repetitions + r] << ","
                   << total_line_down_0_count[core * config.repetitions + r] << ","
                   << total_line_down_1_count[core * config.repetitions + r] << ","
                   << total_line_down_2_count[core * config.repetitions + r] << ","
                   << total_line_down_3_count[core * config.repetitions + r] << ","
                   << total_pll_not_locked_count[core * config.repetitions + r] << ","
                   << total_mmcm_not_locked_count[core * config.repetitions + r] << ","
                   << total_hard_err_count[core * config.repetitions + r] << ","
                   << total_soft_err_count[core * config.repetitions + r] << ","
                   << total_channel_down_count[core * config.repetitions + r] << ","
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
