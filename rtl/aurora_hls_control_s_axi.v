//
// Copyright 2022 Xilinx, Inc.
//           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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
    input wire  [12:0]  aurora_status,
    input wire  [7:0]   fifo_status,
    input wire  [21:0]  configuration,
    input wire  [31:0]  fifo_thresholds
`ifdef USE_FRAMING
,   input wire  [31:0]  frames_received,
    input wire  [31:0]  frames_with_errors
`endif
);

//------------------------Address Info-------------------
// 0x00 : reserved
// 0x04 : reserved
// 0x08 : reserved
// 0x0c : reserved
// 0x10 : Aurora status
// 0x14 : FIFO status
// 0x18 : Configuration
// 0x1c : FIFO thresholds (configuration)
// only with framing enabled:
// 0x20 : Frames received
// 0x24 : Frames with errors

//------------------------Parameter----------------------
localparam
    ADDR_AURORA_STATUS  = 12'h010, 
    ADDR_FIFO_STATUS    = 12'h014,
    ADDR_CONFIGURATION  = 12'h018,
    ADDR_FIFO_THRESHOLDS = 12'h01c,
`ifdef USE_FRAMING
    ADDR_FRAMES_RECEIVED = 12'h020,
    ADDR_FRAMES_WITH_ERRORS = 12'h024,
`endif
    
    // registers read state machine
    RDIDLE          = 2'd0,
    RDDATA          = 2'd1,
    RDRESET         = 2'd2;

//------------------------Signal Declaration----------------------
    // axi operation
    reg  [1:0]      rstate;
    reg  [1:0]      rnext;
    reg  [31:0]     rdata;
    wire            ar_hs;
    wire [11:0]     raddr;
    

//------------------------AXI protocol control------------------    
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
                ADDR_AURORA_STATUS: begin
                    rdata <= aurora_status;
                end
                ADDR_FIFO_STATUS: begin
                    rdata <= fifo_status;
                end
                ADDR_CONFIGURATION: begin
                    rdata <= configuration;
                end
                ADDR_FIFO_THRESHOLDS: begin
                    rdata <= fifo_thresholds;
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

    // axi write channel tie-off
    assign AWREADY = 1'b1;
    assign WREADY  = 1'b1;
    assign BRESP   = 2'b00;
    assign BVALID  = 1'b0;

endmodule
