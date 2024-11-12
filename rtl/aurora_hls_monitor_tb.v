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

    reg rst;
    reg clk;
    reg [12:0] aurora_status;
    reg fifo_rx_almost_full;
    reg fifo_tx_almost_full;
    reg tx_tvalid;
    reg tx_tready;
    reg rx_tvalid;

    wire [31:0] core_status_not_ok_count;
    wire [31:0] fifo_rx_overflow_count;
    wire [31:0] fifo_tx_overflow_count;
    wire [31:0] tx_count;
    wire [31:0] rx_count;

    aurora_hls_monitor dut (
        .clk(clk),
        .rst(rst),
        .aurora_status(aurora_status),
        .fifo_rx_almost_full(fifo_rx_almost_full),
        .fifo_tx_almost_full(fifo_tx_almost_full),
        .tx_tvalid(tx_tvalid),
        .tx_tready(tx_tready),
        .rx_tvalid(rx_tvalid),
        .core_status_not_ok_count(core_status_not_ok_count),
        .fifo_rx_overflow_count(fifo_rx_overflow_count),
        .fifo_tx_overflow_count(fifo_tx_overflow_count),
        .tx_count(tx_count),
        .rx_count(rx_count)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    reg [15:0] errors;

    initial begin
        $dumpfile("monitor_tb.vcd");
        $dumpvars(0, aurora_hls_monitor);
        $monitor("core_status_not_ok_count = %d", core_status_not_ok_count);
        $monitor("fifo_rx_overflow_count = %d", fifo_rx_overflow_count);
        $monitor("fifo_tx_overflow_count = %d", fifo_tx_overflow_count);
        $monitor("tx_count = %d", tx_count);
        $monitor("rx_count = %d", rx_count);

        errors = 0;

        aurora_status = 13'h11ff;
        fifo_rx_almost_full = 1'b0;
        fifo_tx_almost_full = 1'b0;
        tx_tvalid = 1'b0;
        tx_tready = 1'b0;
        rx_tvalid = 1'b0;

        rst = 1'b1;
        repeat (2) @(posedge clk);

        if (core_status_not_ok_count != 0 || fifo_rx_overflow_count != 0 || fifo_tx_overflow_count != 0) begin
            $error(1, "reset did not work");
            errors = errors + 1;
        end

        rst = 1'b0;
        repeat (4) @(posedge clk);
        aurora_status = aurora_status - 1;
        repeat (3) @(posedge clk);
        aurora_status = aurora_status + 1;

        if (core_status_not_ok_count != 3) begin
            $error(1, "status_not_ok count not correct");
            errors = errors + 1;
        end

        fifo_rx_almost_full = 1'b1;
        @(posedge clk);
        fifo_rx_almost_full = 1'b0;
        @(posedge clk);
        fifo_rx_almost_full = 1'b1;
        @(posedge clk);
        fifo_rx_almost_full = 1'b0;
        @(posedge clk);

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
 