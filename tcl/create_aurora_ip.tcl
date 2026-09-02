#
# Copyright 2022 Xilinx, Inc.
#           2023-2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Set the device part from the command-line arguments.
set_part [lindex $argv 0]

set instance [lindex $argv 1]
set ins_loss_nyq [lindex $argv 2]
set rx_eq_mode [lindex $argv 3]

set use_framing [lindex $argv 4]

set version [lindex $argv 5]

if {$use_framing == "1"} {
    set interface_mode "Framing"
    set crc_mode "true"
} else {
    set interface_mode "Streaming"
    set crc_mode "false"
}


# ----------------------------------------------------------------------------
# Generate the Aurora IP.
# ----------------------------------------------------------------------------
create_ip -name aurora_64b66b \
          -vendor xilinx.com \
          -library ip \
          -version $version \
          -module_name aurora_64b66b_$instance \
          -dir ./ip_creation

# Match the little-endian [n:0] AXI bus ordering used by Vitis and HLS.
set_property -dict [list CONFIG.C_AURORA_LANES {4} \
                         CONFIG.C_LINE_RATE {25.78125} \
                         CONFIG.C_REFCLK_FREQUENCY {161.1328125} \
                         CONFIG.C_INIT_CLK {100} \
                         CONFIG.C_USE_BYTESWAP {true} \
                         CONFIG.INS_LOSS_NYQ $ins_loss_nyq \
                         CONFIG.RX_EQ_MODE $rx_eq_mode \
                         CONFIG.flow_mode {Immediate_NFC} \
                         CONFIG.interface_mode $interface_mode \
                         CONFIG.crc_mode $crc_mode \
                         CONFIG.drp_mode {Native} \
                         CONFIG.SupportLevel {1}] \
             [get_ips aurora_64b66b_$instance]

generate_target all [get_files ./ip_creation/aurora_64b66b_$instance/aurora_64b66b_$instance.xci]
