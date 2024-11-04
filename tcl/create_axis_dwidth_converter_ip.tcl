#
# Copyright 2023-2024 Gerrit Pape (papeg@mail.upb.de)
#
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

set_part [lindex $argv 0]

set instance [lindex $argv 1]
set width [lindex $argv 2]
set has_tkeep [lindex $argv 3]
set has_tlast [lindex $argv 4]

if {$instance == "rx"} {
     set m_width $width
     set s_width 32
} elseif {$instance == "tx"} {
     set m_width 32
     set s_width $width
} else {
     puts "instance has to be rx or tx"
     exit 1
}

create_ip -name axis_dwidth_converter \
          -vendor xilinx.com \
          -library ip \
          -version 1.1 \
          -module_name axis_dwidth_converter_$instance \
          -dir ./ip_creation
      
set_property -dict [list CONFIG.HAS_TKEEP $has_tkeep \
                         CONFIG.HAS_TLAST $has_tlast \
                         CONFIG.M_TDATA_NUM_BYTES $m_width \
                         CONFIG.S_TDATA_NUM_BYTES $s_width] \
                    [get_ips axis_dwidth_converter_$instance]

generate_target all [get_files ./ip_creation/axis_dwidth_converter_$instance/axis_dwidth_converter_$instance.xci]
