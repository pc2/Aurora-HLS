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
`timescale 1ns/1ps
`default_nettype none

module aurora_flow_configuration_tb();
    wire [21:0] configuration;
    wire [31:0] fifo_thresholds;

    aurora_flow_configuration dut (
        .configuration(configuration),
        .fifo_thresholds(fifo_thresholds)
    );

    initial begin
        $dumpfile("configuration_tb.vcd");
        $dumpvars(0, aurora_flow_configuration_tb);
        $monitor("configuration = %b", configuration);
        $monitor("fifo_thresholds = %b", fifo_thresholds);
    end


endmodule
