//
// Copyright 2022 Xilinx, Inc.
//           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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
`default_nettype none
`include "aurora_hls_define.v"

module aurora_hls_@@@instance@@@ (
// Platform axi/axis ports
    input wire           ap_clk,
    input wire           ap_rst_n,

// TX/RX AXIS interface
    output wire [((`FIFO_WIDTH * 8) - 1):0]  rx_axis_tdata,
    output wire          rx_axis_tvalid,
    input wire           rx_axis_tready,
`ifdef USE_FRAMING
    output wire          rx_axis_tlast,
    output wire [63:0]   rx_axis_tkeep,
`endif

    input wire  [((`FIFO_WIDTH * 8) - 1):0]  tx_axis_tdata,
    input wire           tx_axis_tvalid,
    output wire          tx_axis_tready,
`ifdef USE_FRAMING
    input wire           tx_axis_tlast,
    input wire  [63:0]   tx_axis_tkeep,
`endif

  // AXI4-Lite slave interface
    input wire           s_axi_control_awvalid,
    output wire          s_axi_control_awready,
    input wire  [11:0]   s_axi_control_awaddr ,
    input wire           s_axi_control_wvalid ,
    output wire          s_axi_control_wready ,
    input wire  [31:0]   s_axi_control_wdata  ,
    input wire  [3:0]    s_axi_control_wstrb  ,
    input wire           s_axi_control_arvalid,
    output wire          s_axi_control_arready,
    input wire  [11:0]   s_axi_control_araddr ,
    output wire          s_axi_control_rvalid ,
    input wire           s_axi_control_rready ,
    output wire [31:0]   s_axi_control_rdata  ,
    output wire [1:0]    s_axi_control_rresp  ,
    output wire          s_axi_control_bvalid ,
    input wire           s_axi_control_bready ,
    output wire [1:0]    s_axi_control_bresp  , 

// GT ref clock
    input wire           gt_refclk_@@@instance@@@_p,
    input wire           gt_refclk_@@@instance@@@_n,
    input wire  [3:0]    gt_rxp_in,
    input wire  [3:0]    gt_rxn_in,
    output wire [3:0]    gt_txp_out,
    output wire [3:0]    gt_txn_out,

// assume 50MHz init clk
    input wire           init_clk
);


// internal axi/axis signals

wire            user_clk;

wire [255:0]    s_axi_tx_tdata_u;
wire            s_axi_tx_tvalid_u;
wire            s_axi_tx_tready_u;
`ifdef USE_FRAMING
wire            s_axi_tx_tlast_u;  
wire [31:0]     s_axi_tx_tkeep_u;
`endif

wire [255:0]    m_axi_rx_tdata_u;
wire            m_axi_rx_tvalid_u;
`ifdef USE_FRAMING
wire            m_axi_rx_tlast_u;
wire [31:0]     m_axi_rx_tkeep_u;
`endif

// nfc signals
wire [15:0]     s_axi_nfc_tdata_u;
wire            s_axi_nfc_tready_u;
wire            s_axi_nfc_tvalid_u;
wire            rx_tvalid_u;

// aurora status signals
//   user_clk domain
wire [3:0]      line_up_u; 
wire            channel_up_u;
wire            soft_err_u;
wire            hard_err_u;
wire            mmcm_not_locked_out_u;
wire [3:0]      gt_powergood_u;
`ifdef USE_FRAMING
wire            crc_pass_fail_n_u;
wire            crc_valid_u;
`endif
wire            gt_pll_lock_u;

//   init_clk domain
wire            gt_pll_lock_i;

//   ap_clk domain
wire [3:0]      line_up_sync;
wire [3:0]      gt_powergood_sync;
wire            channel_up_sync;
wire            soft_err_sync;
wire            hard_err_sync;
wire            mmcm_not_locked_out_sync;
wire            gt_pll_lock_sync;


wire [12:0]     aurora_status;
wire [12:0]     aurora_status_u;
wire [7:0]      fifo_status;

