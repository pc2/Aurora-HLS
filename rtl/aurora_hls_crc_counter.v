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

module aurora_hls_crc_counter(
    input wire clk,
    input wire rst_n,
    input wire crc_valid,
    input wire crc_pass_fail_n,
    output reg [31:0] frames_received,
    output reg [31:0] frames_with_errors
);

always @(posedge clk) begin
    if (!rst_n) begin
        frames_received <= 32'h00000000;
        frames_with_errors <= 32'h00000000;
    end
    if (crc_valid) begin
        frames_received <= frames_received + 1'b1;
        if (!crc_pass_fail_n) begin
            frames_with_errors <= frames_with_errors + 1'b1;
        end
    end
end

`ifdef PROBE_CRC_COUNTER
ila_crc_counter ila_crc_counter_0 (
    .clk(clk),
    .probe0(rst_n),
    .probe1(crc_valid),
    .probe2(crc_pass_fail_n),
    .probe3(frames_received),
    .probe4(frames_with_errors)
);
`endif


endmodule
