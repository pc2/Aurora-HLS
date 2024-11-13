/*
 * Copyright 2024 Gerrit Pape (papeg@mail.upb.de)
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
`timescale 1ns/1ps

module aurora_hls_monitor(
    input wire rst,
    input wire clk,
    input wire [12:0] aurora_status,
    input wire fifo_rx_almost_full,
    input wire fifo_tx_almost_full,
    input wire tx_tvalid,
    input wire tx_tready,
    input wire rx_tvalid,
    output reg [31:0] gt_not_ready_0_count,
    output reg [31:0] gt_not_ready_1_count,
    output reg [31:0] gt_not_ready_2_count,
    output reg [31:0] gt_not_ready_3_count,
    output reg [31:0] line_down_0_count,
    output reg [31:0] line_down_1_count,
    output reg [31:0] line_down_2_count,
    output reg [31:0] line_down_3_count,
    output reg [31:0] pll_not_locked_count,
    output reg [31:0] mmcm_not_locked_count,
    output reg [31:0] hard_err_count,
    output reg [31:0] soft_err_count,
    output reg [31:0] channel_down_count,
    output reg [31:0] fifo_rx_overflow_count,
    output reg [31:0] fifo_tx_overflow_count,
    output reg [31:0] tx_count,
    output reg [31:0] rx_count
);

// TODO: valid+ready+(keep?) count:  byte-counter
// TODO: explicit status
// TODO: counter reset (init)
// TODO: further status?

parameter
    GT_POWERGOOD_0  = 13'h0001,
    GT_POWERGOOD_1  = 13'h0002,
    GT_POWERGOOD_2  = 13'h0004,
    GT_POWERGOOD_3  = 13'h0008,
    LINE_UP_0       = 13'h0010,
    LINE_UP_1       = 13'h0020,
    LINE_UP_2       = 13'h0040,
    LINE_UP_3       = 13'h0080,
    GT_PLL_LOCK     = 13'h0100,
    MMCM_NOT_LOCKED = 13'h0200,
    HARD_ERR        = 13'h0400,
    SOFT_ERR        = 13'h0800,
    CHANNEL_UP      = 13'h1000;

parameter
    GT_POWERGOOD = GT_POWERGOOD_0 | GT_POWERGOOD_1 | GT_POWERGOOD_2 | GT_POWERGOOD_3,
    LINE_UP = LINE_UP_0 | LINE_UP_1 | LINE_UP_2 | LINE_UP_3;

parameter
    CORE_STATUS_OK = GT_POWERGOOD | LINE_UP | GT_PLL_LOCK | CHANNEL_UP;

reg rx_full_triggered, tx_full_triggered;

always @(posedge clk) begin
    if (rst) begin
        gt_not_ready_0_count <= 0;
        gt_not_ready_1_count <= 0;
        gt_not_ready_2_count <= 0;
        gt_not_ready_3_count <= 0;
        line_down_0_count <= 0;
        line_down_1_count <= 0;
        line_down_2_count <= 0;
        line_down_3_count <= 0;
        pll_not_locked_count <= 0;
        mmcm_not_locked_count <= 0;
        hard_err_count <= 0;
        soft_err_count <= 0;
        channel_down_count <= 0;
        fifo_rx_overflow_count <= 0;
        fifo_tx_overflow_count <= 0;
        rx_full_triggered <= fifo_rx_almost_full;
        tx_full_triggered <= fifo_tx_almost_full;
        tx_count <= 0;
        rx_count <= 0;
    end else begin
        if (aurora_status != CORE_STATUS_OK) begin
            if (!(aurora_status & GT_POWERGOOD_0)) begin
                if (!(aurora_status & GT_POWERGOOD_0)) begin
                    gt_not_ready_0_count <= gt_not_ready_0_count + 1;
                end
                if (!(aurora_status & GT_POWERGOOD_1)) begin
                    gt_not_ready_1_count <= gt_not_ready_1_count + 1;
                end
                if (!(aurora_status & GT_POWERGOOD_2)) begin
                    gt_not_ready_2_count <= gt_not_ready_2_count + 1;
                end
                if (!(aurora_status & GT_POWERGOOD_3)) begin
                    gt_not_ready_3_count <= gt_not_ready_3_count + 1;
                end
            end
            if (!(aurora_status & LINE_UP)) begin
                if (!(aurora_status & LINE_UP_0)) begin
                    line_down_0_count <= line_down_0_count + 1;
                end
                if (!(aurora_status & LINE_UP_1)) begin
                    line_down_1_count <= line_down_1_count + 1;
                end
                if (!(aurora_status & LINE_UP_2)) begin
                    line_down_2_count <= line_down_2_count + 1;
                end
                if (!(aurora_status & LINE_UP_3)) begin
                    line_down_3_count <= line_down_3_count + 1;
                end
            end
            if (!(aurora_status & GT_PLL_LOCK)) begin
                pll_not_locked_count <= pll_not_locked_count + 1;
            end
            if (aurora_status & MMCM_NOT_LOCKED) begin
                mmcm_not_locked_count <= mmcm_not_locked_count + 1;
            end
            if (aurora_status & HARD_ERR) begin
                hard_err_count <= hard_err_count + 1;
            end
            if (aurora_status & SOFT_ERR) begin
                soft_err_count <= soft_err_count + 1;
            end
            if (!(aurora_status & CHANNEL_UP)) begin
                channel_down_count <= channel_down_count + 1;
            end
        end

        if (fifo_rx_almost_full && !rx_full_triggered) begin
            fifo_rx_overflow_count <= fifo_rx_overflow_count + 1;
            rx_full_triggered <= 1'b1;
        end
        else if (!fifo_rx_almost_full && rx_full_triggered) begin
            rx_full_triggered <= 1'b0;
        end

        if (fifo_tx_almost_full && !tx_full_triggered) begin
            fifo_tx_overflow_count <= fifo_tx_overflow_count + 1;
            rx_full_triggered <= 1'b1;
        end
        else if (!fifo_tx_almost_full && tx_full_triggered) begin
            tx_full_triggered <= 1'b0;
        end

        if (tx_tvalid && tx_tready) begin
            tx_count <= tx_count + 1;
        end
        if (rx_tvalid) begin
            rx_count <= rx_count + 1;
        end
    end
end

endmodule