#
# Copyright 2022 Xilinx, Inc.
#           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

# set the device part from command line argvs
set_part [lindex $argv 0]

set instance [lindex $argv 1]
set ins_loss_nyq [lindex $argv 2]
set rx_eq_mode [lindex $argv 3]

set use_framing [lindex $argv 4]

if {$use_framing == "1"} {
    set interface_mode "Framing"
    set crc_mode "true"
} else {
    set interface_mode "Streaming"
    set crc_mode "false"
}


# ----------------------------------------------------------------------------
# generate Aurora IP
# ----------------------------------------------------------------------------
create_ip -name aurora_64b66b \
          -vendor xilinx.com \
          -library ip \
          -version 12.0 \
          -module_name aurora_64b66b_$instance \
          -dir ./ip_creation

set_property -dict [list CONFIG.C_AURORA_LANES {4} \
                         CONFIG.C_LINE_RATE {25.78125} \
                         CONFIG.C_REFCLK_FREQUENCY {161.1328125} \
                         CONFIG.C_INIT_CLK {100} \
                         CONFIG.INS_LOSS_NYQ $ins_loss_nyq \
                         CONFIG.RX_EQ_MODE $rx_eq_mode \
                         CONFIG.flow_mode {Immediate_NFC} \
                         CONFIG.interface_mode $interface_mode \
                         CONFIG.crc_mode $crc_mode \
                         CONFIG.drp_mode {Native} \
                         CONFIG.SupportLevel {1}] \
             [get_ips aurora_64b66b_$instance]

generate_target all [get_files ./ip_creation/aurora_64b66b_$instance/aurora_64b66b_$instance.xci]
