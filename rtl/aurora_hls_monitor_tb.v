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

    reg rst_n;
    reg clk;
    reg [12:0] aurora_status;
    reg fifo_rx_almost_full;
    reg fifo_tx_almost_full;

    wire [31:0] core_status_not_ok_count;
    wire [31:0] fifo_rx_overflow_count;
    wire [31:0] fifo_tx_overflow_count;

    aurora_hls_monitor dut (
        .clk(clk),
        .rst_n(rst_n),
        .aurora_status(aurora_status),
        .fifo_rx_almost_full(fifo_rx_almost_full),
        .fifo_tx_almost_full(fifo_tx_almost_full),
        .core_status_not_ok_count(core_status_not_ok_count),
        .fifo_rx_overflow_count(fifo_rx_overflow_count),
        .fifo_tx_overflow_count(fifo_tx_overflow_count)
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

        errors = 0;

        aurora_status = 13'h11ff;
        fifo_rx_almost_full = 1'b0;
        fifo_tx_almost_full = 1'b0;

        rst_n = 1'b0;
        repeat (2) @(posedge clk);

        if (core_status_not_ok_count != 0 || fifo_rx_overflow_count != 0 || fifo_tx_overflow_count != 0) begin
            $error(1, "reset did not work");
            errors = errors + 1;
        end

        rst_n = 1'b1;
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

    end

endmodule
 