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

create_ip \
        -name ila \
        -vendor xilinx.com \
        -library ip \
        -version 6.2 \
        -module_name ila_nfc \
        -dir ./ip_creation

set_property -dict [list \
  CONFIG.C_MONITOR_TYPE {Native} \
  CONFIG.C_NUM_OF_PROBES {9} \
  CONFIG.C_PROBE5_WIDTH {16} \
  CONFIG.C_PROBE6_WIDTH {3} \
  CONFIG.C_PROBE7_WIDTH {3} \
  CONFIG.C_DATA_DEPTH {2048} \
  CONFIG.C_TRIGOUT_EN {false} \
  CONFIG.C_TRIGIN_EN {false} \
  CONFIG.C_INPUT_PIPE_STAGES {0} \
  CONFIG.C_EN_STRG_QUAL {1} \
  CONFIG.C_ADV_TRIGGER {true} \
  CONFIG.ALL_PROBE_SAME_MU {true} \
] [get_ips ila_nfc]

generate_target all [get_files ./ip_creation/ila_nfc/ila_nfc.xci]
