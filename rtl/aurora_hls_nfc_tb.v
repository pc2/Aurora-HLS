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
    wire [15:0] s_axi_nfc_tdata;

    aurora_hls_nfc dut (
        .clk(clk),
        .rst_n(rst_n),
        .fifo_rx_prog_full(fifo_rx_prog_full),
        .fifo_rx_prog_empty(fifo_rx_prog_empty),
        .s_axi_nfc_tready(s_axi_nfc_tready),
        .s_axi_nfc_tvalid(s_axi_nfc_tvalid),
        .s_axi_nfc_tdata(s_axi_nfc_tdata)
    );

    always begin
        clk = 1'b0;
        #10;
        clk = 1'b1;
        #10;
    end

    initial begin
        fifo_rx_prog_full = 1'b0;
        fifo_rx_prog_empty = 1'b0;
        s_axi_nfc_tready = 1'b0;
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
        #80;
        fifo_rx_prog_empty = 1'b0;
        s_axi_nfc_tready = 1'b0;
        fifo_rx_prog_full = 1'b0;
        #20;
        fifo_rx_prog_full = 1'b1;
        #100;
        s_axi_nfc_tready = 1'b1;
        #400;
        fifo_rx_prog_full = 1'b0;
        #100
        fifo_rx_prog_empty = 1'b1;
        #400
        fifo_rx_prog_empty = 1'b0;
    end
 
endmodule
