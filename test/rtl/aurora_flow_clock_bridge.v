//
// Copyright 2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Split-clock integration probe. The HLS-facing AXI streams use ap_clk
// (scalable clock 0, 300 MHz); the AuroraFlow-facing streams use ap_clk_2
// (scalable clock 1, 400 MHz). aurora_flow_io provides the same asynchronous
// FIFOs and 512/256-bit width converters used by the real AuroraFlow datapath.

`default_nettype none
// Use a kernel-specific header name.  Several RTL kernels are linked into the
// same Vivado project, so the generic AuroraFlow header name is ambiguous in
// the shared IP source tree.
`include "aurora_flow_clock_bridge_define.vh"

module aurora_flow_clock_bridge (
    input  wire ap_clk,
    input  wire ap_rst_n,
    input  wire ap_clk_2,
    input  wire ap_rst_n_2,

    // HLS send -> bridge, 512 bits at 300 MHz.
    input  wire [((`CLOCK_BRIDGE_HLS_WIDTH * 8) - 1):0] hls_tx_tdata,
    input  wire hls_tx_tvalid,
    output wire hls_tx_tready,
`ifdef USE_FRAMING
    input  wire hls_tx_tlast,
    input  wire [(`CLOCK_BRIDGE_HLS_WIDTH - 1):0] hls_tx_tkeep,
`endif

    // Bridge -> AuroraFlow TX, 256 bits at 400 MHz.
    output wire [((`CLOCK_BRIDGE_AURORA_WIDTH * 8) - 1):0] aurora_tx_tdata,
    output wire aurora_tx_tvalid,
    input  wire aurora_tx_tready,
`ifdef USE_FRAMING
    output wire aurora_tx_tlast,
    output wire [(`CLOCK_BRIDGE_AURORA_WIDTH - 1):0] aurora_tx_tkeep,
`endif

    // AuroraFlow RX -> bridge, 256 bits at 400 MHz.
    input  wire [((`CLOCK_BRIDGE_AURORA_WIDTH * 8) - 1):0] aurora_rx_tdata,
    input  wire aurora_rx_tvalid,
    output wire aurora_rx_tready,
`ifdef USE_FRAMING
    input  wire aurora_rx_tlast,
    input  wire [(`CLOCK_BRIDGE_AURORA_WIDTH - 1):0] aurora_rx_tkeep,
`endif

    // Bridge -> HLS recv, 512 bits at 300 MHz.
    output wire [((`CLOCK_BRIDGE_HLS_WIDTH * 8) - 1):0] hls_rx_tdata,
    output wire hls_rx_tvalid,
    input  wire hls_rx_tready
`ifdef USE_FRAMING
    , output wire hls_rx_tlast
    , output wire [(`CLOCK_BRIDGE_HLS_WIDTH - 1):0] hls_rx_tkeep
`endif
);

aurora_flow_clock_bridge_io bridge_io (
    .ap_clk                  (ap_clk),
    .ap_rst_n                (ap_rst_n),
    .user_clk                (ap_clk_2),
    .ap_rst_n_u              (ap_rst_n_2),

    .rx_axis_tdata           (hls_rx_tdata),
    .rx_axis_tvalid          (hls_rx_tvalid),
    .rx_axis_tready          (hls_rx_tready),
`ifdef USE_FRAMING
    .rx_axis_tlast           (hls_rx_tlast),
    .rx_axis_tkeep           (hls_rx_tkeep),
`endif

    .m_axi_rx_tdata_u        (aurora_rx_tdata),
    .m_axi_rx_tvalid_u       (aurora_rx_tvalid),
    .m_axi_rx_tready_u       (aurora_rx_tready),
`ifdef USE_FRAMING
    .m_axi_rx_tlast_u        (aurora_rx_tlast),
    .m_axi_rx_tkeep_u        (aurora_rx_tkeep),
`endif

    .tx_axis_tdata           (hls_tx_tdata),
    .tx_axis_tvalid          (hls_tx_tvalid),
    .tx_axis_tready          (hls_tx_tready),
`ifdef USE_FRAMING
    .tx_axis_tlast           (hls_tx_tlast),
    .tx_axis_tkeep           (hls_tx_tkeep),
`endif

    .s_axi_tx_tdata_u        (aurora_tx_tdata),
    .s_axi_tx_tvalid_u       (aurora_tx_tvalid),
    .s_axi_tx_tready_u       (aurora_tx_tready),
`ifdef USE_FRAMING
    .s_axi_tx_tlast_u        (aurora_tx_tlast),
    .s_axi_tx_tkeep_u        (aurora_tx_tkeep),
`endif

    .fifo_rx_almost_full_u   (),
    .fifo_rx_prog_full_u     (),
    .fifo_rx_almost_empty    (),
    .fifo_rx_prog_empty      (),
    .fifo_tx_almost_full     (),
    .fifo_tx_prog_full       (),
    .fifo_tx_almost_empty_u  (),
    .fifo_tx_prog_empty_u    ()
);

endmodule
`default_nettype wire