// fifo status signals
// user_clk domain
wire            fifo_rx_almost_full_u;
wire            fifo_rx_prog_full_u;
wire            fifo_tx_almost_empty_u;
wire            fifo_tx_prog_empty_u;

wire            fifo_rx_almost_full_sync;
wire            fifo_rx_prog_full_sync;
wire            fifo_tx_almost_empty_sync;
wire            fifo_tx_prog_empty_sync;

wire            fifo_rx_prog_empty_u;

// ap_clk domain
wire            fifo_tx_almost_full;
wire            fifo_tx_prog_full;
wire            fifo_rx_almost_empty;
wire            fifo_rx_prog_empty;

xpm_cdc_single  rx_prog_empty_sync (
    .src_in     (fifo_rx_prog_empty),
    .src_clk    (ap_clk),
    .dest_clk   (user_clk),
    .dest_out   (fifo_rx_prog_empty_u)
);

// internal reset signals
wire             reset_pb_i;
wire             pma_init_i;

wire             reset_pb_u;

// aurora reset generation
wire            ap_rst_n_i;
wire            ap_rst_n_u;

// software-controllable reset
wire            sw_reset;
wire            ap_rst_n_core;
assign ap_rst_n_core = ap_rst_n && !sw_reset;

// optionally drain tx data source during sw_reset
wire            tx_axis_tready_raw;
`ifdef DRAIN_AXI_ON_RESET
    assign tx_axis_tready = tx_axis_tready_raw || sw_reset;
`else
    assign tx_axis_tready = tx_axis_tready_raw;
`endif

aurora_hls_reset aurora_hls_reset_0 (
    .init_clk(init_clk),
    .ap_rst_n_i(ap_rst_n_i),
    .reset_pb_i(reset_pb_i),
    .pma_init_i(pma_init_i)
);

xpm_cdc_async_rst reset_sync_0 (
    .src_arst   (ap_rst_n_core),
    .dest_clk   (init_clk),
    .dest_arst  (ap_rst_n_i)
);

xpm_cdc_async_rst reset_sync_1 (
    .src_arst   (ap_rst_n_core),
    .dest_clk   (user_clk),
    .dest_arst  (ap_rst_n_u)
);

wire            host_monitor_reset;
wire            host_monitor_reset_u;
wire            monitor_reset;
wire            monitor_reset_u;

xpm_cdc_async_rst reset_sync_2 (
    .src_arst   (host_monitor_reset),
    .dest_clk   (user_clk),
    .dest_arst  (host_monitor_reset_u)
);

assign monitor_reset_u = reset_pb_u || host_monitor_reset_u;

xpm_cdc_async_rst reset_sync_3 (
    .src_arst   (monitor_reset_u),
    .dest_clk   (ap_clk),
    .dest_arst  (monitor_reset)
);

// aurora status sync
xpm_cdc_array_single #(.WIDTH(4)) aurora_status_sync_0 (
    .src_in     (line_up_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (line_up_sync)
);

xpm_cdc_array_single #(.WIDTH(4)) aurora_status_sync_1 (
    .src_in     (gt_powergood_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (gt_powergood_sync)
);

xpm_cdc_single  aurora_status_sync_2 (
    .src_in     (channel_up_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (channel_up_sync)
);

xpm_cdc_single  aurora_status_sync_3 (
    .src_in     (soft_err_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (soft_err_sync)
);

xpm_cdc_single  aurora_status_sync_4 (
    .src_in     (hard_err_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (hard_err_sync)
);

xpm_cdc_single  aurora_status_sync_5 (
    .src_in     (mmcm_not_locked_out_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (mmcm_not_locked_out_sync)
);

xpm_cdc_single  aurora_status_sync_6 (
    .src_in     (gt_pll_lock_i),
    .src_clk    (init_clk),
    .dest_clk   (ap_clk),
    .dest_out   (gt_pll_lock_sync)
);

assign aurora_status = {
    channel_up_sync,
    soft_err_sync,
    hard_err_sync,
    mmcm_not_locked_out_sync,
    gt_pll_lock_sync,
    line_up_sync,
    gt_powergood_sync
};

xpm_cdc_single  fifo_status_sync_0 (
    .src_in     (fifo_rx_almost_full_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (fifo_rx_almost_full_sync)
);

xpm_cdc_single  fifo_status_sync_1 (
    .src_in     (fifo_rx_prog_full_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (fifo_rx_prog_full_sync)
);

xpm_cdc_single  fifo_status_sync_2 (
    .src_in     (fifo_tx_almost_empty_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (fifo_tx_almost_empty_sync)
);

xpm_cdc_single  fifo_status_sync_3 (
    .src_in     (fifo_tx_prog_empty_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (fifo_tx_prog_empty_sync)
);

assign fifo_status = {
    fifo_rx_almost_full_sync,
    fifo_rx_prog_full_sync,
    fifo_rx_almost_empty,
    fifo_rx_prog_empty,
    fifo_tx_almost_full,
    fifo_tx_prog_full,
    fifo_tx_almost_empty_sync,
    fifo_tx_prog_empty_sync
};

aurora_64b66b_0 aurora_64b66b_0_0 (
  .rxp                          (gt_rxp_in),                // input wire [0 : 3] rxp
  .rxn                          (gt_rxn_in),                // input wire [0 : 3] rxn
  .reset_pb                     (reset_pb_i),               // input wire reset_pb
  .power_down                   (1'b0),                     // input wire power_down
  .pma_init                     (pma_init_i),               // input wire pma_init
  .loopback                     (3'b0),                     // input wire [2 : 0] loopback
  .txp                          (gt_txp_out),               // output wire [0 : 3] txp
  .txn                          (gt_txn_out),               // output wire [0 : 3] txn
  .hard_err                     (hard_err_u),               // output wire hard_err
  .soft_err                     (soft_err_u),               // output wire soft_err
  .channel_up                   (channel_up_u),             // output wire channel_up
  .lane_up                      (line_up_u),                // output wire [0 : 3] lane_up
`ifdef USE_FRAMING
  .crc_pass_fail_n              (crc_pass_fail_n_u),        // output wire crc_pass_fail_n
  .crc_valid                    (crc_valid_u),              // output wire crc_valid
