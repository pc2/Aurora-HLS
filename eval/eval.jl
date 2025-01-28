using CSV
using DataFrames
using Statistics

file = "results.csv"

results = CSV.read(file, DataFrame, header = [
    "hostname",
    "job_id",
    "commit_id",
    "xrt_version",
    "bdf",
    "rank",
    "config",
    "repetition",
    "testmode",
    "frame_size",
    "message_size",
    "iterations",
    "test_nfc",        
    "transmission_time",
    "rx_count",
    "tx_count",
    "failed_transmissions",
    "fifo_rx_overflow_count",
    "fifo_tx_overflow_count",
    "nfc_on",
    "nfc_off",
    "nfc_latency",
    "byte_errors",
    "gt_not_ready_0",
    "gt_not_ready_1",
    "gt_not_ready_2",
    "gt_not_ready_3",
    "line_down_0",
    "line_down_1",
    "line_down_2",
    "line_down_3",
    "pll_not_locked",
    "mmcm_not_locked",
    "hard_err",
    "soft_err",
    "channel_down",
    "frames_received",
    "frames_with_errors"
])

results.fpga = results.hostname .* "_" .* results.bdf 
results.port = results.fpga .* "_" .* string.(results.rank .% 2)
results.fifo_width = (results.config .& 0x7fc) .>> 2;
results.latency = results.transmission_time ./ results.iterations
results.throughput = results.message_size ./ results.latency
results.throughput_gbit_s = results.throughput * 8 / 1e9
results.nfc_status = results.nfc_off .- results.nfc_on

function check(df, by)
    sort(
        combine(
            groupby(df, by),
            nrow => :count,
            :failed_transmissions => sum => :failed_transmissions,
            :byte_errors => sum => :byte_errors,
            :frames_with_errors => sum => :frame_errors,
            :fifo_rx_overflow_count => sum => :fifo_rx_overflows,
            :fifo_tx_overflow_count => sum => :fifo_tx_overflows,
            :nfc_on => sum => :nfc_on,
            :nfc_off => sum => :nfc_off,
            :nfc_status => sum => :nfc_status,
            :nfc_latency => maximum => :nfc_latency,
            :latency => minimum => :latency_min,
            :throughput_gbit_s => maximum => :throughput_max,
        ),
        by
    )
end

display(check(results, :hostname))
display(check(results, :fpga))
display(check(results, :port))
display(check(results, :testmode))

function check_error_type(df, by)
    sort(
        unstack(
            combine(
                groupby(df, [by, :failed_transmissions]),
                nrow => :count
            ),
            :failed_transmissions,
            :count,
        ),
        by
    )
end

display(check_error_type(results, :hostname))
display(check_error_type(results, :fpga))
display(check_error_type(results, :port))

function aggregate_means(df)
    combine(
        groupby(df, [:frame_size, :message_size]),
        :latency => minimum => :latency_min,
        :latency => mean => :latency_avg,
        :latency => maximum => :latency_max,
        :throughput => minimum => :throughput_min,
        :throughput => mean => :throughput_avg,
        :throughput => maximum => :throughput_max,
        :throughput_gbit_s => minimum => :throughput_gbit_s_min,
        :throughput_gbit_s => mean => :throughput_gbit_s_avg,
        :throughput_gbit_s => maximum => :throughput_gbit_s_max,
        nrow => :count,
        :failed_transmissions => sum => :failed_transmissions,
        :byte_errors => sum => :byte_errors,
        :frames_with_errors => sum => :frames_with_errors,
        :fifo_rx_overflow_count => sum => :fifo_rx_overflow_count,
        :fifo_tx_overflow_count => sum => :fifo_tx_overflow_count,
        :nfc_on => sum => :nfc_on,
        :nfc_off => sum => :nfc_off,
        :nfc_status => sum => :nfc_status,
        :nfc_latency => maximum => :nfc_latency_max,
    )
end

means = aggregate_means(results)

#means_32 = aggregate_means(filter(:fifo_width => ==(32), results))
means_64 = aggregate_means(filter(:fifo_width => ==(64), results))

function tabulate(df, value)
    unstacked = unstack(
        df,
        :message_size,
        :frame_size,
        value
    )
    unstacked[:,vcat(
        ["message_size"],
        sort(setdiff(names(unstacked), ["message_size"]), by = fs -> parse(Int, fs))
    )]
end

function eval_error(error_symbol, error_string)
    if nrow(filter(row -> (row[error_symbol] > 0), results)) > 0
        println(error_string)
        println(tabulate(means, error_symbol))
    else
        println("No ", error_string)
    end

end

display(tabulate(means, :count))

eval_error(:failed_transmissions, "Failed Transmissions")

eval_error(:byte_errors, "Byte Errors")

eval_error(:frames_with_errors, "Frame Errors")

eval_error(:fifo_rx_overflow_count, "FIFO RX Overflows")

eval_error(:nfc_status, "NFC Errors")