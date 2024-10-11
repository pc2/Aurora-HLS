//
// Copyright 2021-2022 Xilinx, Inc.
//           2023-2024 Gerrit Pape (papeg@mail.upb.de)
//           2023-2024 Paderborn Center for Parallel Computing
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

`default_nettype none
`include "aurora_hls_define.v"

module aurora_hls_control_s_axi (
    input wire          ACLK,
    input wire          ARESETn,
    // AXI signals
    input wire  [11:0]  AWADDR,
    input wire          AWVALID,
    output wire         AWREADY,
    input wire  [31:0]  WDATA,
    input wire  [3:0]   WSTRB,
    input wire          WVALID,
    output wire         WREADY,
    output wire [1:0]   BRESP,
    output wire         BVALID,
    input wire          BREADY,
    input wire  [11:0]  ARADDR,
    input wire          ARVALID,
    output wire         ARREADY,
    output wire [31:0]  RDATA,
    output wire [1:0]   RRESP,
    output wire         RVALID,
    input wire          RREADY,
    // control register signals
    input wire  [21:0]  configuration,
    input wire  [31:0]  fifo_thresholds,
    input wire  [12:0]  aurora_status,
    input wire  [31:0]  core_status_not_ok_count,
    input wire  [7:0]   fifo_status,
    input wire  [31:0]  fifo_rx_overflow_count,
    input wire  [31:0]  fifo_tx_overflow_count,
    output reg          sw_reset
`ifdef USE_FRAMING
   ,input wire  [31:0]  frames_received,
    input wire  [31:0]  frames_with_errors
`endif
);

//------------------------Address Info-------------------
// 0x00 : reserved
// 0x04 : reserved
// 0x08 : reserved
// 0x0c : reserved
// 0x10 : Configuration
// 0x14 : FIFO thresholds (configuration)
// 0x18 : Aurora status
// 0x1c : Status not OK count
// 0x20 : FIFO status
// 0x24 : FIFO RX overflow count
// 0x28 : FIFO TX overflow count
// 0x2c : Software-controlled reset (LSB, active high)
// only with framing enabled:
// 0x30 : Frames received
// 0x34 : Frames with errors

//------------------------Parameter----------------------
localparam
    ADDR_CONFIGURATION          = 12'h010,
    ADDR_FIFO_THRESHOLDS        = 12'h014,
    ADDR_AURORA_STATUS          = 12'h018, 
    ADDR_STATUS_NOT_OK_COUNT    = 12'h01c,
    ADDR_FIFO_STATUS            = 12'h020,
    ADDR_FIFO_RX_OVERFLOW_COUNT = 12'h024,
    ADDR_FIFO_TX_OVERFLOW_COUNT = 12'h028,
    ADDR_SW_RESET               = 12'h02c,
`ifdef USE_FRAMING
    ADDR_FRAMES_RECEIVED        = 12'h030,
    ADDR_FRAMES_WITH_ERRORS     = 12'h034,
`endif
    
    // registers write state machine
    WRIDLE          = 2'd0,
    WRDATA          = 2'd1,
    WRRESP          = 2'd2,
    WRRESET         = 2'd3,
    
    // registers read state machine
    RDIDLE          = 2'd0,
    RDDATA          = 2'd1,
    RDRESET         = 2'd2;

//------------------------Signal Declaration----------------------
    // axi operation
    reg  [1:0]      wstate;
    reg  [1:0]      wnext;
    reg  [11:0]     waddr;
    wire [31:0]     wmask;
    wire            aw_hs;
    wire            w_hs;
    reg  [1:0]      rstate;
    reg  [1:0]      rnext;
    reg  [31:0]     rdata;
    wire            ar_hs;
    wire [11:0]     raddr;

//------------------------AXI protocol control------------------    
    //------------------------AXI write fsm------------------
    assign AWREADY = (wstate == WRIDLE);
    assign WREADY  = (wstate == WRDATA);
    assign BRESP   = 2'b00;  // OKAY
    assign BVALID  = (wstate == WRRESP);
    assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
    assign aw_hs   = AWVALID & AWREADY;
    assign w_hs    = WVALID & WREADY;

    // wstate
    always @(posedge ACLK) begin
        if (!ARESETn)
            wstate <= WRRESET;
        else
            wstate <= wnext;
    end
    
    // wnext
    always @(*) begin
        case (wstate)
            WRIDLE:
                if (AWVALID)
                    wnext = WRDATA;
                else
                    wnext = WRIDLE;
            WRDATA:
                if (WVALID)
                    wnext = WRRESP;
                else
                    wnext = WRDATA;
            WRRESP:
                if (BREADY)
                    wnext = WRIDLE;
                else
                    wnext = WRRESP;
            default:
                wnext = WRIDLE;
        endcase
    end
    
    // waddr
    always @(posedge ACLK) begin
        if (aw_hs)
            waddr <= AWADDR;
    end

    // wdata
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            sw_reset <= 1'b0;
        end else if (w_hs) begin
            case (waddr)
                ADDR_SW_RESET: begin
                    if (WSTRB[0])
                        sw_reset <= WDATA[0];
                end
            endcase
        end
    end
    
    //------------------------AXI read fsm-------------------
    assign ARREADY = (rstate == RDIDLE);
    assign RDATA   = rdata;
    assign RRESP   = 2'b00;  // OKAY
    assign RVALID  = (rstate == RDDATA);
    assign ar_hs   = ARVALID & ARREADY;
    assign raddr   = ARADDR;
    
    // rstate
    always @(posedge ACLK) begin
        if (!ARESETn)
            rstate <= RDRESET;
        else
            rstate <= rnext;
    end
    
    // rnext
    always @(*) begin
        case (rstate)
            RDIDLE:
                if (ARVALID)
                    rnext = RDDATA;
                else
                    rnext = RDIDLE;
            RDDATA:
                if (RREADY & RVALID)
                    rnext = RDIDLE;
                else
                    rnext = RDDATA;
            default:
                rnext = RDIDLE;
        endcase
    end
    
    // rdata
    always @(posedge ACLK) begin
        if (ar_hs) begin
            case (raddr)
                ADDR_CONFIGURATION: begin
                    rdata <= configuration;
                end
                ADDR_FIFO_THRESHOLDS: begin
                    rdata <= fifo_thresholds;
                end
                ADDR_AURORA_STATUS: begin
                    rdata <= aurora_status;
                end
                ADDR_STATUS_NOT_OK_COUNT: begin
                    rdata <= core_status_not_ok_count;
                end
                ADDR_FIFO_STATUS: begin
                    rdata <= fifo_status;
                end
                ADDR_FIFO_RX_OVERFLOW_COUNT: begin
                    rdata <= fifo_rx_overflow_count;
                end
                ADDR_FIFO_TX_OVERFLOW_COUNT: begin
                    rdata <= fifo_tx_overflow_count;
                end
`ifdef USE_FRAMING
                ADDR_FRAMES_RECEIVED: begin
                    rdata <= frames_received;   
                end
                ADDR_FRAMES_WITH_ERRORS: begin
                    rdata <= frames_with_errors;
                end
`endif
            endcase
        end
    end

endmodule