`endif
  .tx_out_clk                   (),                         // output wire tx_out_clk
  .gt_pll_lock                  (gt_pll_lock_i),            // output wire gt_pll_lock
  .s_axi_tx_tdata               (s_axi_tx_tdata_u),         // input wire [0 : 255] s_axi_tx_tdata
`ifdef USE_FRAMING
  .s_axi_tx_tkeep               (s_axi_tx_tkeep_u),
  .s_axi_tx_tlast               (s_axi_tx_tlast_u),
`endif
  .s_axi_tx_tvalid              (s_axi_tx_tvalid_u),        // input wire s_axi_tx_tvalid
  .s_axi_tx_tready              (s_axi_tx_tready_u),        // output wire s_axi_tx_tready
  .s_axi_nfc_tdata              (s_axi_nfc_tdata_u),                         // input wire s_axi_nfc_tdata
  .s_axi_nfc_tready             (s_axi_nfc_tready_u),                         // output wire s_axi_nfc_tready,
  .s_axi_nfc_tvalid             (s_axi_nfc_tvalid_u),                         // input wire s_axi_nfc_tvalid,
  .m_axi_rx_tdata               (m_axi_rx_tdata_u),         // output wire [0 : 255] m_axi_rx_tdata
`ifdef USE_FRAMING
  .m_axi_rx_tkeep               (m_axi_rx_tkeep_u),
  .m_axi_rx_tlast               (m_axi_rx_tlast_u),
