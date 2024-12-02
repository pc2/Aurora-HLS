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

module aurora_hls_nfc (
    input wire  rst_n,
    input wire  counter_reset,
    input wire  clk,
    input wire  fifo_rx_prog_full,
    input wire  fifo_rx_prog_empty,
    input wire  rx_tvalid,
    input wire  s_axi_nfc_tready,
    output reg  s_axi_nfc_tvalid,
    output reg [0:15] s_axi_nfc_tdata,
    output reg [31:0] full_trigger_count,
    output reg [31:0] empty_trigger_count,
    output reg [31:0] max_latency
);

localparam empty = 3'b000;
localparam empty_transmit = 3'b001;
localparam empty_triggered = 3'b010;
localparam full = 3'b011;
localparam full_transmit = 3'b100;
localparam full_triggered = 3'b101;
localparam idle = 3'b110;
localparam reset = 3'b111;

reg [2:0] current_state, next_state;

// default big endian
reg [0:15] nfc_xoff = 16'hffff;
reg [0:15] nfc_xon = 16'h0000;

reg [31:0] latency_count;

always @ (posedge clk) begin
    case(current_state)
    reset: begin
        s_axi_nfc_tvalid <= 1'b0;
        s_axi_nfc_tdata <= 16'h0000;
        if (fifo_rx_prog_empty) begin
            next_state = empty;
        end
        else if (fifo_rx_prog_full) begin
            next_state = full;
        end
        else begin
            next_state = idle;
        end
        empty_trigger_count <= 0;
        full_trigger_count <= 0;
        latency_count <= 0;
        max_latency <= 0;
    end
    empty_triggered: begin
        s_axi_nfc_tdata <= nfc_xon;
        s_axi_nfc_tvalid <= 1'b1;
        next_state = empty_transmit;
        empty_trigger_count <= empty_trigger_count + 1;
    end
    empty_transmit: begin
        if (s_axi_nfc_tready) begin
            s_axi_nfc_tvalid <= 1'b0;
            next_state = empty;
        end
    end
    empty: begin
        if (!fifo_rx_prog_empty) begin
            next_state = idle;
        end
    end
    full_triggered: begin
        s_axi_nfc_tdata <= nfc_xoff;
        s_axi_nfc_tvalid <= 1'b1;
        next_state = full_transmit;
        full_trigger_count <= full_trigger_count + 1;
        latency_count <= 0;
    end
    full_transmit: begin
        if (s_axi_nfc_tready) begin
            s_axi_nfc_tvalid <= 1'b0;
            next_state = full;
        end
        latency_count <= latency_count + 1;
    end
    full: begin
        if (!fifo_rx_prog_full) begin
            next_state = idle;
            if (latency_count > max_latency) begin
                max_latency <= latency_count;
            end
            latency_count <= 0;
        end
        else if (rx_tvalid) begin
            latency_count <= latency_count + 1;
        end
    end
    idle: begin
        if (fifo_rx_prog_empty) begin
            next_state = empty_triggered;
        end
        else if (fifo_rx_prog_full) begin
            next_state = full_triggered;
        end
    end
    endcase

    if (!rst_n) begin
        current_state <= reset;
    end else begin
        current_state <= next_state;
    end

    if (counter_reset) begin
        empty_trigger_count <= 0;
        full_trigger_count <= 0;
        latency_count <= 0;
        max_latency <= 0;
    end

end

endmodule
