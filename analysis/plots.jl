using CairoMakie
using ColorSchemes

const global_scheme = ColorSchemes.seaborn_pastel
const RESOURCE_TYPES = ["LUT", "REG", "BRAM", "DSP", "URAM"]

max_res() = Dict("LUT" => 1303680, "REG" => 2607360, "BRAM" => 2016,
                 "DSP" => 9024, "URAM" => 960)

function plot_over_message_size(df, metric)
    latency = metric == :latency
    fig = Figure(size=(850, 440), fontsize=14)
    ax = Axis(fig[1, 1], title=first(df.variant),
              xscale=log2, yscale=latency ? log10 : identity,
              xlabel="Message size [bytes]",
              ylabel=latency ? "Latency [μs]" : "Throughput [Gbit/s]",
              yminorticksvisible=true, yminorgridvisible=true,
              yminorticks=IntervalsBetween(5), palette=(color=global_scheme,))
    for frame in sort(unique(df.frame_bytes))
        data = sort(df[df.frame_bytes .== frame, :], :message_bytes)
        label = frame == 0 ? "Streaming" : "$frame bytes"
        values = latency ? data.latency .* 1e6 : data.throughput
        lines!(ax, data.message_bytes, values, label=label)
    end
    latency || ylims!(ax, 0, max(100, maximum(df.throughput) * 1.05))
    Legend(fig[1, 2], ax, "Maximum frame payload")
    fig
end

plot_latencies(df) = plot_over_message_size(df, :latency)
plot_throughput(df) = plot_over_message_size(df, :throughput)

function prepare_dataframe_resources(df)
    data = combine(groupby(df, [:framing, :resource]), :value_abs => mean => :value_abs)
    data.value = [row.value_abs / max_res()[row.resource] for row in eachrow(data)]
    data
end

function plot_resources(df)
    data = prepare_dataframe_resources(df)
    categories = sort(unique(data.framing))
    names = [frame == 0 ? "Streaming" : "Framing" for frame in categories]
    fig = Figure(size=(850, 440), fontsize=14)
    ax = Axis(fig[1, 1], title=first(df.variant), xlabel="U280 utilization per core [%]",
              yticks=(1:length(RESOURCE_TYPES), RESOURCE_TYPES),
              palette=(patchcolor=global_scheme,))
    hidespines!(ax, :t, :r, :l)
    hideydecorations!(ax, ticklabels=false)
    barplot!(ax, [findfirst(==(row.resource), RESOURCE_TYPES) for row in eachrow(data)],
             data.value .* 100, direction=:x,
             color=[global_scheme[findfirst(==(frame), categories)] for frame in data.framing],
             dodge=[findfirst(==(frame), categories) for frame in data.framing],
             bar_labels=[string(round(value, digits=1)) for value in data.value_abs],
             label_size=12)
    xlims!(ax, 0, max(0.1, maximum(data.value) * 125))
    Legend(fig[1, 2], [PolyElement(color=global_scheme[i]) for i in eachindex(categories)], names)
    fig
end
