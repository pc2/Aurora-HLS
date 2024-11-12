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
    output reg [31:0] core_status_not_ok_count,
    output reg [31:0] fifo_rx_overflow_count,
    output reg [31:0] fifo_tx_overflow_count,
    output reg [31:0] tx_count,
    output reg [31:0] rx_count
);

// TODO: valid+ready+(keep?) count:  byte-counter
// TODO: explicit status
// TODO: counter reset (init)
// TODO: further status?

localparam core_status_ok = 13'h11ff;

reg rx_full_triggered, tx_full_triggered;

always @(posedge clk) begin
    if (rst) begin
        core_status_not_ok_count <= 0;
        fifo_rx_overflow_count <= 0;
        fifo_tx_overflow_count <= 0;
        rx_full_triggered <= fifo_rx_almost_full;
        tx_full_triggered <= fifo_tx_almost_full;
        tx_count <= 0;
        rx_count <= 0;
    end else begin
        if (aurora_status != core_status_ok) begin
            core_status_not_ok_count <= core_status_not_ok_count + 1;
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