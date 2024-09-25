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

module aurora_hls_crc_counter_tb();
    reg rst_n;
    reg clk;
    reg crc_valid;
    reg crc_pass_fail_n;
    wire [31:0] frames_received;
    wire [31:0] frames_with_errors;

    aurora_hls_crc_counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .crc_valid(crc_valid),
        .crc_pass_fail_n(crc_pass_fail_n),
        .frames_received(frames_received),
        .frames_with_errors(frames_with_errors)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    reg [3:0] errors;

    initial begin
        $dumpfile("crc_counter_tb.vcd");
        $dumpvars(0, aurora_hls_crc_counter_tb);
        $monitor("frames_received = %d", frames_received);
        $monitor("frames_with_errors = %d", frames_with_errors);

        errors = 4'h0;

        rst_n = 1'b0;
        crc_valid = 1'b0;
        crc_pass_fail_n = 1'b0;
        repeat (2) @(posedge clk);

        if (frames_received != 0 || frames_with_errors != 0) begin
            $error(1, "reset did not work at time %0t", $time);
            errors <= errors + 1;
        end

        rst_n = 1'b1;
        @(posedge clk);
        crc_valid = 1'b1;
        crc_pass_fail_n = 1'b1;
        repeat (4) begin
            @(posedge clk);
            crc_valid = 1'b1;
        end
        crc_pass_fail_n = 1'b0;
        @(posedge clk);
        crc_valid = 1'b0;
        crc_pass_fail_n = 1'b1;
        @(posedge clk);
        crc_valid = 1'b1;
        @(posedge clk);
        crc_valid = 1'b0;

        if (frames_received != 6) begin
            $error(1, "wrong frame counter");
            errors = errors + 1;
        end
        if (frames_with_errors != 1) begin
            $error(1, "wrong error counter");
            errors = errors + 1;
        end
    end
endmodule
