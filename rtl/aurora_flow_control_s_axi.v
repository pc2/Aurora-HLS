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
`include "aurora_flow_define.v"

module aurora_flow_control_s_axi (
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
    output reg          core_reset,
    output reg          monitor_reset,
    input wire  [21:0]  configuration,
    input wire  [31:0]  fifo_thresholds,
    input wire  [12:0]  aurora_status,
    input wire  [31:0]  gt_not_ready_0_count,
    input wire  [31:0]  gt_not_ready_1_count,
    input wire  [31:0]  gt_not_ready_2_count,
    input wire  [31:0]  gt_not_ready_3_count,
    input wire  [31:0]  line_down_0_count,
    input wire  [31:0]  line_down_1_count,
    input wire  [31:0]  line_down_2_count,
    input wire  [31:0]  line_down_3_count,
    input wire  [31:0]  pll_not_locked_count,
    input wire  [31:0]  mmcm_not_locked_count,
    input wire  [31:0]  hard_err_count,
    input wire  [31:0]  soft_err_count,
    input wire  [31:0]  channel_down_count,
    input wire  [7:0]   fifo_status,
    input wire  [31:0]  fifo_rx_overflow_count,
    input wire  [31:0]  fifo_tx_overflow_count,
    input wire  [31:0]  nfc_full_trigger_count,
    input wire  [31:0]  nfc_empty_trigger_count,
    input wire  [31:0]  tx_count,
    input wire  [31:0]  rx_count,
    input wire  [31:0]  nfc_latency_count
`ifdef USE_FRAMING
   ,input wire  [31:0]  frames_received,
    input wire  [31:0]  frames_with_errors
`endif
);

localparam
    ADDR_CORE_RESET              = 12'h010,
    ADDR_COUNTER_RESET           = 12'h014,
    ADDR_CONFIGURATION           = 12'h018,
    ADDR_FIFO_THRESHOLDS         = 12'h01c,
    ADDR_AURORA_STATUS           = 12'h020, 
    ADDR_STATUS_NOT_OK_COUNT     = 12'h024,
    ADDR_FIFO_STATUS             = 12'h028,
    ADDR_FIFO_RX_OVERFLOW_COUNT  = 12'h02c,
    ADDR_FIFO_TX_OVERFLOW_COUNT  = 12'h030,
    ADDR_NFC_FULL_TRIGGER_COUNT  = 12'h034,
    ADDR_NFC_EMPTY_TRIGGER_COUNT = 12'h038,
    ADDR_NFC_LATENCY_COUNT       = 12'h03c,
    ADDR_TX_COUNT                = 12'h040,
    ADDR_RX_COUNT                = 12'h044,
    ADDR_GT_NOT_READY_0_COUNT    = 12'h048,
    ADDR_GT_NOT_READY_1_COUNT    = 12'h04c,
    ADDR_GT_NOT_READY_2_COUNT    = 12'h050,
    ADDR_GT_NOT_READY_3_COUNT    = 12'h054,
    ADDR_LINE_DOWN_0_COUNT       = 12'h058,
    ADDR_LINE_DOWN_1_COUNT       = 12'h05c,
    ADDR_LINE_DOWN_2_COUNT       = 12'h060,
    ADDR_LINE_DOWN_3_COUNT       = 12'h064,
    ADDR_PLL_NOT_LOCKED_COUNT    = 12'h068,
    ADDR_MMCM_NOT_LOCKED_COUNT   = 12'h06c,
    ADDR_HARD_ERR_COUNT          = 12'h070,
    ADDR_SOFT_ERR_COUNT          = 12'h074,
    ADDR_CHANNEL_DOWN_COUNT      = 12'h078,
`ifdef USE_FRAMING
    ADDR_FRAMES_RECEIVED         = 12'h07c,
    ADDR_FRAMES_WITH_ERRORS      = 12'h080,
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
            core_reset <= 1'b0;
            monitor_reset <= 1'b0;
        end else if (w_hs) begin
            case (waddr)
                ADDR_CORE_RESET: begin
                    if (WSTRB[0])
                        core_reset <= WDATA[0];
                end
                ADDR_COUNTER_RESET: begin
                    if (WSTRB[0])
                        monitor_reset <= WDATA[0];
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
                ADDR_GT_NOT_READY_0_COUNT: begin
                    rdata <= gt_not_ready_0_count;
                end
                ADDR_GT_NOT_READY_1_COUNT: begin
                    rdata <= gt_not_ready_1_count;
                end
                ADDR_GT_NOT_READY_2_COUNT: begin
                    rdata <= gt_not_ready_3_count;
                end
                ADDR_GT_NOT_READY_2_COUNT: begin
                    rdata <= gt_not_ready_3_count;
                end
                ADDR_LINE_DOWN_0_COUNT: begin
                    rdata <= line_down_0_count;
                end
                ADDR_LINE_DOWN_1_COUNT: begin
                    rdata <= line_down_1_count;
                end
                ADDR_LINE_DOWN_2_COUNT: begin
                    rdata <= line_down_2_count;
                end
                ADDR_LINE_DOWN_3_COUNT: begin
                    rdata <= line_down_3_count;
                end
                ADDR_PLL_NOT_LOCKED_COUNT: begin
                    rdata <= pll_not_locked_count;
                end
                ADDR_MMCM_NOT_LOCKED_COUNT: begin
                    rdata <= mmcm_not_locked_count;
                end
                ADDR_HARD_ERR_COUNT: begin
                    rdata <= hard_err_count;
                end
                ADDR_SOFT_ERR_COUNT: begin
                    rdata <= soft_err_count;
                end
                ADDR_CHANNEL_DOWN_COUNT: begin
                    rdata <= channel_down_count;
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
                ADDR_NFC_FULL_TRIGGER_COUNT: begin
                    rdata <= nfc_full_trigger_count;
                end
                ADDR_NFC_EMPTY_TRIGGER_COUNT: begin
                    rdata <= nfc_empty_trigger_count;
                end
                ADDR_NFC_LATENCY_COUNT: begin
                    rdata <= nfc_latency_count;
                end
                ADDR_TX_COUNT: begin
                    rdata <= tx_count;
                end
                ADDR_RX_COUNT: begin
                    rdata <= rx_count;
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