`endif
  .m_axi_rx_tvalid              (m_axi_rx_tvalid_u),        // output wire m_axi_rx_tvalid
  .mmcm_not_locked_out          (mmcm_not_locked_out_u),    // output wire mmcm_not_locked_out
  .gt0_drpaddr                  (10'b0),                    // input wire [9 : 0] gt0_drpaddr
  .gt1_drpaddr                  (10'b0),                    // input wire [9 : 0] gt1_drpaddr
  .gt2_drpaddr                  (10'b0),                    // input wire [9 : 0] gt2_drpaddr
  .gt3_drpaddr                  (10'b0),                    // input wire [9 : 0] gt3_drpaddr
  .gt0_drpdi                    (16'b0),                    // input wire [15 : 0] gt0_drpdi
  .gt1_drpdi                    (16'b0),                    // input wire [15 : 0] gt1_drpdi
  .gt2_drpdi                    (16'b0),                    // input wire [15 : 0] gt2_drpdi
  .gt3_drpdi                    (16'b0),                    // input wire [15 : 0] gt3_drpdi
  .gt0_drprdy                   (),                         // output wire gt0_drprdy
  .gt1_drprdy                   (),                         // output wire gt1_drprdy
  .gt2_drprdy                   (),                         // output wire gt2_drprdy
  .gt3_drprdy                   (),                         // output wire gt3_drprdy
  .gt0_drpwe                    (1'b0),                     // input wire gt0_drpwe
  .gt1_drpwe                    (1'b0),                     // input wire gt1_drpwe
  .gt2_drpwe                    (1'b0),                     // input wire gt2_drpwe
  .gt3_drpwe                    (1'b0),                     // input wire gt3_drpwe
  .gt0_drpen                    (1'b0),                     // input wire gt0_drpen
  .gt1_drpen                    (1'b0),                     // input wire gt1_drpen
  .gt2_drpen                    (1'b0),                     // input wire gt2_drpen
  .gt3_drpen                    (1'b0),                     // input wire gt3_drpen
  .gt0_drpdo                    (),                         // output wire [15 : 0] gt0_drpdo
  .gt1_drpdo                    (),                         // output wire [15 : 0] gt1_drpdo
  .gt2_drpdo                    (),                         // output wire [15 : 0] gt2_drpdo
  .gt3_drpdo                    (),                         // output wire [15 : 0] gt3_drpdo
  .init_clk                     (init_clk),                 // input wire init_clk
  .link_reset_out               (),                         // output wire link_reset_out
  .gt_refclk1_p                 (gt_refclk_@@@instance@@@_p),              // input wire gt_refclk1_p
  .gt_refclk1_n                 (gt_refclk_@@@instance@@@_n),              // input wire gt_refclk1_n
  .user_clk_out                 (user_clk),                 // output wire user_clk_out
  .sync_clk_out                 (),                         // output wire sync_clk_out
  .gt_qpllclk_quad1_out         (),                         // output wire gt_qpllclk_quad1_out
  .gt_qpllrefclk_quad1_out      (),                         // output wire gt_qpllrefclk_quad1_out
  .gt_qpllrefclklost_quad1_out  (),                         // output wire gt_qpllrefclklost_quad1_out
  .gt_qplllock_quad1_out        (),                         // output wire gt_qplllock_quad1_out
  .gt_rxcdrovrden_in            (1'b0),                     // input wire gt_rxcdrovrden_in
  .sys_reset_out                (),                         // output wire sys_reset_out
  .gt_reset_out                 (),                         // output wire gt_reset_out
  .gt_refclk1_out               (),                         // output wire gt_refclk1_out
  .gt_powergood                 (gt_powergood_u)            // output wire [3 : 0] gt_powergood
);

aurora_hls_io aurora_hls_io_0 (
    .ap_clk                 (ap_clk),
    .ap_rst_n               (ap_rst_n_core),
    .user_clk               (user_clk),
    .ap_rst_n_u             (ap_rst_n_u),
    .rx_axis_tdata          (rx_axis_tdata),
    .rx_axis_tvalid         (rx_axis_tvalid),
    .rx_axis_tready         (rx_axis_tready),
`ifdef USE_FRAMING
    .rx_axis_tlast          (rx_axis_tlast),
    .rx_axis_tkeep          (rx_axis_tkeep),
