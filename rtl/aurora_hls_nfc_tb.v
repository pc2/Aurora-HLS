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

module aurora_hls_nfc_tb();
    reg rst_n;
    reg clk;
    reg fifo_rx_prog_full;
    reg fifo_rx_prog_empty;
    reg s_axi_nfc_tready;
    wire s_axi_nfc_tvalid;
    wire [15:0] s_axi_nfc_tdata;
    reg rx_tvalid;
    wire [31:0] full_trigger_count, empty_trigger_count;

    aurora_hls_nfc dut (
        .clk(clk),
        .rst_n(rst_n),
        .fifo_rx_prog_full(fifo_rx_prog_full),
        .fifo_rx_prog_empty(fifo_rx_prog_empty),
        .s_axi_nfc_tready(s_axi_nfc_tready),
        .s_axi_nfc_tvalid(s_axi_nfc_tvalid),
        .s_axi_nfc_tdata(s_axi_nfc_tdata),
        .rx_tvalid(rx_tvalid),
        .full_trigger_count(full_trigger_count),
        .empty_trigger_count(empty_trigger_count)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    reg [15:0] errors;

    initial begin
        $dumpfile("nfc_tb.vcd");
        $dumpvars(0, aurora_hls_nfc);
        $monitor("s_axi_nfc_tvalid = %d", s_axi_nfc_tvalid);
        $monitor("s_axi_nfc_tdata = %d", s_axi_nfc_tdata);
        $monitor("full_trigger_count = %d", full_trigger_count);
        $monitor("empty_trigger_count = %d", empty_trigger_count);

        errors = 4'h0;

        fifo_rx_prog_full = 1'b0;
        fifo_rx_prog_empty = 1'b0;
        s_axi_nfc_tready = 1'b0;
        rst_n = 1'b0;
        repeat (2) @(posedge clk);

        if (s_axi_nfc_tvalid != 1'b0 || s_axi_nfc_tdata != 16'h0000) begin
            $error(1, "reset did not work");
            errors = errors + 1;
        end

        rst_n = 1'b1;
        repeat (4) @(posedge clk);
        fifo_rx_prog_empty = 1'b0;
        s_axi_nfc_tready = 1'b0;
        fifo_rx_prog_full = 1'b0;
        @(posedge clk);
        fifo_rx_prog_full = 1'b1;
        repeat (5) @(posedge clk);

        if (s_axi_nfc_tvalid != 1'b1 || s_axi_nfc_tdata != 16'hffff) begin
            $error(1, "no xoff signal");
            errors = errors + 1;
        end

        if (full_trigger_count != 1 && empty_trigger_count != 0) begin
            $error(1, "full trigger counting not correct");
            errors = errors + 1;
        end

        s_axi_nfc_tready = 1'b1;
        repeat (20) @(posedge clk);
        fifo_rx_prog_full = 1'b0;
        repeat (5) @(posedge clk);
        fifo_rx_prog_empty = 1'b1;
        repeat (2) @(posedge clk);

        if (s_axi_nfc_tvalid != 1'b1 || s_axi_nfc_tdata != 16'h0000) begin
            $error(1, "no xon signal");
            errors = errors + 1;
        end

        if (full_trigger_count != 1 && empty_trigger_count != 1) begin
            $error(1, "empty trigger counting not correct");
            errors = errors + 1;
        end

        repeat (4) @(posedge clk);
        fifo_rx_prog_empty = 1'b0;

    end
 
endmodule
