/*
 * Copyright 2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
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

// DPI-C GT stub replacing the aurora_64b66b transceiver for hw_emu.
// Uses named pipes for inter-FPGA communication.
// Keeps the same little-endian port interface as the configured
// aurora_64b66b_0 (relevant signals only).
`include "aurora_flow_define.v"

module aurora_flow_gt_stub #(
    parameter INSTANCE = 0,
    parameter PIPE_ID = 0,
    parameter NFC_INFLIGHT_CYCLES = 256
)(
    input  wire         ap_clk,
    input  wire         reset,
    // TX AXI-Stream (from FIFO/datawidth converter)
    input  wire [255:0] s_axi_tx_tdata,
    input  wire         s_axi_tx_tvalid,
    output wire         s_axi_tx_tready,
`ifdef USE_FRAMING
    input  wire [31:0]  s_axi_tx_tkeep,
    input  wire         s_axi_tx_tlast,
`endif
    // RX AXI-Stream (to FIFO/datawidth converter)
    output reg  [255:0] m_axi_rx_tdata,
    output reg          m_axi_rx_tvalid,
    input  wire         m_axi_rx_tready,
`ifdef USE_FRAMING
    output reg  [31:0]  m_axi_rx_tkeep,
    output reg          m_axi_rx_tlast,
`endif
    // NFC
    input  wire [15:0]  s_axi_nfc_tdata,
    input  wire         s_axi_nfc_tvalid,
    output wire         s_axi_nfc_tready,
    // Status
    output wire         channel_up,
    output wire [0:3]   lane_up,
    output wire [3:0]   gt_powergood,
    output wire         gt_pll_lock,
    output wire         mmcm_not_locked_out,
    output wire         hard_err,
    output wire         soft_err,
`ifdef USE_FRAMING
    output wire         crc_pass_fail_n,
    output wire         crc_valid,
`endif
    // Clock output
    output wire         user_clk_out
);

    import "DPI-C" function void aurora_dpi_open_all();
    import "DPI-C" function int  aurora_dpi_write(
        input int inst,
        input bit [255:0] data,
        input bit [31:0] keep,
        input bit last
    );
    import "DPI-C" function int  aurora_dpi_read(
        input int inst,
        output bit [255:0] data,
        output bit [31:0] keep,
        output bit last
    );
    import "DPI-C" function void aurora_dpi_close(input int inst);

    // Status: always report link up
    assign channel_up = 1'b1;
    assign lane_up = 4'hf;
    assign gt_powergood = 4'hf;
    assign gt_pll_lock = 1'b1;
    assign mmcm_not_locked_out = 1'b0;
    assign hard_err = 1'b0;
    assign soft_err = 1'b0;
`ifdef USE_FRAMING
    assign crc_pass_fail_n = 1'b1;
    assign crc_valid = 1'b0;
`endif
    assign user_clk_out = ap_clk;
    assign s_axi_nfc_tready = 1'b1;

    // NFC state: XOFF with in-flight window
    reg nfc_stop = 0;
    reg [8:0] inflight_count = 0;

    always @(posedge ap_clk) begin
        if (reset) begin
            nfc_stop <= 0;
            inflight_count <= 0;
        end else begin
            if (s_axi_nfc_tvalid && s_axi_nfc_tdata == 16'hffff) begin
                inflight_count <= NFC_INFLIGHT_CYCLES;
            end else if (s_axi_nfc_tvalid && s_axi_nfc_tdata == 16'h0000) begin
                inflight_count <= 0;
                nfc_stop <= 0;
            end
            if (inflight_count > 0) begin
                inflight_count <= inflight_count - 1;
                if (inflight_count == 1)
                    nfc_stop <= 1;
            end
        end
    end

    // Pipe lifecycle. Fixed-clock hw_emu may start with reset deasserted, then
    // assert it while XRT configures the device, so handle both the initial
    // reset level and every subsequent reset cycle.
    reg pipes_open = 0;

    initial begin
        forever begin
            wait (reset === 1'b0);
            if (INSTANCE == 0) begin
                aurora_dpi_open_all();
            end
            pipes_open = 1;

            @(posedge reset);
            if (pipes_open) begin
                aurora_dpi_close(INSTANCE);
                pipes_open = 0;
            end
        end
    end

    // TX: accept an AXI beat into a one-entry buffer, then retry the
    // nonblocking pipe write until it succeeds.  TREADY describes buffer
    // availability; it must not report the result of a write attempted at the
    // same clock edge, because the AXI source samples the old TREADY value.
    bit [255:0] tx_data;
    bit [31:0] tx_keep;
    bit tx_last;
    reg tx_pending = 0;

    assign s_axi_tx_tready = pipes_open && !reset && !tx_pending;

    always @(posedge ap_clk) begin
        if (reset || !pipes_open) begin
            tx_pending <= 0;
        end else if (tx_pending) begin
            if (aurora_dpi_write(INSTANCE, tx_data, tx_keep, tx_last)) begin
                tx_pending <= 0;
            end
        end else if (s_axi_tx_tvalid) begin
            tx_data = s_axi_tx_tdata;
`ifdef USE_FRAMING
            tx_keep = s_axi_tx_tkeep;
            tx_last = s_axi_tx_tlast;
`else
            tx_keep = 32'hffffffff;
            tx_last = 1'b0;
`endif
            tx_pending <= 1;
        end
    end

    // RX: keep a record stable until the downstream AXI slave accepts it.
    // A new pipe record may replace one consumed on the same edge.
    bit [255:0] rx_data;
    bit [31:0] rx_keep;
    bit rx_last;
    always @(posedge ap_clk) begin
        if (reset || !pipes_open) begin
            m_axi_rx_tvalid <= 1'b0;
        end else if (!nfc_stop && (!m_axi_rx_tvalid || m_axi_rx_tready)) begin
            if (aurora_dpi_read(INSTANCE, rx_data, rx_keep, rx_last)) begin
                m_axi_rx_tdata <= rx_data;
                m_axi_rx_tvalid <= 1'b1;
`ifdef USE_FRAMING
                m_axi_rx_tkeep <= rx_keep;
                m_axi_rx_tlast <= rx_last;
`endif
            end else begin
                m_axi_rx_tvalid <= 1'b0;
            end
        end else if (nfc_stop && m_axi_rx_tvalid && m_axi_rx_tready) begin
            m_axi_rx_tvalid <= 1'b0;
        end
    end

endmodule
