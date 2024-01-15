#
# Copyright 2022 Xilinx, Inc.
#           2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

# set the device part from command line argvs
set_part [lindex $argv 0]

set instance [lindex $argv 1]
set width [lindex $argv 2]
set depth [lindex $argv 3]
set prog_full [lindex $argv 4]
set prog_empty [lindex $argv 5]
set has_tkeep [lindex $argv 6]
set has_tlast [lindex $argv 7]

# ----------------------------------------------------------------------------
# generate AXIS data fifo IP
# ----------------------------------------------------------------------------
create_ip -name axis_data_fifo \
          -vendor xilinx.com \
          -library ip \
          -version 2.0 \
          -module_name axis_data_fifo_$instance \
          -dir ./ip_creation

set_property -dict [list CONFIG.TDATA_NUM_BYTES $width \
                         CONFIG.IS_ACLK_ASYNC {1} \
                         CONFIG.FIFO_DEPTH $depth \
                         CONFIG.HAS_AFULL {1} \
                         CONFIG.HAS_PROG_FULL {1} \
                         CONFIG.PROG_FULL_THRESH $prog_full \
                         CONFIG.HAS_AEMPTY {1} \
                         CONFIG.HAS_PROG_EMPTY {1} \
                         CONFIG.PROG_EMPTY_THRESH $prog_empty \
                         CONFIG.HAS_TKEEP $has_tkeep \
                         CONFIG.HAS_TLAST $has_tlast ] \
             [get_ips axis_data_fifo_$instance]

generate_target all [get_files ./ip_creation/axis_data_fifo_$instance/axis_data_fifo_$instance.xci]

