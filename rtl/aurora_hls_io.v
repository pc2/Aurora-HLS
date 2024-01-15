/*
 * Copyright 2023-2024 Gerrit Pape (papeg@mail.upb.de)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
`default_nettype none
`include "aurora_hls_define.v"

module aurora_hls_io (
    input wire          ap_clk,
    input wire          ap_rst_n,
    input wire          user_clk,
    input wire          ap_rst_n_u,

    output wire[511:0]  rx_axis_tdata,
    output wire         rx_axis_tvalid,
    input wire          rx_axis_tready,
`ifdef USE_FRAMING
    output wire         rx_axis_tlast,
    output wire[63:0]   rx_axis_tkeep,
`endif

    input wire[255:0]    m_axi_rx_tdata_u,
    input wire           m_axi_rx_tvalid_u,
`ifdef USE_FRAMING
    input wire           m_axi_rx_tlast_u,
    input wire[31:0]     m_axi_rx_tkeep_u,
`endif

    input wire [511:0]  tx_axis_tdata,
    input wire          tx_axis_tvalid,
    output wire         tx_axis_tready,
`ifdef USE_FRAMING
    input wire          tx_axis_tlast,
    input wire [63:0]   tx_axis_tkeep,
`endif

    output wire[255:0]    s_axi_tx_tdata_u,
    output wire           s_axi_tx_tvalid_u,
    input wire            s_axi_tx_tready_u,
`ifdef USE_FRAMING
    output wire           s_axi_tx_tlast_u, 
    output wire[31:0]     s_axi_tx_tkeep_u,
`endif

    output wire          fifo_rx_almost_full_u,
    output wire          fifo_rx_prog_full_u,
    output wire          fifo_rx_almost_empty,
    output wire          fifo_rx_prog_empty,

    output wire          fifo_tx_almost_full,
    output wire          fifo_tx_prog_full,
    output wire          fifo_tx_almost_empty_u,
    output wire          fifo_tx_prog_empty_u,
    output wire          rx_tvalid_u
);

wire [511:0]    dwidth_tx_s_axis_tdata_u; 
wire            dwidth_tx_s_axis_tvalid_u; 
wire            dwidth_tx_s_axis_tready_u; 
`ifdef USE_FRAMING
wire            dwidth_tx_s_axis_tlast_u;
wire [63:0]     dwidth_tx_s_axis_tkeep_u;
`endif

wire [511:0]    dwidth_rx_m_axis_tdata_u; 
wire            dwidth_rx_m_axis_tvalid_u; 
wire            dwidth_rx_m_axis_tready_u; 
`ifdef USE_FRAMING
wire            dwidth_rx_m_axis_tlast_u;
wire [63:0]     dwidth_rx_m_axis_tkeep_u;
`endif

assign rx_tvalid_u = dwidth_rx_m_axis_tvalid_u;

axis_data_fifo_rx axis_data_fifo_rx_0 (
  .s_axis_aresetn   (ap_rst_n_u),           // input wirewire s_axis_aresetn
  .s_axis_aclk      (user_clk),             // input wirewire s_axis_aclk
  .s_axis_tdata     (dwidth_rx_m_axis_tdata_u),     // input wirewire [255 : 0] s_axis_tdata
`ifdef USE_FRAMING
  .s_axis_tkeep     (dwidth_rx_m_axis_tkeep_u),
  .s_axis_tlast     (dwidth_rx_m_axis_tlast_u),
`endif
  .s_axis_tready    (dwidth_rx_m_axis_tready_u),                     // output regwire s_axis_tready
  .s_axis_tvalid    (dwidth_rx_m_axis_tvalid_u),    // input wirewire s_axis_tvalid
  .m_axis_aclk      (ap_clk),               // input wirewire m_axis_aclk
  .m_axis_tdata     (rx_axis_tdata),        // output regwire [255 : 0] m_axis_tdata
`ifdef USE_FRAMING
  .m_axis_tkeep     (rx_axis_tkeep),
  .m_axis_tlast     (rx_axis_tlast),
`endif
  .m_axis_tready    (rx_axis_tready),       // input wirewire m_axis_tready
  .m_axis_tvalid    (rx_axis_tvalid),       // output regwire m_axis_tvalid
  .almost_full      (fifo_rx_almost_full_u),
  .prog_full        (fifo_rx_prog_full_u),
  .almost_empty     (fifo_rx_almost_empty),
  .prog_empty       (fifo_rx_prog_empty)
);

axis_dwidth_converter_rx axis_dwidth_converter_rx_0 (
    .s_axis_tvalid      (m_axi_rx_tvalid_u),
    .s_axis_tready      (),
    .s_axis_tdata       (m_axi_rx_tdata_u),
`ifdef USE_FRAMING
    .s_axis_tkeep       (m_axi_rx_tkeep_u),
    .s_axis_tlast       (m_axi_rx_tlast_u),
`endif
    .m_axis_tvalid      (dwidth_rx_m_axis_tvalid_u),
    .m_axis_tready      (dwidth_rx_m_axis_tready_u),
    .m_axis_tdata       (dwidth_rx_m_axis_tdata_u),
`ifdef USE_FRAMING
    .m_axis_tkeep       (dwidth_rx_m_axis_tkeep_u),
    .m_axis_tlast       (dwidth_rx_m_axis_tlast_u),
`endif
    .aresetn            (ap_rst_n_u),
    .aclk               (user_clk)
);

axis_data_fifo_tx axis_data_fifo_tx_0 (
  .s_axis_aresetn   (ap_rst_n),             // input wirewire s_axis_aresetn
  .s_axis_aclk      (ap_clk),               // input wirewire s_axis_aclk
  .s_axis_tdata     (tx_axis_tdata),        // input wirewire [255 : 0] s_axis_tdata
`ifdef USE_FRAMING
  .s_axis_tkeep     (tx_axis_tkeep),
  .s_axis_tlast     (tx_axis_tlast),
`endif
  .s_axis_tready    (tx_axis_tready),       // output regwire s_axis_tready
  .s_axis_tvalid    (tx_axis_tvalid),       // input wirewire s_axis_tvalid
  .m_axis_aclk      (user_clk),             // input wirewire m_axis_aclk
  .m_axis_tdata     (dwidth_tx_s_axis_tdata_u),      // output regwire [255 : 0] m_axis_tdata
`ifdef USE_FRAMING
  .m_axis_tkeep     (dwidth_tx_s_axis_tkeep_u),
  .m_axis_tlast     (dwidth_tx_s_axis_tlast_u),
`endif
  .m_axis_tready    (dwidth_tx_s_axis_tready_u),    // input wirewire m_axis_tready
  .m_axis_tvalid    (dwidth_tx_s_axis_tvalid_u),    // output regwire m_axis_tvalid
  .almost_full      (fifo_tx_almost_full),
  .prog_full        (fifo_tx_prog_full),
  .almost_empty     (fifo_tx_almost_empty_u),
  .prog_empty       (fifo_tx_prog_empty_u)
);

axis_dwidth_converter_tx axis_dwidth_converter_tx_0 (
    .s_axis_tvalid      (dwidth_tx_s_axis_tvalid_u),
    .s_axis_tready      (dwidth_tx_s_axis_tready_u),
    .s_axis_tdata       (dwidth_tx_s_axis_tdata_u),
`ifdef USE_FRAMING
    .s_axis_tkeep       (dwidth_tx_s_axis_tkeep_u),
    .s_axis_tlast       (dwidth_tx_s_axis_tlast_u),
`endif
    .m_axis_tvalid      (s_axi_tx_tvalid_u),
    .m_axis_tready      (s_axi_tx_tready_u),
    .m_axis_tdata       (s_axi_tx_tdata_u),
`ifdef USE_FRAMING
    .m_axis_tkeep       (s_axi_tx_tkeep_u),
    .m_axis_tlast       (s_axi_tx_tlast_u),
`endif
    .aresetn            (ap_rst_n_u),
    .aclk               (user_clk)
);

endmodule
