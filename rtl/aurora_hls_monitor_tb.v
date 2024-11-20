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
`timescale 1ns/1ps

module aurora_hls_monitor_tb();
    reg rst_u;
    reg clk_u;
    reg [12:0] aurora_status;
    reg fifo_rx_almost_full;

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

    reg rst;
    reg clk;
    reg fifo_tx_almost_full;
    reg tx_tvalid;
    reg tx_tready;
    reg rx_tvalid;
    reg rx_tready;

    wire [31:0] fifo_tx_overflow_count;
    wire [31:0] tx_count;
    wire [31:0] rx_count;

    aurora_hls_monitor dut (
        .clk_u(clk_u),
        .rst_u(rst_u),
        .aurora_status(aurora_status),
        .fifo_rx_almost_full(fifo_rx_almost_full),
        .gt_not_ready_0_count(gt_not_ready_0_count),
        .gt_not_ready_1_count(gt_not_ready_1_count),
        .gt_not_ready_2_count(gt_not_ready_2_count),
        .gt_not_ready_3_count(gt_not_ready_3_count),
        .line_down_0_count(line_down_0_count),
        .line_down_1_count(line_down_1_count),
        .line_down_2_count(line_down_2_count),
        .line_down_3_count(line_down_3_count),
        .pll_not_locked_count(pll_not_locked_count),
        .mmcm_not_locked_count(mmcm_not_locked_count),
        .hard_err_count(hard_err_count),
        .soft_err_count(soft_err_count),
        .channel_down_count(channel_down_count),
        .fifo_rx_overflow_count(fifo_rx_overflow_count),
        .clk(clk),
        .rst(rst),
        .fifo_tx_almost_full(fifo_tx_almost_full),
        .tx_tvalid(tx_tvalid),
        .tx_tready(tx_tready),
        .rx_tvalid(rx_tvalid),
        .rx_tready(rx_tready),
        .fifo_tx_overflow_count(fifo_tx_overflow_count),
        .tx_count(tx_count),
        .rx_count(rx_count)
    );

    initial begin
        clk_u = 1'b0;
        forever #10 clk_u = ~clk_u;
    end

    initial begin
        clk_u = 1'b0;
        forever #7 clk_u = ~clk_u;
    end

    reg [15:0] errors;

    initial begin
        $dumpfile("monitor_tb.vcd");
        $dumpvars(0, aurora_hls_monitor);
        $monitor("gt_not_ready_0_count = %d", gt_not_ready_0_count);
        $monitor("gt_not_ready_1_count = %d", gt_not_ready_1_count);
        $monitor("gt_not_ready_2_count = %d", gt_not_ready_2_count);
        $monitor("gt_not_ready_3_count = %d", gt_not_ready_3_count);
        $monitor("line_down_0_count = %d", line_down_0_count);
        $monitor("line_down_1_count = %d", line_down_1_count);
        $monitor("line_down_2_count = %d", line_down_2_count);
        $monitor("line_down_3_count = %d", line_down_3_count);
        $monitor("pll_not_locked_count = %d", pll_not_locked_count);
        $monitor("mmcm_not_locked_count = %d", mmcm_not_locked_count);
        $monitor("hard_err_count = %d", hard_err_count);
        $monitor("soft_err_count = %d", soft_err_count);
        $monitor("channel_down_count = %d", channel_down_count);
        $monitor("fifo_rx_overflow_count = %d", fifo_rx_overflow_count);
        $monitor("fifo_tx_overflow_count = %d", fifo_tx_overflow_count);
        $monitor("tx_count = %d", tx_count);
        $monitor("rx_count = %d", rx_count);

        errors = 0;

        aurora_status = dut.CORE_STATUS_OK;
        fifo_rx_almost_full = 1'b0;
        fifo_tx_almost_full = 1'b0;
        tx_tvalid = 1'b0;
        tx_tready = 1'b0;
        rx_tvalid = 1'b0;

        rst_u = 1'b1;
        rst = 1'b1;
        repeat (2) @(posedge clk_u);

        if (gt_not_ready_0_count != 0
            || gt_not_ready_1_count != 0
            || gt_not_ready_2_count != 0
            || gt_not_ready_3_count != 0
            || line_down_0_count != 0
            || line_down_1_count != 0
            || line_down_2_count != 0
            || line_down_3_count != 0
            || pll_not_locked_count != 0
            || mmcm_not_locked_count != 0
            || hard_err_count != 0
            || soft_err_count != 0
            || channel_down_count != 0
            || fifo_rx_overflow_count != 0
            || fifo_tx_overflow_count != 0
            || tx_count != 0
            || rx_count != 0) begin
            $error(1, "reset did not work");
            errors = errors + 1;
        end

        rst_u = 1'b0;
        rst = 1'b0;
        repeat (4) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.GT_POWERGOOD;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.GT_POWERGOOD;

        if (gt_not_ready_0_count != 3
            || gt_not_ready_1_count != 3
            || gt_not_ready_2_count != 3
            || gt_not_ready_3_count != 3) begin
            $error(1, "gt_not_ready counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.LINE_UP;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.LINE_UP;

        if (line_down_0_count != 3
            || line_down_1_count != 3 
            || line_down_2_count != 3 
            || line_down_3_count != 3) begin
            $error(1, "line_down counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.GT_PLL_LOCK;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.GT_PLL_LOCK;

        if (pll_not_locked_count != 3) begin
            $error(1, "pll_not_locked counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.MMCM_NOT_LOCKED;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.MMCM_NOT_LOCKED;

        if (mmcm_not_locked_count != 3) begin
            $error(1, "mmcm_not_locked counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.HARD_ERR;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.HARD_ERR;

        if (hard_err_count != 3) begin
            $error(1, "hard_err counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.SOFT_ERR;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.SOFT_ERR;

        if (soft_err_count != 3) begin
            $error(1, "soft_err counter not working");
            errors = errors + 1;
        end

        aurora_status = aurora_status ^ dut.CHANNEL_UP;
        repeat (3) @(posedge clk_u);
        aurora_status = aurora_status ^ dut.CHANNEL_UP;

        if (channel_down_count != 3) begin
            $error(1, "channel_down counter not working");
            errors = errors + 1;
        end

        fifo_rx_almost_full = 1'b1;
        @(posedge clk_u);
        fifo_rx_almost_full = 1'b0;
        @(posedge clk_u);
        fifo_rx_almost_full = 1'b1;
        @(posedge clk_u);
        fifo_rx_almost_full = 1'b0;
        @(posedge clk_u);

        if (fifo_rx_overflow_count != 2) begin
            $error(1, "rx overflow count not correct");
            errors = errors + 1;
        end

        fifo_tx_almost_full = 1'b1;
        @(posedge clk);
        fifo_tx_almost_full = 1'b0;
        @(posedge clk);
        fifo_tx_almost_full = 1'b1;
        @(posedge clk);
        fifo_tx_almost_full = 1'b0;
        @(posedge clk);
        fifo_tx_almost_full = 1'b1;
        @(posedge clk);
        fifo_tx_almost_full = 1'b0;
        @(posedge clk);

        if (fifo_tx_overflow_count != 3) begin
            $error(1, "rx overflow count not correct");
            errors = errors + 1;
        end

        tx_tvalid = 1'b1;
        tx_tready = 1'b1;
        rx_tvalid = 1'b1;
        rx_tready = 1'b1;
        repeat (3) @(posedge clk);
        tx_tvalid = 1'b0;
        repeat (2) @(posedge clk);
        rx_tvalid = 1'b0;

        if (tx_count != 3) begin
            $error(1, "tx count not correct");
        end

        if (rx_count != 5) begin
            $error(1, "rx count not correct");
        end

    end

endmodule
 