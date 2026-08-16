/*
 * Copyright 2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
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
`timescale 1ns/1ps
`default_nettype none

module aurora_flow_control_s_axi_tb();
    localparam real CLK_PERIOD_NS = 2.4826; // 402.8 MHz
    localparam integer TIMEOUT_CYCLES = 8;

    reg ACLK = 1'b0;
    reg ARESETn = 1'b0;
    reg [11:0] AWADDR = 12'b0;
    reg AWVALID = 1'b0;
    wire AWREADY;
    reg [31:0] WDATA = 32'b0;
    reg [3:0] WSTRB = 4'b0;
    reg WVALID = 1'b0;
    wire WREADY;
    wire [1:0] BRESP;
    wire BVALID;
    reg BREADY = 1'b0;
    reg [11:0] ARADDR = 12'b0;
    reg ARVALID = 1'b0;
    wire ARREADY;
    wire [31:0] RDATA;
    wire [1:0] RRESP;
    wire RVALID;
    reg RREADY = 1'b0;
    wire core_reset;
    wire monitor_reset;

    reg [21:0] configuration = 22'h2a55a5;
    reg [31:0] fifo_thresholds = 32'h1234abcd;
    reg [12:0] aurora_status = 13'h1357;

    integer cycles;
    reg [31:0] held_rdata;

    always #(CLK_PERIOD_NS / 2.0) ACLK = ~ACLK;

    aurora_flow_control_s_axi dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .core_reset(core_reset),
        .monitor_reset(monitor_reset),
        .configuration(configuration),
        .fifo_thresholds(fifo_thresholds),
        .aurora_status(aurora_status),
        .gt_not_ready_0_count(32'h01010101),
        .gt_not_ready_1_count(32'h02020202),
        .gt_not_ready_2_count(32'h03030303),
        .gt_not_ready_3_count(32'h04040404),
        .line_down_0_count(32'h05050505),
        .line_down_1_count(32'h06060606),
        .line_down_2_count(32'h07070707),
        .line_down_3_count(32'h08080808),
        .pll_not_locked_count(32'h09090909),
        .mmcm_not_locked_count(32'h0a0a0a0a),
        .hard_err_count(32'h0b0b0b0b),
        .soft_err_count(32'h0c0c0c0c),
        .channel_down_count(32'h0d0d0d0d),
        .fifo_status(8'ha5),
        .fifo_rx_overflow_count(32'h0e0e0e0e),
        .fifo_tx_overflow_count(32'h0f0f0f0f),
        .nfc_full_trigger_count(32'h10101010),
        .nfc_empty_trigger_count(32'h11111111),
        .tx_count(32'h12121212),
        .rx_count(32'h13131313),
        .nfc_latency_count(32'h14141414)
    );

    task automatic axi_read;
        input [11:0] address;
        input [31:0] expected;
        input integer backpressure_cycles;
        begin
            @(negedge ACLK);
            ARADDR = address;
            ARVALID = 1'b1;
            RREADY = 1'b0;

            cycles = 0;
            while (!ARREADY && cycles < TIMEOUT_CYCLES) begin
                @(negedge ACLK);
                cycles = cycles + 1;
            end
            if (!ARREADY)
                $fatal(1, "ARREADY timeout at 0x%03h", address);

            @(posedge ACLK);
            #0.001;
            ARVALID = 1'b0;

            cycles = 0;
            while (!RVALID && cycles < TIMEOUT_CYCLES) begin
                @(posedge ACLK);
                #0.001;
                cycles = cycles + 1;
            end
            if (!RVALID)
                $fatal(1, "RVALID timeout at 0x%03h", address);
            if (RRESP !== 2'b00)
                $fatal(1, "RRESP at 0x%03h was %02b", address, RRESP);
            if (RDATA !== expected)
                $fatal(1, "read 0x%03h returned 0x%08h, expected 0x%08h",
                       address, RDATA, expected);

            held_rdata = RDATA;
            repeat (backpressure_cycles) begin
                @(posedge ACLK);
                #0.001;
                if (!RVALID || RDATA !== held_rdata)
                    $fatal(1, "read response changed under backpressure at 0x%03h",
                           address);
            end

            @(negedge ACLK);
            RREADY = 1'b1;
            @(posedge ACLK);
            #0.001;
            @(negedge ACLK);
            RREADY = 1'b0;
            ARADDR = 12'b0;

            @(posedge ACLK);
            #0.001;
            if (RVALID)
                $fatal(1, "read response did not retire at 0x%03h", address);
        end
    endtask

    initial begin
        repeat (4) @(posedge ACLK);
        #0.001;
        if (core_reset !== 1'b0 || monitor_reset !== 1'b0)
            $fatal(1, "control outputs were not reset");

        @(negedge ACLK);
        ARESETn = 1'b1;
        repeat (2) @(posedge ACLK);

        // AuroraFlow::read_configuration() performs these two reads.
        axi_read(12'h018, {10'b0, configuration}, 3);
        axi_read(12'h01c, fifo_thresholds, 0);

        // Verify that a third consecutive transaction starts cleanly.
        axi_read(12'h020, {19'b0, aurora_status}, 1);

        $display("PASS: AuroraFlow AXI-Lite reads at 402.8 MHz");
        $finish;
    end

    initial begin
        #(CLK_PERIOD_NS * 100.0);
        $fatal(1, "testbench timeout");
    end
endmodule

`default_nettype wire
