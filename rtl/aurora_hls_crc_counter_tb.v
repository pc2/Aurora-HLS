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

    always begin
        clk = 1'b0;
        #10;
        clk = 1'b1;
        #10;
    end

    initial begin
        crc_valid = 1'b0;
        crc_pass_fail_n = 1'b0;
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
        #80;
        crc_valid = 1'b1;
        crc_pass_fail_n = 1'b1;
        #20
        crc_valid = 1'b0;
        #20
        crc_valid = 1'b1;
        #20
        crc_valid = 1'b0;
        #20
        crc_valid = 1'b1;
        #20
        crc_valid = 1'b0;
        #20
        crc_valid = 1'b1;
        #20
        crc_valid = 1'b0;
        #20
        crc_valid = 1'b1;
        crc_pass_fail_n = 1'b0;
        #20
        crc_valid = 1'b0;
        crc_pass_fail_n = 1'b1;
        #20
        crc_valid = 1'b1;
        #20
        crc_valid = 1'b0;
    end
 
endmodule
