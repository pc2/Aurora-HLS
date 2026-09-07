using CSV
using DataFrames
using JSON3
using Statistics

const CSV_COLUMNS = [
    :node, :slurm_job, :commit, :xrt, :device, :instance, :configuration,
    :repetition, :mode, :frame_words, :message_bytes, :iterations, :nfc_test,
    :elapsed_seconds, :rx_count, :tx_count, :failed_transmissions,
    :rx_overflow, :tx_almost_full, :nfc_full, :nfc_empty, :nfc_latency,
    :byte_errors, :gt0, :gt1, :gt2, :gt3, :line0, :line1, :line2, :line3,
    :pll, :mmcm, :hard_errors, :soft_errors, :channel_down, :frames,
    :frame_errors,
]

read_json(path) = JSON3.read(read(path, String), Dict{String, Any})

function variant(matrix)
    width = parse(Int, matrix["WIDTH"])
    clock = parse(Int, matrix["AXI_CLOCK_HZ"]) ÷ 1_000_000
    bridge = get(matrix, "CLOCK_BRIDGE", "0") == "1" ? ", bridge" : ""
    "$clock MHz, $(8width) bit$bridge, XRT $(matrix["XRT"])"
end

function result_directory(root, result)
    local_result = get(result, "local", nothing)
    isnothing(local_result) && return nothing
    get(local_result, "kind", "") == "success" || return nothing
    path = get(local_result, "result_path", nothing)
    isnothing(path) && return nothing
    directory = realpath(joinpath(root, path))
    relative = relpath(directory, root)
    (relative == ".." || startswith(relative, "../") || relative == ".") && error("Result directory escapes collection.")
    directory
end

function benchmark_points(path, matrix)
    data = CSV.read(path, DataFrame, header=CSV_COLUMNS)
    ncol(data) == length(CSV_COLUMNS) || error("Unexpected benchmark CSV columns.")
    nrow(data) > 0 || error("Empty benchmark CSV.")
    all(data.iterations .> 0) && all(isfinite.(data.elapsed_seconds) .& (data.elapsed_seconds .> 0)) || error("Invalid benchmark timing.")
    all(data.mode .== 1) && all(data.nfc_test .== 0) || error("Expected the pair benchmark without deliberate NFC pressure.")
    all(data.failed_transmissions .== 0) && all(data.byte_errors .== 0) && all(data.frame_errors .== 0) || error("Benchmark contains failed transfers.")
    hls_width = parse(Int, get(matrix, "HLS_WIDTH", matrix["WIDTH"]))
    frame_bytes = parse(Int, matrix["FRAME_SIZE"]) * hls_width
    data.latency = data.elapsed_seconds ./ data.iterations
    summary = combine(groupby(data, :message_bytes), :latency => mean => :latency,
                      :latency => minimum => :latency_min,
                      :latency => maximum => :latency_max,
                      nrow => :instances)
    summary.variant .= variant(matrix)
    summary.frame_bytes .= frame_bytes
    summary.throughput = summary.message_bytes .* 8 ./ summary.latency ./ 1e9
    sort!(summary, :message_bytes)
end

function resource_points(path, matrix)
    data = read_json(path)
    data["schema_version"] == 1 && data["design_state"] == "routed" || error("Expected routed core utilization.")
    cores = data["cores"]
    sort([core["name"] for core in cores]) == ["aurora_flow_0", "aurora_flow_1"] || error("Expected both AuroraFlow cores.")
    DataFrame([
        (variant=variant(matrix), framing=parse(Int, matrix["FRAMING"]),
         core=core["name"], resource=resource, value_abs=Float64(core["resources"][resource]))
        for core in cores for resource in ["LUT", "REG", "BRAM", "DSP", "URAM"]
    ])
end

function load_results(path)
    root = dirname(abspath(path))
    snapshot = read_json(path)
    snapshot["schema"] == "hpc-ci/result-set" || error("Expected a collected HPC result set.")
    benchmarks = DataFrame()
    resources = DataFrame()
    sources = NamedTuple[]
    for result in snapshot["results"]
        kind = result["job_name"]
        kind in ["benchmark", "hw-build"] || continue
        matrix = result["matrix"]
        directory = result_directory(root, result)
        filename = kind == "benchmark" ? "benchmark.csv" : "core-resources.json"
        available = !isnothing(directory) && isfile(joinpath(directory, filename))
        producer = get(result, "producer", nothing)
        producer = isnothing(producer) ? Dict() : producer
        job_url = get(get(producer, "job", Dict()), "url", "")
        if available
            points = kind == "benchmark" ? benchmark_points(joinpath(directory, filename), matrix) : resource_points(joinpath(directory, filename), matrix)
            points.content_key .= result["content_key"]
            points.job_url .= job_url
            append!(kind == "benchmark" ? benchmarks : resources, points, cols=:union)
        end
        push!(sources, (variant=variant(matrix), kind=kind,
                       framing=matrix["FRAMING"], frame_words=get(matrix, "FRAME_SIZE", ""),
                       available=available, content_key=result["content_key"], job_url=job_url))
    end
    (benchmarks=benchmarks, resources=resources, sources=DataFrame(sources))
end
