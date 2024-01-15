/*
 * Copyright 2022 Xilinx, Inc.
 *           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

module aurora_hls_reset(
    input wire init_clk,
    input wire ap_rst_n_i,
    output reg reset_pb_i,
    output reg pma_init_i
);

// use rst_cnt to generate asserted reset_pb longer than 1 second.
// Assume 100MHz init_clk is used, so 27bit counter is needed. 
// Apparently it works as well for 50MHz init_clk
reg [26:0]      rst_cnt;

always @ (posedge init_clk or negedge ap_rst_n_i) begin
    if (!ap_rst_n_i) begin
        reset_pb_i <= 1'b1;
        pma_init_i <= 1'b1;
        rst_cnt    <= 27'b0;
    end else begin
        if (rst_cnt != 27'h7ff_ffff) begin
            rst_cnt <= rst_cnt + 1'b1;
        end
        if (rst_cnt == 27'h7ff_ff00) begin
            pma_init_i <= 1'b0;
        end
        if (rst_cnt == 27'h7ff_ffff) begin
            reset_pb_i <= 1'b0;
        end
    end
end

endmodule