`endif
    .m_axi_rx_tdata_u       (m_axi_rx_tdata_u),
    .m_axi_rx_tvalid_u      (m_axi_rx_tvalid_u),
`ifdef USE_FRAMING
    .m_axi_rx_tlast_u       (m_axi_rx_tlast_u),
    .m_axi_rx_tkeep_u       (m_axi_rx_tkeep_u),
`endif
    .tx_axis_tdata          (tx_axis_tdata),
    .tx_axis_tvalid         (tx_axis_tvalid),
    .tx_axis_tready         (tx_axis_tready_raw),
`ifdef USE_FRAMING
    .tx_axis_tlast          (tx_axis_tlast),
    .tx_axis_tkeep          (tx_axis_tkeep),
`endif
    .s_axi_tx_tdata_u       (s_axi_tx_tdata_u),
    .s_axi_tx_tvalid_u      (s_axi_tx_tvalid_u),
    .s_axi_tx_tready_u      (s_axi_tx_tready_u),
`ifdef USE_FRAMING
    .s_axi_tx_tlast_u       (s_axi_tx_tlast_u), 
    .s_axi_tx_tkeep_u       (s_axi_tx_tkeep_u),
`endif
    .fifo_rx_almost_full_u  (fifo_rx_almost_full_u),
    .fifo_rx_prog_full_u    (fifo_rx_prog_full_u),
    .fifo_rx_almost_empty   (fifo_rx_almost_empty),
    .fifo_rx_prog_empty     (fifo_rx_prog_empty),
    .fifo_tx_almost_full    (fifo_tx_almost_full),
    .fifo_tx_prog_full      (fifo_tx_prog_full),
    .fifo_tx_almost_empty_u (fifo_tx_almost_empty_u),
    .fifo_tx_prog_empty_u   (fifo_tx_prog_empty_u)
);

xpm_cdc_single  aurora_monitor_sync_0 (
    .src_in     (gt_pll_lock_i),
    .src_clk    (init_clk),
    .dest_clk   (user_clk),
    .dest_out   (gt_pll_lock_u)
);

xpm_cdc_single  aurora_monitor_sync_1 (
    .src_in     (reset_pb_i),
    .src_clk    (init_clk),
    .dest_clk   (user_clk),
    .dest_out   (reset_pb_u)
);

assign aurora_status_u = {
    channel_up_u,
    soft_err_u,
    hard_err_u,
    mmcm_not_locked_out_u,
    gt_pll_lock_u,
    line_up_u,
    gt_powergood_u
};


wire [31:0] gt_not_ready_0_count_u;
wire [31:0] gt_not_ready_1_count_u;
wire [31:0] gt_not_ready_2_count_u;
wire [31:0] gt_not_ready_3_count_u;
wire [31:0] line_down_0_count_u;
wire [31:0] line_down_1_count_u;
wire [31:0] line_down_2_count_u;
wire [31:0] line_down_3_count_u;
wire [31:0] pll_not_locked_count_u;
wire [31:0] mmcm_not_locked_count_u;
wire [31:0] hard_err_count_u;
wire [31:0] soft_err_count_u;
wire [31:0] channel_down_count_u;

wire [31:0] fifo_rx_overflow_count_u;
wire [31:0] fifo_tx_overflow_count;
wire [31:0] tx_count;
wire [31:0] rx_count;

aurora_hls_monitor aurora_hls_monitor_0 (
    .rst_u                      (monitor_reset_u),
    .clk_u                      (user_clk),
    .aurora_status              (aurora_status_u),
    .fifo_rx_almost_full        (fifo_rx_almost_full_u),
    .gt_not_ready_0_count       (gt_not_ready_0_count_u),
    .gt_not_ready_1_count       (gt_not_ready_1_count_u),
    .gt_not_ready_2_count       (gt_not_ready_2_count_u),
    .gt_not_ready_3_count       (gt_not_ready_3_count_u),
    .line_down_0_count          (line_down_0_count_u),
    .line_down_1_count          (line_down_1_count_u),
    .line_down_2_count          (line_down_2_count_u),
    .line_down_3_count          (line_down_3_count_u),
    .pll_not_locked_count       (pll_not_locked_count_u),
    .mmcm_not_locked_count      (mmcm_not_locked_count_u),
    .hard_err_count             (hard_err_count_u),
    .soft_err_count             (soft_err_count_u),
    .channel_down_count         (channel_down_count_u),
    .fifo_rx_overflow_count     (fifo_rx_overflow_count_u),
    .rst                        (monitor_reset),
    .clk                        (ap_clk),
    .tx_tvalid                  (tx_axis_tvalid),
    .tx_tready                  (tx_axis_tready),
    .rx_tvalid                  (rx_axis_tvalid),
    .rx_tready                  (rx_axis_tready),
    .fifo_tx_almost_full        (fifo_tx_almost_full),
    .fifo_tx_overflow_count     (fifo_tx_overflow_count),
    .tx_count                   (tx_count),
    .rx_count                   (rx_count)
);

wire [31:0] gt_not_ready_0_count;
wire [31:0] gt_not_ready_1_count;
wire [31:0] gt_not_ready_2_count;
wire [31:0] gt_not_ready_3_count;
wire [31:0] line_down_0_count;
wire [31:0] line_down_1_count;
wire [31:0] line_down_2_count;
wire [31:0] line_down_3_count;
wire [31:0] pll_not_locked_count;
wire [31:0] mmcm_not_locked_count;
wire [31:0] hard_err_count;
wire [31:0] soft_err_count;
wire [31:0] channel_down_count;
wire [31:0] fifo_rx_overflow_count;

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_3 (
    .src_in(gt_not_ready_0_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(gt_not_ready_0_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_4 (
    .src_in(gt_not_ready_1_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(gt_not_ready_1_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_5 (
    .src_in(gt_not_ready_2_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(gt_not_ready_2_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_6 (
    .src_in(gt_not_ready_3_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(gt_not_ready_3_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_7 (
    .src_in(line_down_0_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(line_down_0_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_8 (
    .src_in(line_down_1_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(line_down_1_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_9 (
    .src_in(line_down_2_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(line_down_2_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_10 (
    .src_in(line_down_3_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(line_down_3_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_11 (
    .src_in(pll_not_locked_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(pll_not_locked_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_12 (
    .src_in(mmcm_not_locked_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(mmcm_not_locked_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_13 (
    .src_in(hard_err_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(hard_err_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_14 (
    .src_in(soft_err_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(soft_err_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_15 (
    .src_in(channel_down_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(channel_down_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_monitor_sync_16 (
    .src_in(fifo_rx_overflow_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(fifo_rx_overflow_count)
);

wire [31:0] nfc_full_trigger_count_u;
wire [31:0] nfc_empty_trigger_count_u; 

aurora_hls_nfc aurora_hls_nfc_0 (
    .rst_n                  (ap_rst_n_u),
    .clk                    (user_clk),
    .fifo_rx_prog_full      (fifo_rx_prog_full_u),
    .fifo_rx_prog_empty     (fifo_rx_prog_empty_u),
    .s_axi_nfc_tready       (s_axi_nfc_tready_u),
    .s_axi_nfc_tvalid       (s_axi_nfc_tvalid_u),
    .s_axi_nfc_tdata        (s_axi_nfc_tdata_u),
    .full_trigger_count     (nfc_full_trigger_count_u),
    .empty_trigger_count    (nfc_empty_trigger_count_u)
);

wire [31:0] nfc_full_trigger_count;
wire [31:0] nfc_empty_trigger_count;

xpm_cdc_array_single #(.WIDTH(32)) aurora_nfc_sync_0 (
    .src_in(nfc_full_trigger_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(nfc_full_trigger_count)
);

xpm_cdc_array_single #(.WIDTH(32)) aurora_nfc_sync_1 (
    .src_in(nfc_empty_trigger_count_u),
    .src_clk(user_clk),
    .dest_clk(ap_clk),
    .dest_out(nfc_empty_trigger_count)
);

`ifdef USE_FRAMING
wire [31:0] frames_received_u;
wire [31:0] frames_with_errors_u;

