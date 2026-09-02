#!/usr/bin/env bash
set -euo pipefail

build_dir="${1:?usage: $0 BUILD_DIR [hw|hw_emu]}"
target="${2:-hw_emu}"
case "${target}" in
    hw|hw_emu) ;;
    *)
        echo "target must be hw or hw_emu" >&2
        exit 2
        ;;
esac

link_summary="${build_dir}/_x_aurora_flow_test_${target}/link/int/automation_summary.txt"
bd_tcl="${build_dir}/_x_aurora_flow_test_${target}/link/int/dr.bd.tcl"
bridge_xo="${build_dir}/aurora_flow_clock_bridge.xo"

test -s "${link_summary}"
test -s "${bd_tcl}"
test -s "${bridge_xo}"

has_link() {
    local source="$1"
    local destination="$2"
    awk -v source="${source}" -v destination="${destination}" '
        $0 == "Source Pin: " source {
            if (getline > 0 && $0 == "Destination Pin: " destination)
                found = 1
        }
        END { exit(found ? 0 : 1) }
    ' "${link_summary}"
}

expect_link() {
    local source="$1"
    local destination="$2"
    if ! has_link "${source}" "${destination}"; then
        echo "unexpected Vitis link: ${source} -> ${destination} is missing" >&2
        exit 1
    fi
}

expect_link_or_axis_cdc() {
    local source="$1"
    local destination="$2"
    local cdc="$3"

    if has_link "${source}" "${destination}"; then
        return
    fi

    expect_link "${source}" "${cdc}/S_AXIS"
    expect_link "${cdc}/M_AXIS" "${destination}"
    if ! grep -Fq \
            "xilinx.com:ip:axis_clock_converter:1.1 ${cdc}" "${bd_tcl}"; then
        echo "unexpected Vitis link: ${cdc} is not an AXI clock converter" >&2
        exit 1
    fi
}

link_source() {
    local destination="$1"
    awk -v destination="${destination}" '
        /^Source Pin: / { source = substr($0, 13) }
        $0 == "Destination Pin: " destination { print source; exit }
    ' "${link_summary}"
}

for instance in 0 1; do
    expect_link_or_axis_cdc \
        "send_${instance}/data_output" \
        "clock_bridge_${instance}/hls_tx" \
        "cdc_send_${instance}_data_output"
    expect_link "clock_bridge_${instance}/aurora_tx" "aurora_flow_${instance}/tx_axis"
    expect_link "aurora_flow_${instance}/rx_axis" "clock_bridge_${instance}/aurora_rx"
    expect_link_or_axis_cdc \
        "clock_bridge_${instance}/hls_rx" \
        "recv_${instance}/data_input" \
        "cdc_clock_bridge_${instance}_hls_rx"
done

hls_clock_source="$(link_source send_0/ap_clk)"
control_clock_source="$(link_source clock_bridge_0/ap_clk)"
data_clock_source="$(link_source aurora_flow_0/ap_clk_2)"
hls_reset_source="$(link_source send_0/ap_rst_n)"
control_reset_source="$(link_source clock_bridge_0/ap_rst_n)"
data_reset_source="$(link_source aurora_flow_0/ap_rst_n_2)"

for source in "${hls_clock_source}" "${control_clock_source}" \
              "${data_clock_source}" "${hls_reset_source}" \
              "${control_reset_source}" "${data_reset_source}"; do
    if [[ -z "${source}" ]]; then
        echo "unexpected Vitis link: a clock or reset source is missing" >&2
        exit 1
    fi
done

if [[ "${target}" == "hw_emu" && \
      ("${hls_clock_source}" == clk_wiz/* || \
       "${control_clock_source}" == clk_wiz/* || \
       "${data_clock_source}" == clk_wiz/*) ]]; then
    echo "unexpected Vitis link: generated clock wizard used in hw_emu" >&2
    exit 1
fi
if [[ "${control_clock_source}" == "${data_clock_source}" ]]; then
    echo "unexpected Vitis link: 300 MHz HLS and 400 MHz AuroraFlow clocks are not distinct" >&2
    exit 1
fi

for instance in 0 1; do
    for destination in "send_${instance}/ap_clk" \
                       "recv_${instance}/ap_clk"; do
        expect_link "${hls_clock_source}" "${destination}"
    done
    for destination in "aurora_flow_${instance}/ap_clk" \
                       "clock_bridge_${instance}/ap_clk"; do
        expect_link "${control_clock_source}" "${destination}"
    done
    for destination in "aurora_flow_${instance}/ap_clk_2" \
                       "clock_bridge_${instance}/ap_clk_2"; do
        expect_link "${data_clock_source}" "${destination}"
    done

    for destination in "send_${instance}/ap_rst_n" \
                       "recv_${instance}/ap_rst_n"; do
        expect_link "${hls_reset_source}" "${destination}"
    done
    for destination in "aurora_flow_${instance}/ap_rst_n" \
                       "clock_bridge_${instance}/ap_rst_n"; do
        expect_link "${control_reset_source}" "${destination}"
    done
    for destination in "aurora_flow_${instance}/ap_rst_n_2" \
                       "clock_bridge_${instance}/ap_rst_n_2"; do
        expect_link "${data_reset_source}" "${destination}"
    done
done

xo_listing="$(unzip -Z1 "${bridge_xo}")"
for component in \
    axis_data_fifo_clock_bridge_rx \
    axis_data_fifo_clock_bridge_tx \
    axis_dwidth_converter_clock_bridge_rx \
    axis_dwidth_converter_clock_bridge_tx; do
    if ! grep -Fq "${component}" <<<"${xo_listing}"; then
        echo "clock bridge XO is missing ${component}" >&2
        exit 1
    fi
done

echo "Verified line-rate ${target} link"
echo "  HLS clock source: ${hls_clock_source}"
echo "  bridge 300 MHz clock source: ${control_clock_source}"
echo "  line-rate 400 MHz clock source: ${data_clock_source}"
echo "  bridge: async FIFO plus 512/256-bit conversion in both directions"
