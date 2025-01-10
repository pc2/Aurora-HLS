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
`include "aurora_flow_define.v"

module aurora_flow_configuration(
    output wire [21:0] configuration,
    output wire [31:0] fifo_thresholds
);

localparam
    HAS_TKEEP = 1'b`HAS_TKEEP,
    HAS_TLAST = 1'b`HAS_TLAST,
    FIFO_WIDTH = 9'd`FIFO_WIDTH,
    RX_FIFO_DEPTH = 16'd`RX_FIFO_DEPTH,
    INS_LOSS_NYQ = 5'd`INS_LOSS_NYQ,
    RX_EQ_MODE = `RX_EQ_MODE,
    RX_FIFO_PROG_FULL = 16'd`RX_FIFO_PROG_FULL,
    RX_FIFO_PROG_EMPTY = 16'd`RX_FIFO_PROG_EMPTY;

wire [1:0] RX_EQ_MODE_BINARY;

case(RX_EQ_MODE)
    "AUTO": assign RX_EQ_MODE_BINARY = 2'b00;
    "LPM": assign RX_EQ_MODE_BINARY = 2'b01;
    "DFE": assign RX_EQ_MODE_BINARY = 2'b10;
    default: assign RX_EQ_MODE_BINARY = 2'b11;
endcase

wire [3:0] RX_FIFO_DEPTH_LOG2;
assign RX_FIFO_DEPTH_LOG2 = $clog2(RX_FIFO_DEPTH);

assign configuration = {
    INS_LOSS_NYQ,
    RX_EQ_MODE_BINARY,
    RX_FIFO_DEPTH_LOG2,
    FIFO_WIDTH,
    HAS_TLAST,
    HAS_TKEEP
};

assign fifo_thresholds = {
    RX_FIFO_PROG_FULL,
    RX_FIFO_PROG_EMPTY
};

endmodule