aurora_hls_crc_counter aurora_hls_crc_counter_0 (
    .clk                (user_clk),
    .rst_n              (ap_rst_n_u),
    .crc_valid          (crc_valid_u),
    .crc_pass_fail_n    (crc_pass_fail_n_u),
    .frames_received    (frames_received_u),
    .frames_with_errors (frames_with_errors_u)
);

wire [31:0] frames_received;
wire [31:0] frames_with_errors;

xpm_cdc_array_single #(.WIDTH(32)) frames_received_sync (
    .src_in     (frames_received_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (frames_received)
);

xpm_cdc_array_single #(.WIDTH(32)) frames_with_errors_sync (
    .src_in     (frames_with_errors_u),
    .src_clk    (user_clk),
    .dest_clk   (ap_clk),
    .dest_out   (frames_with_errors)
);

`endif

wire [21:0] configuration;
wire [31:0] fifo_thresholds;

aurora_hls_configuration aurora_hls_configuration_0 (
    .configuration(configuration),
    .fifo_thresholds(fifo_thresholds)
);

aurora_hls_control_s_axi axi_control_slave (
  .ACLK                     (ap_clk),
  .ARESETn                  (ap_rst_n),
  .AWADDR                   (s_axi_control_awaddr),
  .AWVALID                  (s_axi_control_awvalid),
  .AWREADY                  (s_axi_control_awready),
  .WDATA                    (s_axi_control_wdata),
  .WSTRB                    (s_axi_control_wstrb),
  .WVALID                   (s_axi_control_wvalid),
  .WREADY                   (s_axi_control_wready),
  .BRESP                    (s_axi_control_bresp),
  .BVALID                   (s_axi_control_bvalid),
  .BREADY                   (s_axi_control_bready),
  .ARADDR                   (s_axi_control_araddr),
  .ARVALID                  (s_axi_control_arvalid),
  .ARREADY                  (s_axi_control_arready),
  .RDATA                    (s_axi_control_rdata),
  .RRESP                    (s_axi_control_rresp),
  .RVALID                   (s_axi_control_rvalid),
  .RREADY                   (s_axi_control_rready),
  .configuration            (configuration),
  .fifo_thresholds          (fifo_thresholds),
  .aurora_status            (aurora_status),
  .gt_not_ready_0_count     (gt_not_ready_0_count),
  .gt_not_ready_1_count     (gt_not_ready_1_count),
  .gt_not_ready_2_count     (gt_not_ready_2_count),
  .gt_not_ready_3_count     (gt_not_ready_3_count),
  .line_down_0_count        (line_down_0_count),
  .line_down_1_count        (line_down_1_count),
  .line_down_2_count        (line_down_2_count),
  .line_down_3_count        (line_down_3_count),
  .pll_not_locked_count     (pll_not_locked_count),
  .mmcm_not_locked_count    (mmcm_not_locked_count),
  .hard_err_count           (hard_err_count),
  .soft_err_count           (soft_err_count),
  .channel_down_count       (channel_down_count),
  .fifo_status              (fifo_status),
  .fifo_rx_overflow_count   (fifo_rx_overflow_count),
  .fifo_tx_overflow_count   (fifo_tx_overflow_count),
  .nfc_full_trigger_count   (nfc_full_trigger_count),
  .nfc_empty_trigger_count  (nfc_empty_trigger_count),
  .tx_count                 (tx_count),
  .rx_count                 (rx_count),
`ifdef USE_FRAMING
  .frames_received          (frames_received),
  .frames_with_errors       (frames_with_errors),
`endif
  .core_reset               (sw_reset),
  .monitor_reset            (host_monitor_reset)
);

endmodule
